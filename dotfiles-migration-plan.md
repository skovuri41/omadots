# Dotfiles migration plan: skovuri41/dotfiles → chezmoi + Bitwarden

Planned 2026-08-19, executed 2026-08-19. Tree built, validated, and delivered to
`archdots` on the user's machine. User will review and commit themselves
(explicit preference — Claude does not run git commands on their device).

## Status: delivered, not yet committed by user

56 files now live under `/home/shyam/Projects/aicode/archdots/home/` (19 from
the original migration + 37 from the standard-Omarchy-config merge below).

- `README.md` — top-level doc tying `install-dev-stack.sh` (software) and
  `home/` (chezmoi dotfiles) together, with the required run order and a
  summary of every content change made during curation.
- `.chezmoiroot` → `home`
- `home/.chezmoi.toml.tmpl` — prompts once per machine for git name/email via
  `promptStringOnce`; sets `bitwarden.unlock = "auto"`.
- `home/.chezmoiexternal.toml` — `type = "git-repo"` external for
  `skovuri41/doom.d` → `~/.config/doom` (replaces the old git submodule).
- `home/dot_bashrc`, `dot_bash_aliases`, `dot_bash_exports`,
  `dot_bash_functions`, `dot_bash_profile`, `dot_bash_logout`, `dot_wgetrc`,
  `dot_inputrc` — kept at top-level (see "XDG placement" below).
- `home/dot_config/` — everything else, XDG-native personal config plus the
  full standard-Omarchy config set (see next section).
- `install-dev-stack.sh` / `README-dev-stack.md` — carries the `chezmoi` +
  `bitwarden-cli` registry entries added during the earlier phase.

### Standard-Omarchy-config merge (2026-08-19, second follow-up)

User copied every config file that ships with a standard Omarchy install into
a local `archdots/omarchyconfig/` folder and asked for it to be merged into
the chezmoi tree in standard chezmoi format, with conflicts resolved directly
rather than flagged back to them.

**Files merged as plain `dot_config/` entries** (42 files → `home/dot_config/`):
`alacritty/alacritty.toml`, `chromium-flags.conf`, `foot/foot.ini`,
`ghostty/config`, `herdr/config.toml`, `hypr/*.lua` + `hyprsunset.conf` +
`xdph.conf` (7 files), `kitty/kitty.conf`, `mise/config.toml`,
`omarchy/branding/{about.txt,screensaver.txt}`, `starship.toml`,
`user-dirs.dirs`, and the full LazyVim-based `nvim/` tree (18 files/paths,
including `nvim/.gitignore` → `nvim/dot_gitignore` per chezmoi naming).

**One symlink handled specially**: `nvim/lua/plugins/theme.lua` in the
source folder was itself a symlink to
`../../../../.local/state/omarchy/current/theme/neovim.lua` — Omarchy's
live theme-switcher state, not static content. Copying it as a plain file
would have frozen whatever theme was active at copy time and broken
Omarchy's theme hot-reload. Encoded instead as chezmoi's `symlink_theme.lua`
(chezmoi's symlink-managing naming convention), so `chezmoi apply` recreates
the *link* pointing at Omarchy's live theme state, not a snapshot.

**One real conflict, resolved**: both the existing personal
`home/dot_config/tmux/tmux.conf` (ported from the user's old dotfiles repo
in the first migration pass) and `omarchyconfig/tmux/tmux.conf` (Omarchy's
standard config) target the same path. Reviewed both and adopted Omarchy's
version as the base rather than attempting a keybinding-level merge, because:
(1) it's tightly integrated with Omarchy-specific tooling — the `?` binding
opens `omarchy-menu-tmux-keybindings`, `q` reloads from the exact
`~/.config/tmux/tmux.conf` path this setup already uses, and status-bar
colors track Omarchy's live theme; (2) `herdr/config.toml` (also being
merged in this pass) explicitly documents itself as "mirrors the Omarchy
tmux config" — keeping a different tmux.conf would desync herdr's
keybindings from the actual tmux config; (3) the two configs have real
keybinding collisions (e.g. bare `h`/`v` bound to different actions), not
just style differences, so a line-level merge would have been ambiguous.
Appended one small, non-colliding addition from the old personal config —
`monitor-activity`/`visual-activity` status-line alerts — since it doesn't
touch any binding Omarchy's version defines. The old personal tmux.conf,
along with the three other files superseded by the earlier XDG-placement
pass, are preserved (not deleted) — see "Not yet done" below.

**Verified before merging** — not assumed: read Omarchy's official manual
and a live GitHub issue confirming `omarchy update` can and does overwrite
user customizations under `~/.config/*` for files that are also part of
Omarchy's own default set (`~/.config/hypr/bindings.conf` was reported
overwritten in one case). Omarchy's own manual explicitly frames
`~/.config/*` as "your files, your changes" and recommends a dotfiles tool
(they mention Stow) to track and reapply customizations after updates —
which validates chezmoi-managing these files as the right call, but also
means: once `chezmoi apply` owns a file like `hypr/bindings.lua`, a future
`omarchy update` that changes Omarchy's own default for that file will get
silently overwritten back to this chezmoi-tracked version on the next
`chezmoi apply`, unless the user notices and re-syncs. This is normal,
expected chezmoi behavior (not a bug) but worth knowing going in.

**Validated**: re-ran the full apply against a scratch `$HOME` with the real
chezmoi binary after the merge — all 42 new files land at the correct
`.config/` path, `nvim/dot_gitignore` → `.config/nvim/.gitignore` correctly,
`symlink_theme.lua` materializes as an actual symlink (not a text file) with
the correct relative target, the merged tmux.conf renders with the personal
addition appended, and a second `apply` is still a no-op diff (idempotent).

**Cleanup**: the source `archdots/omarchyconfig/` folder (now fully merged)
and the four files superseded by the earlier XDG-placement pass were moved
into a single consolidated `archdots/_to_delete/` folder on the user's
machine (file deletion isn't available over the device bridge) — contains
`_to_delete/omarchyconfig/` (the now-redundant source copy) and
`_to_delete/home-dot_config-old/` (`dot_curlrc`, `dot_gitconfig.tmpl`,
`dot_gitignore`, `dot_tmux.conf` — all superseded in the XDG-placement pass).
User should delete this folder once satisfied everything landed correctly.

### XDG placement decision (2026-08-19, first follow-up)

User asked whether all dotfiles should move under `~/.config/` for one
uniform convention. Verified per-tool XDG support before deciding (see
Sources) rather than assuming:

- **Moved** (native XDG support, free win, confirmed via docs): git
  (`~/.config/git/config`, `~/.config/git/ignore` — git reads both
  automatically; dropped the now-redundant `core.excludesfile = ~/.gitignore`
  line from gitconfig since it's no longer needed), tmux
  (`~/.config/tmux/tmux.conf` — only used as a fallback if `~/.tmux.conf`
  doesn't exist, which is now the case), curl (`~/.config/curlrc` — flat,
  no `curl/` subfolder, since that's the literal path curl checks as of
  7.73.0, unlike git/tmux's subfolder convention).
- **Left at top-level** (no native XDG support, moving would require a
  stub/shim or an externally-set env var for no functional benefit): bash
  (`.bashrc`/`.bash_profile`/`.bash_logout` — bash has never implemented XDG
  and never will; a `.config/bash/bashrc` + top-level shim `.bashrc` that
  just sources it was considered and rejected as pure indirection), readline
  (`.inputrc` — confirmed via the upstream CHANGES file going back to
  readline 2.1: no XDG support ever added; would need `INPUTRC` set via
  `~/.config/environment.d/` before the first shell even starts), wget
  (`.wgetrc` — wget2's XDG support is still an open, unresolved GitHub
  issue; would need `WGETRC` set the same way as `INPUTRC`).
- Re-validated the full tree end-to-end with the same real chezmoi binary
  after the move: all four relocated files materialize at the correct
  `.config/` path, the `.chezmoiexternal.toml` doom.d external still works,
  and a second `apply` is still a no-op diff (idempotent).

### Content decisions made during curation (for user's review before commit)

- Dropped everything macOS-only (Hammerspoon, Slate, `osx/`, Mac-only git
  mergetool block) — confirmed scope is Omarchy/Linux-only.
- Dropped `scripts/` entirely — confirmed not applicable to Omarchy.
- **Security fix**: removed `[http] sslverify = false` from gitconfig — this
  was silently disabling TLS verification for all git remotes.
- **Alias/function collisions with newly-installed tools**: `gh` alias
  renamed to `ghist` (shadowed the real GitHub CLI); `tre()` shell function
  dropped (shadowed the new AUR `tre` binary that `install-dev-stack.sh`
  installs).
- Modernizations: `tmux.conf` `mode-mouse` → `mouse on`; `fix-wifi`/
  `wifi-restart` → `systemctl`; `urlencode` → `python3`; `youtube-dl` alias
  → `yt-dlp`.
- Bug fixes ported over: case-sensitivity bug in `p`/`projects` alias,
  smart-quote bug in `gch()`.
- `EDITOR` set to `emacsclient` to match the Doom Emacs setup.
- Dropped dead/superseded tooling: `pyenv`, `fasd`, `liquidprompt` (Omarchy
  already ships `zoxide`/`starship`), Leiningen-specific gitignore section,
  `install_lein()` function.
- Fixed `XDG_RUNTIME_DIR` export; kept `nnn` config and babashka `bbin` path
  (flagged as optional/pre-existing, not removed).
- Fixed zathurarc target path (was incorrectly nested under `bash/` in the
  original repo; now correctly at `~/.config/zathura/zathurarc`).
- 6 git submodules → 1 `.chezmoiexternal.toml` `git-repo` entry so far
  (`doom.d`, the one with real current content); `emacs.d` (superseded by
  Doom), `z`/`fasd`/`liquidprompt` (superseded by zoxide/starship),
  `git-extras`, and the old `dotsync` tool itself were dropped rather than
  re-added as externals, consistent with the "drop superseded/platform-dead"
  list below.
- Dictionary/fonts binary assets and `wallpaper/` not carried over (per the
  original "drop" list — package-manageable or superseded by Omarchy's own
  theme system).

### Validation performed

- Real chezmoi v2.72.0 binary (downloaded directly from GitHub releases,
  not via a package manager) run against the authored tree with a scratch
  `$HOME`: `chezmoi apply` correctly materialized every `dot_*` file at its
  expected path, correctly rendered the `dot_gitconfig.tmpl` template, and
  correctly executed the `.chezmoiexternal.toml` git-repo external (actually
  cloned real `doom.d` content). A second `apply` produced no diff —
  confirmed idempotent. Re-ran the same validation after both the
  XDG-placement pass and the standard-Omarchy-config merge, each time with
  identical (clean, idempotent) results.
- Attempted a second validation exercising the `.chezmoi.toml.tmpl`
  `promptStringOnce` prompt itself non-interactively (piped stdin, then
  `--promptString` CLI flag) — both failed with `could not open a new TTY`.
  Confirmed via upstream issue tracker
  ([twpayne/chezmoi#3345](https://github.com/twpayne/chezmoi/issues/3345))
  that `promptStringOnce` not honoring `--promptString` defaults is a known,
  open chezmoi bug, not a defect in the authored template — irrelevant for
  the user's real usage since `chezmoi init` is always run interactively in
  a real terminal on an actual machine.
- `shellcheck -S warning` and `bash -n` clean on `install-dev-stack.sh` after
  the chezmoi/bitwarden-cli additions.

## Not yet done / future work

- No Bitwarden-backed secret templates exist yet (no live secrets were found
  in the original repo, so there was nothing to migrate). The pattern is
  documented in the new `README.md`'s "Secrets" section for when the first
  one (e.g. SSH key, GPG key, API token) is added.
- User has not yet reviewed or committed the changes — this is intentional,
  per their explicit preference to handle git themselves.
- Per-machine (`.chezmoi.hostname`/`.chezmoi.os`) branching is documented as
  available but no second machine's specific overrides have been authored
  yet, since only one machine's config was in scope for this pass. Good
  future candidates once a second machine is added: `hypr/monitors.lua`
  (hardware-specific monitor scale/layout) and `hypr/looknfeel.lua`/
  `input.lua` if per-device tweaks are ever needed.
- `archdots/_to_delete/` on the user's machine holds everything superseded
  across both follow-up passes — user needs to delete that folder manually
  once satisfied (file deletion isn't available over the device bridge).
- Worth watching: since `hypr/`, `nvim/`, and the rest of the standard
  Omarchy config set are now chezmoi-managed, a future `omarchy update`
  that changes one of those defaults won't "stick" until the user notices
  and re-syncs it into the chezmoi source — see the merge section above.

## Source repo audit

Cloned and read `https://github.com/skovuri41/dotfiles` directly (230 tracked files, 6 git submodules). Findings:

- **No live secrets found.** Grepped for password/token/api-key/private-key patterns across all text files — only false positives (mpd.conf comments, dictionary words, an `offlineimap.py` script that reads from macOS Keychain rather than storing a secret). Bitwarden work here is about setting up a good pattern going forward, not remediating a leak.
- **Multi-era, multi-OS accumulation, pre-dates Omarchy entirely.** Zero Hyprland/Wayland/Quickshell config exists. Heavy X11-era WM config (`i3`, `kwm`, `compton`, `regolith`, raw `xenv/Xresources` etc.), macOS-only material (`hammerspoon/`, `osx/`, `slate/`), and several tools already superseded by what's on the Omarchy box now: `fasd`/`z` → `zoxide` (already in Omarchy base), `liquidprompt` → `starship` (already in Omarchy base), `lein`/`boot` → Clojure CLI (already mise-managed), `ag` → `ripgrep` (already in Omarchy base).
- **6 git submodules**: `dotsync` (their old symlink-based dotfiles tool — replaced by chezmoi), `emacs.d` (old pre-Doom personal Emacs config, `surya46584/emacs.d`), `doom.d` (their **real, current Doom Emacs config**, `skovuri41/doom.d` — this replaces the vanilla Doom setup `install-dev-stack.sh` bootstrapped), `z`, `fasd`, `liquidprompt`, `git-extras`.
- **Binary assets committed directly**: a full dictionary package and ~90 font files (should be package-managed or fetched, not sitting in a dotfiles git history).
- **`git/gitconfig` has machine-specific and macOS-specific content** baked in: `mergetool "mvimdiff"`/`opendiff` (MacVim/FileMerge, Mac-only), `sslverify = false` under `[http]` (a real problem — disables TLS verification for git globally, not carried forward), and `[include] path = .gitconfig.user` (a pre-existing pattern for a local per-machine override file — maps naturally onto chezmoi templating).
- **Old `dotsyncrc`** already had a rudimentary per-hostname section (`[hosts]`, e.g. `shakti git=ANY`) — confirms they've wanted per-machine handling before; chezmoi's templating is the direct upgrade path for that instinct.

## Target structure (chezmoi) — as built

- `.chezmoiroot: home` in the repo root, so the actual chezmoi source tree lives under `home/` and the repo root stays free for the README and `install-dev-stack.sh`.
- Standard chezmoi naming (`dot_bashrc`, `dot_config/git/config.tmpl`, `dot_config/tmux/tmux.conf`, `dot_config/curlrc`, `dot_config/zathura/zathurarc`, `dot_config/nvim/dot_gitignore`, `dot_config/nvim/lua/plugins/symlink_theme.lua`) — XDG-native tools live under `dot_config/`, tools with no XDG support stay flat at top-level (see "XDG placement decision" above), and everything shipped with the standard Omarchy install now lives under `dot_config/` too (see the merge section above). Effectively all config on the machine is chezmoi-managed now, per the user's request.
- **`.chezmoiexternal.toml` replaces the git submodules.** `type = "git-repo"` externals clone-then-`git pull` a repo straight into the target path, preserving that target's own `.git` history — so `~/.config/doom` stays a normal, independently-committable git repo pointing at `skovuri41/doom.d`, refreshed automatically on `chezmoi apply`/`chezmoi update`.
- Per-machine data: `.chezmoi.toml.tmpl` currently only prompts name/email; `.chezmoi.hostname`/`.chezmoi.os` built-ins are available and documented for future per-host branching, none authored yet (single machine in scope).

## Division of labor going forward

- **`install-dev-stack.sh`** stays the source of truth for *software* — packages, language runtimes, Doom Emacs's underlying Emacs binary itself. Now includes `chezmoi` and `bitwarden-cli` in its registry.
- **chezmoi** is the source of truth for *all configuration content*, standard-Omarchy and personal alike, as of the merge above. A fresh Omarchy box: `chezmoi init --apply` first, then `./install-dev-stack.sh` (order documented in `README.md`, and matters for Doom's config directory — see that file's "Why this order matters" section).

## Sources consulted

- [chezmoi.io comparison table](https://www.chezmoi.io/comparison-table/), [chezmoi Bitwarden integration docs](https://www.chezmoi.io/user-guide/password-managers/bitwarden/), [.chezmoiexternal.toml reference](https://www.chezmoi.io/reference/special-files/chezmoiexternal-format/), [promptStringOnce reference](https://www.chezmoi.io/reference/templates/init-functions/promptStringOnce/), [chezmoi setup guide](https://www.chezmoi.io/user-guide/setup/)
- [Arch Linux package: bitwarden-cli](https://archlinux.org/packages/extra/x86_64/bitwarden-cli/)
- [twpayne/chezmoi#3345](https://github.com/twpayne/chezmoi/issues/3345) — `promptStringOnce` doesn't honor `--promptString` CLI defaults (confirms the sandbox TTY validation failure is an upstream limitation, not a template defect)
- Direct read of `github.com/skovuri41/dotfiles` (clone + full file listing + secret-pattern grep + key file reads: `.gitmodules`, `dotsyncrc`, `git/gitconfig`, `bash/exports`, `boot/boot.properties`)
- Real chezmoi v2.72.0 binary (github.com/twpayne/chezmoi releases) used for local apply/idempotency validation
- [curl config file docs](https://everything.curl.dev/cmdline/configfile.html), [curl 7.73.0 changelog](https://curl.se/ch/7.73.0.html) — `$XDG_CONFIG_HOME/curlrc` support confirmed
- [tmux.1 man page (current)](https://raw.githubusercontent.com/tmux/tmux/master/tmux.1) — `$XDG_CONFIG_HOME/tmux/tmux.conf` fallback confirmed
- [git gitignore docs — core.excludesFile](https://git-scm.com/docs/gitignore/2.33.0) — `$XDG_CONFIG_HOME/git/ignore` default confirmed
- [Making Bash compliant with XDG Base Directory](https://hiphish.github.io/blog/2020/12/27/making-bash-xdg-compliant/) — confirms bash has no native XDG support
- [readline CHANGES](https://tiswww.case.edu/php/chet/readline/CHANGES) — confirms no XDG support added in any version through 8.3
- [wget2 XDG config-file handling discussion](https://github.com/rockdaboot/wget2/issues/133) — confirms wget/wget2 XDG support is still unresolved
- [Omarchy manual — Dotfiles](https://learn.omacom.io/2/the-omarchy-manual/65/dotfiles) — confirms `~/.config/*` is meant for user customization and recommends a dotfiles tool to track it
- [basecamp/omarchy#1802](https://github.com/basecamp/omarchy/issues/1802) — real-world report of `omarchy update` overwriting a user-customized `~/.config/hypr/bindings.conf`, confirming the "future work" caveat above
