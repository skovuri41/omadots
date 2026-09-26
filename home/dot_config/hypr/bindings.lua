-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

hl.unbind("SUPER + SHIFT + M") -- previously: Music
o.bind("SUPER + SHIFT + M", "Omarchy Spotify","omarchy shell -q quickshell.spotify.player togglePlayer")

hl.unbind("SUPER + SLASH") -- previously monitor scaling
o.bind("SUPER + SLASH", "Everything", "omarchy-shell shell toggle b.everything")

-- Swap SUPER+F and SUPER+SHIFT+F: Omarchy's defaults have F = fullscreen,
-- SHIFT+F = file manager (nautilus) - flipped here, so F now opens the
-- file manager and SHIFT+F fullscreens. Dispatcher calls are copied
-- straight from default/hypr/bindings/tiling.lua and applications.lua,
-- just swapped onto the other key.
hl.unbind("SUPER + F") -- previously: Full screen
hl.unbind("SUPER + SHIFT + F") -- previously: File manager

o.bind("SUPER + F", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + SHIFT + F", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Close window: SUPER+Q instead of the default SUPER+W. Confirmed against
-- literal source that plain SUPER+Q is free (only SUPER+CTRL+Q exists, bound
-- to the calculator - different combo, no conflict), so no unbind needed
-- for Q itself, only for W.
hl.unbind("SUPER + W") -- previously: Close window

o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

-- Personal webapp/app launcher row: SUPER+SHIFT+<key>. Every one uses
-- Omarchy's own { webapp = ... , focus = true } / { launch = ..., focus =
-- "^regex$" } binding shapes (see default/hypr/bindings/applications.lua's
-- WhatsApp/Google Photos/Maps/Messages entries and the Obsidian launch/focus
-- entry) specifically because those already implement "launch it, or focus
-- the existing window if it's already open" - not reinventing that logic.
--
-- Several of these keys already had a default Omarchy binding - unbound
-- each one first (see the comment above each), same reasoning as the
-- H/J/K/L fix earlier: o.bind()-ing an already-bound key without unbinding
-- throws and silently kills everything after it in the file.
--
-- One default got relocated rather than dropped (SUPER+ALT+<key>, same
-- convention as before) since it's an independent app, not being replaced
-- by anything in this list:
--   Omawrite (was SUPER+SHIFT+W)     -> SUPER+ALT+W
-- Google Photos (was SUPER+SHIFT+P, then relocated here to SUPER+ALT+P) was
-- dropped entirely on 2026-09-12 to free SUPER+ALT+P for Bitwarden - see
-- that section below for why, and the SUPER+P/SUPER+SHIFT+P swap that
-- triggered it.
-- Signal (was SUPER+SHIFT+G) was briefly relocated to SUPER+ALT+G too, but
-- dropped entirely per your request - no shortcut for Signal at all now,
-- only reachable via the app launcher (SUPER+SPACE). For the record: that
-- wasn't actually a duplicate/conflicting bind with Omarchy's own defaults -
-- SUPER+ALT+G (2 modifiers, Signal) and SUPER+SHIFT+ALT+G (3 modifiers,
-- WhatsApp - untouched, still there) are genuinely different key combos,
-- not the same one registered twice. Removing it anyway since you don't
-- want it.
-- Two were NOT relocated, on the assumption you don't use Basecamp's HEY
-- (you're replacing Email with Fastmail below, and nothing here uses HEY
-- Calendar) - say the word if that assumption's wrong and I'll put them
-- back on an ALT-tier key instead of leaving them unbound:
--   Calendar (was SUPER+SHIFT+C, hey.com) - dropped
--   Email (was SUPER+SHIFT+E, hey.com) - dropped (SUPER+SHIFT+ALT+E "New
--     email" still points at hey.com too - let me know if you want that
--     unbound/relocated as well)

hl.unbind("SUPER + SHIFT + G") -- previously: Signal
hl.unbind("SUPER + SHIFT + W") -- previously: Omawrite
hl.unbind("SUPER + SHIFT + P") -- previously: Google Photos
hl.unbind("SUPER + SHIFT + A") -- previously: ChatGPT (moving to G below)
hl.unbind("SUPER + SHIFT + C") -- previously: Calendar (hey.com)
hl.unbind("SUPER + SHIFT + E") -- previously: Email (hey.com)
hl.unbind("SUPER + SHIFT + X") -- previously: X (same key, adding focus=true)
hl.unbind("SUPER + SHIFT + Y") -- previously: YouTube (same key, adding focus=true)
-- SUPER+SHIFT+R and SUPER+SHIFT+H had nothing bound - no unbind needed.

o.bind("SUPER + ALT + W", "Omawrite", { launch = "omawrite" })

-- Google Photos used to live here (SUPER+ALT+P) - dropped entirely on
-- 2026-09-12, not relocated again, to free this key for Bitwarden (see
-- Bitwarden's own section below for the full chain of moves this
-- triggered). Still reachable via the app launcher (SUPER+SPACE) or a
-- browser bookmark if you ever want it back.

o.bind("SUPER + SHIFT + X", "X", { webapp = "https://x.com/", focus = true })
o.bind("SUPER + SHIFT + W", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
o.bind("SUPER + SHIFT + Y", "YouTube", { webapp = "https://youtube.com/", focus = true })
o.bind("SUPER + SHIFT + A", "Amazon", { webapp = "https://www.amazon.com/", focus = true })
o.bind("SUPER + SHIFT + H", "Robinhood", { webapp = "https://robinhood.com/", focus = true })
o.bind("SUPER + SHIFT + G", "ChatGPT", { webapp = "https://chatgpt.com", focus = true })
o.bind("SUPER + SHIFT + E", "Fastmail", { webapp = "https://app.fastmail.com/", focus = true })
o.bind("SUPER + SHIFT + R", "Reddit", { webapp = "https://www.reddit.com/", focus = true })

-- Ytdl (bibek.ytdl plugin, added 2026-09-14): two bindings adapted from the
-- plugin's own README, converted to this file's "MODS + KEY" combined-string
-- o.bind() convention instead of the README's separate-args example style.
-- Both keys confirmed free directly against every default/hypr/bindings/*.lua
-- file plus this file's own existing binds - no SUPER+Y or SUPER+CTRL+Y
-- anywhere, so no hl.unbind() needed for either.
--
-- SUPER+Y opens the panel via the shell's own `summon` IPC method - confirmed
-- real, not assumed: shell/shell.qml's target="shell" IpcHandler defines
-- `function summon(id, payloadJson)`.
--
-- SUPER+CTRL+Y triggers a one-shot auto-download (checks MPRIS for a playing
-- YouTube tab first, then falls back to the clipboard) without opening the
-- panel at all. This one looked like a typo at first - the README literally
-- reads "omarchy shell ytdl autoDownload", missing the hyphen you'd expect
-- for "omarchy-shell" - but it's correct as written: `omarchy <group> ...` is
-- a generic router (bin/omarchy) that forwards to bin/omarchy-<group>, and
-- omarchy-shell's own header documents exactly this equivalence
-- ("omarchy:examples=omarchy shell shell ping | omarchy-shell -q ..."), so
-- "omarchy shell ytdl autoDownload" == "omarchy-shell ytdl autoDownload" -
-- target "ytdl", method "autoDownload", both confirmed straight from the
-- plugin's own Service.qml (`IpcHandler { target: "ytdl" ...
-- function autoDownload() }`).
--
-- Descriptions below deliberately differ ("Ytdl panel" / "Ytdl
-- auto-download") instead of both saying "Ytdl" - keeps
-- `omarchy menu keybindings --print` unambiguous between the two.
--
-- BUG FIXED 2026-09-23: both of these silently did nothing when pressed,
-- confirmed straight from o.bind()'s own source (default/hypr/helpers.lua,
-- basecamp/omarchy) - a plain-string dispatcher arg is NOT parsed as raw
-- Hyprland "dispatcher, args" syntax (no comma-splitting/keyword-stripping
-- anywhere in it or in command_from()); it's handed verbatim to
-- hl.dsp.exec_cmd(), which wraps the WHOLE string as the exec dispatcher's
-- own argument. So the leading "exec, " here wasn't being stripped - it was
-- being run AS PART OF the shell command, i.e. `sh -c "exec, omarchy-shell
-- ..."`, which tries to execute a program literally named `exec,` (comma
-- included) and fails with "command not found" - invisibly, since Hyprland
-- exec doesn't surface a spawned command's stderr anywhere. Confirmed by
-- reproducing this exact error on the emacs-everywhere bind below. Fix is
-- the same as that one: drop the "exec, " prefix entirely - the bare
-- command is already everything hl.dsp.exec_cmd() needs (see this file's
-- own working examples with no prefix, e.g. SUPER+E "Emacs" above).
o.bind("SUPER + Y", "Ytdl panel", "omarchy-shell shell summon bibek.ytdl")
o.bind("SUPER + CTRL + Y", "Ytdl auto-download", "omarchy shell ytdl autoDownload")

-- These two are native apps, not webapps - `launch` is the command to run,
-- `focus` is a regex matched against the window's *class* to detect an
-- already-open instance - two different things, so confirming the
-- executable name doesn't by itself confirm the focus regex. `launch`
-- values below are your confirmed executable names; `focus` (window class)
-- is still my best guess in both cases, not verified against your actual
-- machine - check after first launch with:
--   hyprctl clients -j | jq '.[] | {class, title}'
-- and adjust the `focus` regex below if it doesn't land.
--
-- Claude desktop: launch confirmed by you. Class guessed as "claude" from
-- the claude-desktop-bin AUR package's PKGBUILD (StartupWMClass=claude) -
-- correct if that's the AUR package behind your claude-desktop executable.
o.bind("SUPER + SHIFT + C", "Claude desktop", { launch = "claude-desktop", focus = "^claude$" })

-- Bitwarden desktop: launch confirmed by you as bitwarden-desktop (updated
-- from my earlier wrong guess of "bitwarden"). Class still guessed as
-- "Bitwarden" (capitalized product name, common Electron convention) - not
-- verified, and the executable name being bitwarden-desktop doesn't confirm
-- it either way.
--
-- Moved from SUPER+SHIFT+P to SUPER+ALT+P on 2026-09-12, to make room for
-- the window back-and-forth toggle at SUPER+P and the workspace
-- back-and-forth toggle at SUPER+SHIFT+P (see that section below for the
-- full reasoning) - Google Photos, which used to hold this exact key, was
-- dropped rather than relocated again (see its own note above).
o.bind("SUPER + ALT + P", "Bitwarden", { launch = "bitwarden-desktop", focus = "^Bitwarden$" })

-- Spotify (native desktop client, AUR - see dev-stack-software.txt). This
-- replaces Omarchy's own default SUPER+SHIFT+M ({ omarchy = "spotify" }),
-- which you'd already overridden above with a Quickshell mini-player toggle
-- instead - that toggle is a panel, not a real window, so it can't be
-- workspace-assigned (see windowrules.lua). This is a second, independent
-- way to get at Spotify: a full app window you can actually put on a
-- workspace. Key is SUPER+SHIFT+U - picked arbitrarily since every letter
-- with an obvious "S for Spotify"/"M for Music" mnemonic was already taken
-- (S = Google Maps, M = your Quickshell toggle, both left as-is since you
-- didn't ask to change either) - say the word if you'd rather free up S or
-- M for this instead.
-- `focus` (class) is an unverified guess, same caveat as Claude
-- desktop/Bitwarden above - check with hyprctl clients -j after first launch.
o.bind("SUPER + SHIFT + U", "Spotify", { launch = "spotify", focus = "^[Ss]potify$" })

-- Emacs GUI frame via the daemon. Focuses the existing frame if one's
-- already open instead of always spawning a new one - see
-- emacs-focus-or-launch (home/dot_local/bin) for why this needs its own
-- script rather than Omarchy's { launch, focus } table form. Falls back to
-- launching fresh via -c new frame, -n don't block the shell, -q skip the
-- "waiting for emacs..." message, -a '' auto-starts the daemon with
-- 'emacs --daemon' if it isn't already running. Complements the
-- terminal-side emacsclient usage (ec/emax/ediff aliases, git core.editor)
-- already in this repo - same daemon, this just adds a GUI-frame shortcut.
-- Confirmed free at the plain SUPER level (checked every default binding
-- file - only SUPER+CTRL+E "Emojis" exists, different combo).
o.bind("SUPER + E", "Emacs", "emacs-focus-or-launch")

-- Unbind default SUPER+CTRL+E (was: Emojis) - repurposed below for a forced
-- new Emacs frame.
hl.unbind("SUPER + CTRL + E")
-- Always spawns a fresh frame, bypassing emacs-focus-or-launch's reuse
-- logic above - same underlying emacsclient flags as plain SUPER+E.
o.bind("SUPER + CTRL + E", "New Emacs window", "emacsclient -cnqua ''")

-- SUPER+ALT+E: floating scratch Emacs popup - compose text, C-c C-c sends
-- it back to whatever window was focused before (C-c C-k cancels). Auto-
-- paste via `wtype` DOES work reliably here - an earlier attempt concluded
-- otherwise from a flawed test (a `cat > file` terminal target checked
-- without a trailing newline, which terminals never flush from their
-- canonical-mode input buffer) - see doom.d config.el for the full
-- writeup and the actual implementation (`+emacs-float' and friends).
-- NOT bound to SUPER+CTRL+E as first suggested - that combo is already
-- "Emojis" (see the SUPER+E comment above).
-- All the logic lives in doom.d config.el's `+emacs-float' - this is a
-- bare `--eval`, matching upstream emacs-everywhere's own invocation
-- convention, since `+emacs-float' captures the origin window and spawns
-- its own `emacsclient --create-frame` subprocess for the actual popup
-- (naming the frame "emacs-float", matched by the windowrule in
-- windowrules.lua to float+size it - matching class+title together there,
-- not class alone, so it doesn't also float normal SUPER+E Emacs windows).
o.bind("SUPER + ALT + E", "Emacs Float", "emacsclient -a '' --eval '(+emacs-float)'")

-- SUPER+X: floating GTD capture popup - same architecture as SUPER+ALT+E
-- above (Emacs Float): a bare `--eval`, all the logic lives in doom.d
-- gtd.el's `+org-capture-float', which captures the origin window and
-- calls Doom's own `+org-capture/open-frame' (frame named "doom-capture",
-- matched by the windowrule in windowrules.lua) pointed at a capture menu
-- covering both org-capture and org-roam-capture templates, then restores
-- focus to the origin window once capture finishes or is aborted.
o.bind("SUPER + X", "GTD Capture", "emacsclient -a '' --eval '(+org-capture-float)'")

-- Vim-style directional movement: SUPER + J/K focus the window to the
-- left/right, SUPER + H/L switch to the previous/next workspace. Deliberately
-- not doing up/down on J/K - see the comment block below on why, and on how
-- this interacts with the CAGS home row mods in keyd/default.conf.
--
-- CORRECTION: an earlier version of this only unbound SUPER+K before adding
-- these, on the mistaken belief that H/J/L were unbound by default. They
-- were not - J and L each already had a default binding, and o.bind()-ing
-- an already-bound key without unbinding it first throws (per this file's
-- own guidance up top: "unbind it first, then bind the key again"), which
-- aborted the rest of this block's execution - so none of H/J/K/L took
-- effect, not just the ones that actually conflicted. All four are unbound
-- below before rebinding, and the two defaults that were living on J/L are
-- relocated to SUPER+ALT+<key> rather than just dropped, matching Omarchy's
-- own ALT-tier convention (e.g. SUPER+ALT+F = full width vs SUPER+F =
-- fullscreen):
--   SUPER+K was "Keybindings menu" - not relocated, still reachable via
--     SUPER+SPACE (root menu) or 'omarchy-menu-keybindings' from a terminal.
--   SUPER+J was "Toggle window split" (dwindle-only) - moved to SUPER+ALT+J.
--   SUPER+L was "Toggle workspace layout" - the actual scrolling/dwindle
--     switch we've been discussing - moved to SUPER+ALT+L, since you're
--     actively using both layouts and this is the only way to flip between
--     them.
--   SUPER+H had nothing bound - not calling hl.unbind() on it at all, since
--     that's exactly the kind of "assumed safe" shortcut that caused this
--     bug in the first place; better to only unbind keys confirmed bound.
hl.unbind("SUPER + K") -- previously: Keybindings menu
hl.unbind("SUPER + J") -- previously: Toggle window split
hl.unbind("SUPER + L") -- previously: Toggle workspace layout

o.bind("SUPER + ALT + J", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

o.bind("SUPER + J", "Focus left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + K", "Focus right window", hl.dsp.focus({ direction = "r" }))
o.bind("SUPER + H", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
o.bind("SUPER + L", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))

-- Unify J/K muscle memory across grouped and non-grouped windows, instead of
-- having a separate pair of keys (F11/F12 below) just for cycling within a
-- Hyprland window group (tabbed/stacked windows). You'd asked for a custom
-- hyprctl+jq script (check active window's `.grouped[]`, compare to
-- `.address`, dispatch `changegroupactive` vs `cyclenext` accordingly) bound
-- onto J/K to do this - turns out Hyprland already has this exact behavior
-- built in as a one-line config flag, so no script/process-per-keypress is
-- needed. Verified directly against Hyprland's own source (not docs, which
-- don't render this option's page reliably), specifically
-- Actions::moveFocus() in src/config/shared/actions/ConfigActions.cpp:
--   binds:movefocus_cycles_groupfirst (default false) - when a grouped
--   window has focus, `movefocus l` first steps to the PREVIOUS tab in the
--   group (group->moveCurrent(false)) and `movefocus r` steps to the NEXT
--   tab (moveCurrent(true)), instead of immediately jumping focus outside
--   the group. Only once you're already on the group's first/last tab does
--   movefocus fall through to its normal spatial behavior and leave the
--   group (or wrap back within the group if there's nothing outside to go
--   to - e.g. a single monitor with only this one group on the workspace).
-- Since SUPER+J/K already dispatch exactly `hl.dsp.focus({direction="l"/
-- "r"})` (confirmed in Hyprland's LuaBindingsDispatchers.cpp to be a thin
-- wrapper over this same Actions::moveFocus()), enabling this flag is the
-- entire change - no new bind, no new script file, and it applies
-- identically under both dwindle and the scrolling layout (the group check
-- runs before either layout's spatial resolution, so it doesn't disturb the
-- scrolling-layout-parity reasoning in the Notes section below).
hl.config({
  binds = {
    movefocus_cycles_groupfirst = true,
  },
})

-- Workspace back-and-forth toggle - originally SUPER + P, moved to
-- SUPER + SHIFT + P on 2026-09-12 to make room for the window
-- back-and-forth toggle below (see that section for why SUPER + P was
-- worth taking over). This is different from H/L above: e-1/e+1 step
-- sequentially through workspaces in order, while Hyprland's "previous"
-- workspace keyword is a true back-and-forth toggle - jump to whichever
-- workspace was last active, press again to jump right back, regardless
-- of workspace number/order.
--
-- Turns out Omarchy already ships exactly this dispatcher by default -
-- hl.dsp.focus({ workspace = "previous" }) - just bound to the easy-to-miss
-- SUPER+CTRL+TAB chord as "Former workspace" (default/hypr/bindings/
-- tiling.lua). That tracks with "I don't think it's enabled" - it was there,
-- just not on a key you'd stumble onto. Left that default binding in place
-- (harmless to have two paths to the same toggle).
--
-- SUPER+SHIFT+P is free at this point in the file: Google Photos held it
-- as an Omarchy default, was unbound above, then relocated to SUPER+ALT+P,
-- and Bitwarden (which had since taken this key over) was itself moved to
-- SUPER+ALT+P above too - so no further hl.unbind() is needed here, this
-- key has had nothing bound to it since that original unbind ran.
o.bind("SUPER + SHIFT + P", "Former workspace (back and forth)", hl.dsp.focus({ workspace = "previous" }))

-- Window back-and-forth NAVIGATION, on SUPER + P (back) / SUPER + N
-- (forward) - upgraded 2026-09-20 from the single-step toggle this used to
-- be (added 2026-09-12: `hl.dsp.focus({ last = true })`, a pure current<->
-- last swap with no memory beyond one step). You asked whether Hyprland has
-- a built-in "browser-style" N-deep back/forward through focus history,
-- walking multiple windows back then multiple forward in the exact order
-- you visited them - verified directly against Hyprland's own C++ source
-- (not the wiki) that it does NOT:
--   Desktop::History::CWindowHistoryTracker (src/desktop/history/
--   WindowHistoryTracker.hpp) only exposes fullHistory()/
--   historyForWorkspace() - a flat, append-only, oldest->newest log with no
--   cursor/position concept - and the only two dispatchers that read it
--   (focusCurrentOrLast/focusUrgentOrLast, src/config/shared/actions/
--   ConfigActions.cpp) each just peek at the single most-recent entry, same
--   as the old binding here.
-- So this is built here in Lua instead, on two real Hyprland Lua APIs
-- confirmed straight from source, not assumed:
--   hl.on("window.active", fn) - fires on every real focus change
--     (src/config/lua/LuaEventHandler.cpp); confirmed to accept a plain Lua
--     function, not just a fixed dispatcher.
--   hl.dispatch(hl.dsp.focus({ window = "stableid:<id>" })) - focuses a
--     window by selector, run immediately instead of being bound to a key.
--     hl.dsp.focus(...) only ever BUILDS a dispatcher object - calling it
--     directly with () throws "dispatcher objects cannot be called
--     directly; use hl.dispatch(dispatcher)" (confirmed verbatim from
--     src/config/lua/bindings/LuaBindingsDispatcherUtils.cpp - this bit me
--     on the first pass, fixed here). o.bind()/hl.bind() don't need this
--     wrapper because Hyprland's own keypress dispatch machinery calls the
--     dispatcher object internally; hl.dispatch() is the one call that lets
--     Lua code do the same thing on demand, which is what firing focus from
--     inside this plain function (not a key-triggered dispatcher slot)
--     needs. "stableid:" (MODE_STABLE_ID in src/desktop/state/ViewQuery.cpp)
--     is used rather than "address:" deliberately: window.address is a raw
--     memory pointer that could theoretically get reused by a new window
--     once the old one closes and its memory is freed (confirmed this risk
--     exists, not assumed), while window.stable_id
--     (w->metadata().stableID()) is a monotonic id that's never reused for
--     the life of the Hyprland session - the safer choice for something
--     sitting in a history list for a while.
--
-- SUPER + N is confirmed free (checked every default/hypr/bindings/*.lua
-- file - only SUPER+SHIFT+N "Editor" and SUPER+CTRL+N "Toggle nightlight"
-- exist, neither is plain SUPER+N) - no hl.unbind() needed for it.
-- SUPER + P wasn't free before this file touched it (Omarchy's default has
-- it as "Pseudo window") - already unbound below from when the single-step
-- toggle first took this key over on 2026-09-12; nothing further needed
-- here.
--
-- Known limitation, not engineered around: this history lives in the Lua
-- VM's own memory, not on disk. `hyprctl reload` (theme switches, config
-- edits) tears down and re-runs the whole Lua config - confirmed via the
-- "config.unload"/"config.reloaded" events firing on every reload - which
-- wipes this table back to empty. Same tradeoff as a browser tab's back/
-- forward history resetting on an app restart; fine for a short-lived
-- navigation aid, called out here rather than silently swallowed.
hl.unbind("SUPER + P") -- previously: Pseudo window

local windowHistory = {}
local historyCursor = 0
local navigatingWindowHistory = false

-- REAL BUG FOUND 2026-09-20, confirmed straight from source, not assumed:
-- window.stable_id is exposed to Lua as a plain decimal integer -
--   src/config/lua/objects/LuaWindow.cpp:
--     else if (key == "stable_id") lua_pushinteger(L, sc<lua_Integer>(w->m_stableID));
-- - but the "stableid:<id>" window-selector match on the OTHER end compares
-- against a HEX-formatted string -
--   src/desktop/state/ViewQuery.cpp, MODE_STABLE_ID:
--     std::string stableID = std::format("{:x}", w->m_stableID);
--     if (matchCheck != stableID) continue;
-- - so storing win.stable_id and later doing "stableid:" .. id concatenates
-- Lua's decimal string form of the integer, which only happens to match the
-- hex form for ids 0-9. Any window whose stable id is >= 10 (i.e. needs an
-- a-f digit in hex) would silently fail to match anything - no error, the
-- dispatcher just finds zero windows and does nothing. This alone explained
-- "nope nothing happens in keybinds": most of the time the id in play needed
-- an a-f digit and the focus call was a quiet no-op. Fixed below by hex-
-- encoding the id with string.format("%x", ...) at the point it's stored, so
-- it already matches the selector's own format. Confirmed fixed 2026-09-20.
hl.on("window.active", function(win)
  if navigatingWindowHistory or not win then return end

  local id = win.stable_id
  if not id then return end

  local hexId = string.format("%x", id)
  if hexId == windowHistory[historyCursor] then return end

  -- Browser-style: focusing a *new* window while parked back in history
  -- drops whatever was ahead of the cursor, rather than leaving a stale
  -- "forward" branch dangling.
  for i = #windowHistory, historyCursor + 1, -1 do
    table.remove(windowHistory, i)
  end

  table.insert(windowHistory, hexId)
  historyCursor = #windowHistory
end)

local function navigate_window_history(step)
  local target = historyCursor + step
  if target < 1 or target > #windowHistory then return end

  historyCursor = target
  navigatingWindowHistory = true
  hl.dispatch(hl.dsp.focus({ window = "stableid:" .. windowHistory[historyCursor] }))
  navigatingWindowHistory = false
end

o.bind("SUPER + P", "Focus back in window history", function() navigate_window_history(-1) end)
o.bind("SUPER + N", "Focus forward in window history", function() navigate_window_history(1) end)

-- Notes on this approach:
--
-- 1. Dispatcher choice / scrolling vs dwindle: this deliberately reuses the
--    exact same hl.dsp.focus({direction=...}) call Omarchy's own SUPER+LEFT/
--    RIGHT arrow bindings already use (see default.hypr.bindings.tiling) -
--    not the scrolling layout's own layoutmsg-based "focus l/r" (which
--    additionally recenters/wraps columns). Hyprland doesn't yet have one
--    dispatcher that's fully layout-aware across dwindle and the newer
--    scrolling layout (see hyprwm/Hyprland discussion #13731) - but since
--    your looknfeel.lua already runs general.layout = "scrolling" in
--    production today using this exact dispatcher via the arrow keys, J/K
--    are guaranteed to behave identically to whatever LEFT/RIGHT already do
--    for you right now, in both layouts. If you ever toggle to dwindle and
--    miss the scrolling layout's auto-centering on focus change, that's the
--    tradeoff - swap the direction bindings to
--    hl.dsp.layout("focus l/r") for scrolling-only centering, at the cost of
--    it not being the same call dwindle understands.
--    H/L (workspace switching) have no such caveat - workspaces aren't a
--    per-layout concept, so "e-1"/"e+1" behave identically everywhere.
--
-- 2. Up/down intentionally left off J/K: dwindle and scrolling don't agree
--    on what "vertical" even means (dwindle's tree can split either way,
--    scrolling is a single row of columns), so a vim-style K-is-up mapping
--    would be inconsistent between the two anyway. SUPER + UP/DOWN (arrows)
--    still exist unchanged for that.
--
-- 3. Interaction with CAGS home row mods (keyd/default.conf): H is untouched
--    by keyd, no interaction. J/K/L, though, are all lettermod() keys there
--    (meta/shift/alt respectively) - each only resolves to the modifier
--    layer if the key itself is held past ~200ms, or held while another key
--    is pressed afterward. In a SUPER+J/K/L chord you press Super first,
--    which resets keyd's idle timer right before the letter tap, so in
--    practice the letter fires immediately and the shortcut lands reliably.
--    The one real failure mode: if you hold the letter key itself for a
--    beat (not just Super) - e.g. thinking with Super+K held down - keyd
--    will resolve that as the CAGS layer instead of emitting 'k', and the
--    Hyprland bind silently won't fire that press. Same reason NOT to use a
--    hold-to-repeat bind (binde) here even though Hyprland supports it -
--    holding past ~200ms is exactly what keyd is watching for. Quick,
--    deliberate taps (which is how you'd naturally use a WM shortcut
--    anyway) avoid this entirely.

-- Cycle windows within a Hyprland window group (tabbed/stacked windows).
-- Confirmed SUPER+F11/F12 are unbound in every default binding file.
-- Note: there's no existing bind in this setup that actually GROUPS windows
-- together in the first place (Hyprland's "togglegroup" dispatcher) - these
-- two only cycle within a group once one exists. Say the word if you want a
-- togglegroup bind added too.
--
-- Not fully redundant with the J/K + movefocus_cycles_groupfirst behavior
-- above, despite doing similar things: these two dispatch
-- `changegroupactive` directly, which only ever cycles within the group and
-- wraps at the ends - it never breaks out to a window outside the group.
-- J/K's movefocus-based cycling does break out at the group boundary. So
-- F11/F12 is "stay in this group no matter what", J/K is "flow through the
-- group as part of normal window navigation" - keep both.
--
-- Verified directly against Hyprland's own source this time (previously
-- flagged here as sourced from an unverified community Lua API reference):
-- hl.dsp.group.prev()/next() are real, defined in
-- src/config/lua/bindings/LuaBindingsDispatchers.cpp, and are confirmed
-- thin wrappers over the classic `changegroupactive b`/`f` dispatcher
-- (Actions::changeGroupActive() in ConfigActions.cpp) - not a separate or
-- speculative mechanism.
o.bind("SUPER + F11", "Previous window in group", hl.dsp.group.prev())
o.bind("SUPER + F12", "Next window in group", hl.dsp.group.next())

-- Herdr (SUPER+CTRL+RETURN, was: { omarchy = "terminal-herdr" } ->
-- omarchy-launch-terminal-herdr -> omarchy-launch-terminal herdr) launches
-- herdr directly from Hyprland, bypassing bash entirely - so it never sees
-- dot_bash_exports' EDITOR="emacsclient -t" and instead inherits the global
-- Hyprland-session EDITOR, which resolves through Omarchy's
-- omarchy-launch-editor to this machine's chosen default editor,
-- emacsclient-frame (home/dot_local/bin/executable_emacsclient-frame,
-- `emacsclient -c` - a new GUI frame). omarchy-launch-editor only execs a
-- chosen editor truly inline if its name is literally nvim/vim/nano/micro/
-- hx/helix/fresh; anything else - including emacsclient-frame - always runs
-- via `setsid uwsm-app`, i.e. always a new detached window, regardless of
-- the --inline flag. That's the confirmed root cause of herdr's
-- edit_scrollback (prefix+e) opening a new, smaller Emacs window instead of
-- an inline terminal-mode frame in the herdr pane itself.
--
-- Fix: reuse Omarchy's own unmodified launch script (so any future Omarchy
-- update to the uwsm-app/xdg-terminal-exec chain underneath it is still
-- picked up automatically), just with EDITOR overridden in front of it -
-- `exec` down that whole chain preserves it through to the final `herdr`
-- process. Scoped to only this one binding, so the emacsclient-frame
-- default stays untouched for git/other apps that still want a blocking
-- new-window GUI editor.
hl.unbind("SUPER + CTRL + RETURN") -- previously: { omarchy = "terminal-herdr" }
o.bind("SUPER + CTRL + RETURN", "Herdr", "EDITOR='emacsclient -t' omarchy-launch-terminal-herdr")

-- fathom: begin
do
  local fathom = os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.mtolhuys.fathom/hypr/fathom.lua"
  local file = io.open(fathom, "r")
  if file then
    file:close()
    pcall(dofile, fathom)
  end
end
-- fathom: end
