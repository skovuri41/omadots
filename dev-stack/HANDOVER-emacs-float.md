# Handover: emacs-float (SUPER+ALT+E) on Hyprland/Omarchy

Terse, Claude-Code-oriented. Status as of 2026-09-23: WORKING, verified via
many repeated hand tests (not just written, actually run end-to-end).

## What it does

`SUPER+ALT+E` → floating Emacs popup (org-mode, Evil insert state) →
type text → `C-c C-c` → popup closes, focus returns to the window that was
active before the popup opened, text is typed there automatically (real
auto-paste, no manual Ctrl+V). `C-c C-k` cancels without sending.

## File locations

- `doom.d/config.el` (`~/.config/doom/config.el`) - ALL the logic. NOT
  chezmoi-managed (separate git repo the user commits themselves). Search
  for `"write anywhere" popup` section header. Functions:
  `+emacs-float`, `+emacs-float-init`, `+emacs-float-done`,
  `+emacs-float-cancel`, `+emacs-float-wtype-send`,
  `+emacs-float--active-window-address`, `+emacs-float--call`.
- `doom.d/init.el` - `everywhere` `:app` module is DISABLED (commented
  out, ~line 184). Do not re-enable without also fixing/removing the
  bundled doom+ module's own broken Hyprland dispatch (see "abandoned"
  section below) - re-enabling alone silently reintroduces a dead package.
- `doom.d/packages.el` - no relevant entries; `tinee` and its `everywhere`
  module dependency were both fully removed.
- omadots (chezmoi source under `~/.local/share/chezmoi/`, needs
  `chezmoi apply` after editing, never apply it yourself unless asked):
  - `home/dot_config/hypr/bindings.lua` - the `SUPER + ALT + E` bind,
    search `"Emacs Float"`. Bare `emacsclient -a '' --eval '(+emacs-float)'`.
  - `home/dot_config/hypr/windowrules.lua` - floats+sizes the popup frame,
    search `emacs-float`. `o.window({ class = "^emacs$", title =
    "^emacs-float$" }, { float = true, size = { 900, 600 }, center = true
    })`.
  - `home/dot_config/hypr/autostart.lua` - reverted to pristine 2-line
    stub. NOTHING in the current implementation needs daemon-env-import or
    a pgtk-bootstrap hook (unlike the abandoned tinee attempt) - `+emacs-float`
    uses `--create-frame` (a real `-c` connection) for its own popup, which
    self-bootstraps pgtk fine.
- System deps: `wtype` (already installed, NOT chezmoi-tracked, not added
  by this work), `wl-clipboard` (in `dev-stack-software.toml`, predates
  this work, unrelated). `ydotool` was tried, fully reverted (service
  disabled, udev rule removed, `dev-stack-software.toml` entry removed) -
  NOT needed by the current implementation.

## How it actually works (read config.el for full comments)

```elisp
;; keybind (bindings.lua) just does:
emacsclient -a '' --eval '(+emacs-float)'
```

`+emacs-float`: captures `hyprctl -j activewindow`'s `.address` via
`json-read-from-string` (own helper, NOT the removed emacs-everywhere
package), THEN spawns `emacsclient --create-frame --frame-parameters
'((name . "emacs-float"))' --eval '(+emacs-float-init "0xADDR")'`
asynchronously (`call-process ... nil 0 nil ...` = don't wait). Capturing
origin BEFORE creating the frame is required - by the time the new frame
exists it's the active window, not the one you came from.

`+emacs-float-init`: `generate-new-buffer "float"` (fresh each time, never
reused/cleaned up - buffers accumulate, harmless but not tidy, see TODO),
`org-mode`, buffer-local `+emacs-float-origin` = captured address,
`local-set-key` for `C-c C-c`/`C-c C-k`, `evil-insert-state` LAST (must be
after `org-mode` - switching major mode resets Evil to normal state,
learned the hard way).

`+emacs-float-done`: `(buffer-string)`, `(delete-frame)`, THEN explicit
`hyprctl dispatch "hl.dsp.focus({ window = \"address:0xADDR\" })"` +
`(sleep-for 0.15)`, THEN `+emacs-float-wtype-send`.

`+emacs-float-wtype-send`: **ONE** `call-process` -
`(call-process "wtype" nil nil nil "-M" "shift" "-m" "shift" text)`. The
Shift press/release is a warm-up for a real `wtype` startup race (see
below) - MUST be in the same process as `text`, not a separate prior
`call-process`/process object. Text passed as a literal argv string (no
shell involved via `call-process`, so no escaping/injection concerns
regardless of buffer content - quotes, newlines, anything is safe).

## Critical Hyprland-build-specific facts (this is NOT stock Hyprland)

This build has native Lua config (`hl`/`o` namespaces, same one used
throughout `bindings.lua`/`windowrules.lua`/etc.):

- `hyprctl dispatch <text>` evaluates `<text>` AS LUA
  (`hl.dispatch(<text>)`), not classic `DISPATCHER,args` CLI syntax.
  `hyprctl dispatch focuswindow address:0x...` is a silent no-op here (Lua
  syntax error, never surfaced). Use
  `hyprctl dispatch 'hl.dsp.focus({ window = "address:0x..." })'`.
- `hyprctl keyword ...` (classic keyword-set) does NOT work: "keyword
  can't work with non-legacy parsers. Use eval." Use `hyprctl eval <lua>`
  for one-off IPC Lua execution instead.
- Declarative window rules: do NOT call `hl.window_rule` directly (its
  real argument shape is unclear/finicky - tried `(rules, match)`,
  `(match, rules)` merged into one table, `(rule_str, selector_str)`, all
  wrong or partially wrong). Use `o.window(match_table, rules_table)` -
  Omarchy's own wrapper, used throughout `windowrules.lua` already,
  confirmed working via `hyprctl eval 'o.window({...}, {...})'` +
  triggering a fresh window open.
- `o.bind()`'s command string is passed VERBATIM to a shell via
  `hl.dsp.exec_cmd()` - no `"exec,"` prefix stripping. Never prefix with
  `exec, `.
- `emacs-everywhere-system-configs`/similar alists: `emacs-everywhere`'s
  own `emacs-everywhere--configure-system` walks the WHOLE list and lets
  the LAST matching entry win (not first) - relevant only if that package
  is ever reintroduced; caused a long-lived-daemon staleness bug
  previously (a doom+ module's competing entry silently shadowed a fix in
  doom.d config.el because it was positioned later in the list). N/A to
  the current `+emacs-float` implementation, which doesn't touch that
  package at all - noted here only because it's exactly the kind of
  silent-staleness trap this whole build is full of.
- A headless `emacs --daemon` never initialises any window-system backend
  (pgtk/Wayland) on its own - only a real `emacsclient -c`/`--create-frame`
  connection does that (using the connecting client's env). A bare
  `(make-frame ...)` via plain `--eval`, with NO prior `-c` connection ever
  made in that daemon's lifetime, fails "Unknown terminal type". Why
  `+emacs-float` uses `--create-frame` for its own popup instead of a bare
  `make-frame` - self-bootstraps, no separate hook needed.
- Doom sets `initial-buffer-choice` to its dashboard buffer - any
  externally-created frame (bare `make-frame`, or `-c` with no file arg)
  shows the Doom dashboard by default, not a blank buffer.
  `+emacs-float-init` fixes this by explicitly `switch-to-buffer`-ing its
  own fresh buffer into the new frame's window.

## The wtype startup race (the actual remaining subtlety)

`wtype` (Wayland virtual-keyboard protocol client) has a real startup
race: text sent immediately after the process starts can have its first
several dozen ms of characters silently dropped while it establishes its
Wayland connection. Confirmed: `wtype -s 350 "payload"` from a cold
process sometimes delivered only the tail (e.g. "yload-two-calls" instead
of the full string), sometimes nothing, sometimes everything - genuinely
timing-dependent.

FIX: pass a harmless warm-up (`-M shift -m shift`, press+release Shift,
zero visible effect) AND the real text to the SAME SINGLE `wtype`
invocation/process. Two SEPARATE `wtype` processes (throwaway warm-up
call, then a second real-payload call) does NOT fix it - each process is
its own independent Wayland connection, so the second one hits the exact
same race the first was supposed to absorb. This was the actual bug in an
earlier version of this code; don't reintroduce it.

An even earlier attempt warmed up with a literal space character instead
of a modifier press - it worked (single combined process) but leaked a
stray leading space into the target on every line when the target was
itself an Emacs buffer (`electric-indent-mode`/`indent-relative`
artifact). Modifier-only warm-up avoids inserting anything visible,
regardless of target type.

## Two test-methodology traps that cost a lot of debugging time (repeat these mistakes and you'll get false negatives)

1. **Terminal targets need a trailing newline to verify.** A `foot -e sh
   -c 'cat > file'` target buffers typed input in canonical TTY mode until
   a newline arrives - text IS delivered correctly but sits unflushed and
   invisible to `cat` without one. An entire PRIOR session concluded
   "auto-paste is fundamentally impossible on this Hyprland build" from
   this exact false negative (tested with `ydotool` AND `wtype`, both
   "failed" identically, both were actually fine). If verifying delivery
   by hand, either send a trailing `wtype -k Return` too, or check a
   non-terminal target (a plain Emacs GUI buffer's `buffer-string` is the
   cleanest - no line-discipline involved).
2. **Bare `make-frame` test-target windows don't behave like real windows
   for keyboard-focus purposes.** A frame created via
   `(make-frame '((window-system . pgtk) ...))` (reusing an existing pgtk
   connection) does NOT reliably receive real Wayland keyboard focus even
   when Hyprland's own `hyprctl activewindow`/`hl.dsp.focus` reports it as
   active - `wtype` delivery to such a frame was flaky/partial/empty in a
   way that a REAL target (created via genuine `emacsclient -c`/
   `--create-frame`, or any real application window - terminal, browser,
   etc.) never was. If writing a throwaway test-target Emacs frame, create
   it with `emacsclient --create-frame ...`, not bare `(make-frame ...)`.

## Abandoned approaches (do not re-attempt without new information)

- **emacs-everywhere** (tecosaur/emacs-everywhere, via doom+'s bundled
  `everywhere` `:app` module): got its Hyprland `:focus-command`/
  `:info-function` working (fixed the Lua-dispatch-syntax bug + a
  stale-`emacs-everywhere-system-configs`-cache bug), but its own bundled
  Hyprland support (from the doom+ module, function
  `+everywhere-app-info-hyprland`) uses the OLD BROKEN classic dispatch
  syntax and will silently shadow any fix in doom.d config.el depending on
  daemon-lifetime load order (see "last-match-wins" note above). Root
  cause was fixed at the time but the package was still abandoned in favor
  of a fresh implementation once the wtype race above was solved.
- **tinee** (tusharhero/tinee, Codeberg): simpler design (no `hyprctl`
  calls at all, relies on Hyprland's native refocus-on-close), but that
  native refocus proved UNRELIABLE under rigorous testing with genuinely
  native prior focus (not just synthetic dispatch) - repeatedly refocused
  an unrelated `org.omarchy.agent`-classed window instead of the actual
  most-recently-focused one. Cause never identified; likely specific to
  this Hyprland build's internal focus-history bookkeeping not being
  properly updated by non-native focus changes. This is WHY the current
  implementation uses an EXPLICIT `hl.dsp.focus` dispatch instead of
  relying on native close-behavior - that dispatch mechanism, unlike
  native refocus-on-close, was reliable across this entire investigation.
  tinee package, its doom.d config.el section, its bindings.lua bind, and
  the autostart.lua hook it needed were all fully removed 2026-09-23.

## Known TODOs / possible future enhancements

- `float`-named buffers accumulate forever (never killed after
  `C-c C-c`/`C-c C-k`) - harmless but not tidy. Could `kill-buffer` at the
  end of `+emacs-float-done`/`+emacs-float-cancel` if it ever becomes
  annoying (`M-x list-buffers`).
- No fallback if `wtype` genuinely fails for some reason (e.g. compositor
  restart mid-session breaking the virtual-keyboard protocol binding) -
  text would be lost since it's typed, not clipboard-copied. Could add a
  `(gui-select-text text)` alongside the `wtype` call as a copy-as-backup
  safety net, at zero cost to the working path.
- `sleep-for 0.15` after the focus dispatch in `+emacs-float-done` was
  empirically sufficient in all testing but is a magic number, not a
  verified minimum - if flakiness ever reappears, this is the first place
  to look (increase it) before assuming a new bug class.
- No handling for org-mode markup in the typed output (e.g. if the user
  writes `*bold*` intending literal asterisks vs org emphasis) - types the
  raw buffer text verbatim, which is probably desired but worth confirming
  if this ever surprises anyone.

## Quick re-verification recipe (run this first if something seems broken)

```bash
# confirm the function is loaded
emacsclient --eval '(fboundp (quote +emacs-float))'

# full manual test against a disposable terminal (needs a trailing
# wtype -k Return of your own to check delivery - see trap #1 above)
rm -f /tmp/t.txt
setsid foot -e sh -c 'cat > /tmp/t.txt' & disown; sleep 1
TARGET=$(hyprctl -j clients | jq -r '[.[] | select(.title=="foot")] | last | .address')
hyprctl dispatch "hl.dsp.focus({ window = \"address:$TARGET\" })"; sleep 0.3
emacsclient -a '' --eval '(+emacs-float)'; sleep 1.5
BUF=$(emacsclient --eval "(let ((f (car (cl-remove-if-not (lambda (fr) (equal (frame-parameter fr 'name) \"emacs-float\")) (frame-list))))) (buffer-name (window-buffer (frame-selected-window f))))" | tr -d '"')
emacsclient --eval "(with-current-buffer \"$BUF\" (insert \"test\"))"
emacsclient --eval "(with-current-buffer \"$BUF\" (with-selected-frame (window-frame (get-buffer-window (current-buffer) t)) (call-interactively #'+emacs-float-done)))"
sleep 1; wtype -k Return; sleep 0.3; cat /tmp/t.txt   # should show "test"
```
