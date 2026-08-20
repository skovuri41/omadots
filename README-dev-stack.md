# Omarchy dev stack

`install-dev-stack.sh` installs and then keeps current: Java, Maven, Clojure CLI, Polylith, Node/npm (LTS), Emacs + Doom Emacs (as a systemd --user daemon), uv, curl, sqlite, tree, tre, jq, zathura, Citrix Workspace (icaclient), chezmoi, the Bitwarden CLI, and the GitHub CLI (`gh`).

**Run it with no arguments to install/upgrade everything. Run it with `--status` to see a table of what's installed and what's newer upstream, with no changes made.** After the first run, **`omarchy update` is the only maintenance command you need** — the script wires itself into Omarchy's own update pipeline (see "Ongoing maintenance" below).

**Verified against Omarchy 4.0.0 "Quattro"** (tagged 2026-08-14, checked directly against the `basecamp/omarchy` `v4.0.0` tag). Quattro's headline changes — Quickshell replacing Waybar/Mako/hyprlock/etc., Lua-based Hyprland config, Limine snapshot rollback, the new pacman-upgrade guard — don't touch anything this script relies on. One thing did change and has been fixed here: **the base package is now named `mise`, not `mise-bin`** (only matters on the rare box where mise isn't already present, since Omarchy ships it in the base install either way). Everything else — `omarchy-pkg-add`, the `dev-env` installer's `java`/`clojure` commands, the `omarchy-emacs`/Doom conflict, and the `~/.config/omarchy/hooks/post-update.d/` mechanism — is byte-for-byte the same on Quattro as it was going in. The new pacman-upgrade guard (`00-omarchy-update-guard.hook`, blocks direct `pacman -Syu`) only fires on a combined sync+sysupgrade transaction — `omarchy-pkg-add`'s plain `pacman -S <pkg>` calls (used throughout this script) don't trigger it.

## Design principles

- **Same method Arch/Omarchy would use.** Official pacman package first, AUR (via `yay`, through Omarchy's own `omarchy-pkg-aur-add`) second, and a raw GitHub-release download only when nothing else exists (that's just Polylith — see below).
- **Skip what's already standard.** Every install step checks before it acts (`omarchy-pkg-add` itself is idempotent; `mise use` is a no-op if already current; Polylith/Doom compare versions before touching anything). Of everything on this list, only `jq` ships in Omarchy's base packages already — the script still "installs" it, which is just a no-op confirming that.
- **Failsafe.** No single tool failing can stop the rest. Every step is wrapped so a failure is logged into a summary at the end instead of aborting the script. Citrix Workspace is the one item that's genuinely likely to fail unattended (see below), and it's handled explicitly rather than generically.
- **One script, both jobs.** The script copies itself to `~/.local/share/dev-stack/install-dev-stack.sh` on first run and registers *that* copy as an Omarchy post-update hook. `omarchy update` re-runs the exact same script — since every step is idempotent, a re-run just is the upgrade path. There's no second hand-rolled updater to keep in sync with this one.

## Adding software without touching the script

The software list isn't in `install-dev-stack.sh` - it's in **`dev-stack-software.txt`**, a plain pipe-delimited text file next to it: one line per tool, `name|method|spec|status_pkg|note`. To add, remove, or change anything pacman/AUR/mise can install, edit that file. The script re-reads it on every run (including via the `omarchy update` hook - `install_hook()` copies both files together, so the hook always re-runs against the same list it was set up with) and never needs a code change for it. A plain-text format was chosen deliberately over YAML: the schema is flat (five fields, no nesting), so YAML would only add a new dependency (`yq`) with no structural benefit.

Not sure how a new tool should be installed? Ask the script:

```bash
./install-dev-stack.sh --check <name>
```

This probes pacman/Omarchy repos, the AUR (via `yay`), and mise's registry for that name (exact match first, fuzzy suggestions if there isn't one) and prints a suggested `dev-stack-software.txt` line, using this precedence: **pacman > mise > AUR > custom**. It's read-only - it never installs anything or edits the file for you; you paste the suggested line in yourself. Example:

```
$ ./install-dev-stack.sh --check ripgrep
...
-- Suggestion --
Add to dev-stack-software.txt:
  <Display Name>|pacman|ripgrep|ripgrep|
```

The script itself never lists individual tools - `run_install()` just loops over the registry loaded from `dev-stack-software.txt` and dispatches each line on its `method` field (`pacman`/`aur`/`aur-fragile`/`mise` are handled fully generically; an unrecognized `method` is skipped with a warning, never silently ignored).

**One thing genuinely still needs a script edit: a truly bespoke ("custom") install** - something with no pacman/AUR/mise package at all, like Doom Emacs or Polylith. `custom` entries in the text file are wired to one of a small, fixed set of functions in the script by their `status_pkg` value, via a `dispatch_custom()` lookup; adding a new one means adding a `case` + function there. A `custom` entry whose `status_pkg` has no matching case fails loudly in the run summary rather than doing nothing, so a typo or a genuinely new bespoke tool is impossible to miss. This was a deliberate choice over a fully pluggable "point at an external installer script" mechanism - bespoke installs are rare (2 of the 20 tools on this list, plus the Emacs daemon step) and a fixed function is simpler to read, debug, and trust than a plugin contract with no real payoff at this scale.

**Idempotent PATH handling for custom installs.** Any custom install that needs a PATH addition (Doom Emacs's `~/.config/emacs/bin`, so far) writes it through a shared helper, `dev_stack_path_add`, into `~/.config/dev-stack/env.sh` - never directly into `~/.bashrc` or any other file chezmoi manages. That matters because chezmoi overwrites every file it manages from its own source state on every `chezmoi apply` - anything appended directly to a chezmoi-managed file by this script would silently vanish on the next apply. Instead, `home/dot_bash_exports` (chezmoi-managed) sources `env.sh` once, unconditionally; this script only ever writes inside `env.sh` after that, and only appends a line if it isn't already there.

## What gets installed, and why this shape

**Java, Maven, Clojure CLI, Node.js — via `mise`.** Omarchy already ships `mise` in its base packages and already wires `eval "$(mise activate bash)"` into the default shell rc. `omarchy update` already runs `mise up` (as `omarchy-update-mise`) for every mise-managed tool, so these get free ongoing maintenance.

- `mise use --global java@latest` — tracks the newest OpenJDK build. Pin to an LTS instead with e.g. `mise use --global java@21`.
- `mise use --global maven@latest`
- `mise use --global clojure@latest`, plus `rlwrap` (a system package) for a usable REPL — same as Omarchy's own `omarchy install dev-env clojure` does.
- `mise use --global node@lts` — **deliberately `@lts`, not `@latest`/`@current`**, per your ask for stable-only. mise resolves `lts` to whatever the current Node LTS major is (24 at the time of writing) and re-resolves it on every `mise up`, so it tracks the LTS line rather than the bleeding-edge release train. npm comes bundled with Node, no separate install needed.

**Polylith (`poly`) — the one genuinely GitHub-only tool.** There's no Arch or AUR package. Polylith's own docs specify a stand-alone install for Linux: download the release jar, drop it somewhere, and write a tiny wrapper shell script that execs `java -jar`. The script does exactly that, and additionally:

- Resolves "latest" by following the redirect from `github.com/polyfy/polylith/releases/latest` to its tag (no GitHub API call, so no rate-limit risk).
- Stores the jar at `~/.local/share/dev-stack/polylith/poly-<version>.jar` and writes `~/.local/bin/poly`.
- On every run (including via the `omarchy update` hook), re-checks the latest tag and only re-downloads if it's newer than what's on disk — so re-running is the upgrade mechanism, same as everything else here.

**uv — the official Arch package, not AUR.** `uv` (Astral's Python package/project manager) has its own official package in Arch's `extra` repo now (separate from `python-uv`, which is the Python bindings library — not what you want). Plain `omarchy-pkg-add uv`.

**Emacs — the official Arch package, not AUR.** Arch's `emacs-wayland` package is currently 30.2, built with native compilation and PGTK (pure-GTK, native Wayland rendering — the right choice under Hyprland instead of the X11-only `emacs` package). 30.2 is also Doom's own recommended max version. It's a normal `pacman` package, so it updates with every `omarchy update`.

There's a separate AUR package, `omarchy-emacs`, that gives Emacs theme/font syncing with Omarchy's theme switcher. It's deliberately **not** used here: it manages `~/.config/emacs/init.el` itself, the same file Doom Emacs owns, and the two conflict.

**Doom Emacs — git clone, hooked into Omarchy's update system.** Doom isn't tracked by Arch or Omarchy, so it needs its own updater (`doom upgrade && doom sync`). The script's re-run behavior handles this directly now: if `~/.config/emacs` already exists, it runs `doom upgrade --force && doom sync --force` instead of cloning again. Doom's language/feature modules (including `clojure` and `java`) live in a separate `doomemacs/modules` repo pulled in as a git submodule; `doom install`/`doom upgrade` fetch/update that on their own.

The script enables `:lang java` and `:lang clojure` in `~/.config/doom/init.el` (uncommenting the relevant lines in Doom's generated template — only on first install, since after that it's your file to edit), then runs `doom sync` to pull in CIDER, clojure-mode, clj-refactor, etc.

**Emacs daemon — systemd --user service, launcher-integrated.** Right after Doom is installed/upgraded, the script enables `~/.config/systemd/user/emacs.service` (`systemctl --user daemon-reload && systemctl --user enable --now emacs.service`) — a unit file that comes from chezmoi (`omadots/home/dot_config/systemd/user/emacs.service`), not from this script, per the project's "chezmoi owns config, this script owns software" split. That means `chezmoi apply` has to run before this script on a fresh box, same as it already does for Doom's config — see `README.md`'s run order.

With the daemon running persistently from login onward:

- `emacsclient -c` (the `ec` alias) opens a **new graphical frame** against the always-on daemon instead of cold-starting Emacs every time.
- `emacsclient -t` (the `emax` alias) opens a **terminal text-mode frame** in the current terminal, same daemon.
- `emacsclient --eval '(kill-emacs)'` (the `ekill` alias) **cleanly shuts down the daemon and every attached frame/client at once** — since they're all just connections to one process, there's nothing to individually close.
- A `.desktop` entry at `~/.local/share/applications/emacs.desktop` (also from chezmoi) points Omarchy's app launcher at `emacsclient -c -a "" %F` instead of a plain `emacs` binary launch, so opening Emacs from the launcher reuses the daemon too. `~/.local/share/applications` is searched before `/usr/share/applications` per the XDG spec, so this overrides whatever entry the `emacs-wayland` package itself may ship — worth a quick look in the launcher after first setup in case both show up (rename or remove the extra one if so; hasn't been confirmed either way against the exact package contents).

Full alias list and the daemon's systemd design (why `-c`/`-t` don't need any Wayland-display-forwarding tricks to work) are in `CHEZMOI-GUIDE.md`.

**curl, sqlite, tree, jq, zathura — plain pacman packages**, none of which ship in Omarchy's base install except `jq`. `zathura` is installed together with `zathura-pdf-mupdf`, since zathura has no file-type support at all without a backend plugin — mupdf is the commonly recommended one.

**tre — AUR only (`tre-command`).** This is the Rust rewrite of `tree(1)` (respects `.gitignore`, colorized by default), not a typo of `tree` — both are installed since you asked for both. Built via `yay`/`makepkg` like any other AUR package, no manual steps needed.

**Citrix Workspace (`icaclient`) — AUR, but flagged as fragile on purpose.** This is the one package on the list that commonly can't finish unattended: Citrix gates the Linux Workspace app tarball behind a login/EULA wall on their own site, so `makepkg`'s automatic download frequently fails with no way around it from a script. The script tries `omarchy-pkg-aur-add icaclient` first — if your AUR mirror/cache already has the tarball cached, or the AUR package changes to no longer need it, it'll just work. If it fails, the script prints exactly what to do (download the tarball from citrix.com yourself, then re-run `yay -S icaclient`), marks it in the status table as "ACTION NEEDED," and moves on to finish everything else rather than stopping.

**GitHub CLI (`gh`) — official Arch package, `github-cli`.** Not to be confused with the AUR `github-cli-bin` prebuilt or the old `hub` tool. Installing the package only gets you the binary — it isn't authenticated on install (there's no unattended-safe way to do OAuth device-flow login from a script), so run `gh auth login` once yourself after the script finishes. This is also the tool `home/dot_bash_aliases`' `ghist` alias was named around: the original dotfiles' `gh` alias was renamed to `ghist` specifically so it wouldn't shadow this once it was installed (see `README.md`'s "What changed from the old dotfiles repo").

## Running it

```bash
chmod +x install-dev-stack.sh
./install-dev-stack.sh              # install everything (safe to re-run / upgrade with)
./install-dev-stack.sh --status     # read-only table, no changes
./install-dev-stack.sh --check foo  # read-only: how would 'foo' get installed?
```

Everything is idempotent, so running it again is both how you retry a failure and how you'd manually trigger an upgrade outside of `omarchy update`.

## The `--status` table

```
$ ./install-dev-stack.sh --status
Checking installed vs. available versions...
(pacman upgrade check via 'checkupdates', AUR via 'yay -Qua' - both read-only, no sudo)

SOFTWARE             METHOD       INSTALLED      LATEST         STATUS
----------------------------------------------------------------------------------
Java                  mise        21.0.5         25             UPDATE AVAILABLE
Maven                 mise        3.9.9          3.9.9          OK
...
Citrix Workspace      aur-fragile -              -              NOT INSTALLED
```

Pacman-tracked upgrade checks use `checkupdates` (from `pacman-contrib`, already in Omarchy's base packages) — it does a safe, non-root, temp-directory sync-db check, so this never needs `sudo` and never touches your real package db. AUR-tracked checks use `yay -Qua`. Both are read-only.

## Verifying

```bash
java -version
mvn -version
clj --version
node --version && npm --version
poly version
uv --version
emacs --version
doom doctor          # Doom's own health check; run after first launch
systemctl --user status emacs   # daemon should be "active (running)"
emacsclient -e '(+ 1 2)'        # => 3, confirms a client can actually reach it
gh --version
gh auth status       # will say "not logged in" until you run 'gh auth login' once
```

## Ongoing maintenance

Just:

```bash
omarchy update
```

This one command now updates: system packages (including Emacs, uv, curl, sqlite, tree, jq, zathura), AUR packages (tre, icaclient), every mise-managed tool (Java, Maven, Clojure, Node), Doom Emacs, and Polylith — because the post-update hook it installs just re-runs `install-dev-stack.sh` itself. The daemon re-enable step is a no-op on every run after the first (`systemctl --user enable --now` is idempotent) — it only restarts the daemon if the Emacs package itself was upgraded and the unit's `Restart=on-failure` triggers, not on every `omarchy update`.

If you want to update mise tools only, right now, without a full `omarchy update`: `mup` (an alias Omarchy already defines for `MISE_MINIMUM_RELEASE_AGE=0 mise up`).

## Optional follow-ups (not automated on purpose)

- **LSP for Java/Clojure.** The script enables the `java` and `clojure` Doom modules *without* the `+lsp` flag, so first setup doesn't silently depend on a language server that isn't installed yet. To add it later:
  1. Install a language server — e.g. `clojure-lsp` (AUR, or a release binary) for Clojure, and `eclipse.jdt-ls` for Java (also AUR).
  2. In `~/.config/doom/init.el`, change `clojure` to `(clojure +lsp)` and `java` to `(java +lsp)`, and uncomment `;;(lsp +eglot)` (or plain `lsp`) under `:tools`.
  3. Run `doom sync`.
- **Adding more languages later.** Omarchy has the same pattern built in for others: `omarchy install dev-env <ruby|go|python|rust|...>`. Anything installed through `mise use --global` gets the same free maintenance via `omarchy update`.
- **Pinning versions per-project instead of globally.** Drop a `.mise.toml` in a project directory with e.g. `java = "21"` and `mise` will use that version whenever your shell is inside that directory, overriding the global default.
- **Finishing Citrix Workspace manually**, if the automated attempt failed — see the dedicated note above.
- **Authenticating the GitHub CLI.** `gh auth login` once per machine (interactive OAuth device-flow login, deliberately not automated) — everything after that (`gh repo clone`, `gh pr create`, etc.) works without further setup.
- **Restarting the Emacs daemon after an Emacs version upgrade.** `omarchy update` upgrades the `emacs-wayland` package on disk, but a daemon that's already running keeps using the old binary in memory until it's restarted — the script deliberately does *not* force this automatically (it would kill every open Emacs frame and unsaved buffer without warning on every update). Restart it yourself when convenient: `systemctl --user restart emacs` (or just `ekill` and let the next `ec`/`emax` auto-start it fresh).

## Sources

- [mise registry: java](https://mise.jdx.dev/lang/java.html), and the [mise registry.toml entries](https://github.com/jdx/mise/tree/main/registry) for `maven` and `clojure` (confirms both resolve automatically to asdf/vfox/aqua backends under those short names, no manual plugin-add step)
- [mise node.rs source](https://github.com/jdx/mise/blob/main/src/plugins/core/node.rs) — confirms the `lts` alias exists and what it currently resolves to
- [mise `current`](https://mise.jdx.dev/cli/current.html) and [`latest`](https://mise.jdx.dev/cli/latest.html) CLI docs — exact output format used for the status table
- [basecamp/omarchy](https://github.com/basecamp/omarchy) — `bin/omarchy-install-dev-env`, `bin/omarchy-pkg-add`, `bin/omarchy-pkg-aur-add`, `bin/omarchy-update`, `bin/omarchy-hook`, `install/user/mise.sh`, `install/omarchy-base.packages` / `install/omarchy-other.packages` (confirms mise is base-installed, dev-env conventions, the post-update hook mechanism, and which of the requested tools — only `jq` — are already standard)
- [basecamp/omarchy `v4.0.0` tag](https://github.com/basecamp/omarchy/releases/tag/v4.0.0) — checked directly against this tag (released 2026-08-14) for the Quattro review
- [Arch Linux package: emacs-wayland](https://archlinux.org/packages/extra/x86_64/emacs-wayland/) — 30.2-3, PGTK + native-comp
- [Arch Linux package: uv](https://archlinux.org/packages/extra/x86_64/uv/) — official package, distinct from `python-uv`
- [Arch Linux package: github-cli](https://archlinux.org/packages/extra/x86_64/github-cli/) — official `extra` package, provides the `gh` command
- [scottjones/omarchy-emacs](https://github.com/scottjones/omarchy-emacs) — confirms the `~/.config/emacs/init.el` conflict with Doom
- [doomemacs/core README](https://github.com/doomemacs/core) and [doomemacs/modules](https://github.com/doomemacs/modules) — install commands, module repo split, `lang/clojure`/`lang/java` module contents
- [polyfy/polylith `doc/install.adoc`](https://github.com/polyfy/polylith/blob/master/doc/install.adoc) — official stand-alone Linux install method (jar + wrapper script); [releases](https://github.com/polyfy/polylith/releases) for the current version (v0.3.32 at time of writing)
- [dduan/tre](https://github.com/dduan/tre) and the `tre-command` AUR package — confirms `tre` is a real, distinct tool (tree(1) rewrite), not a typo
- [AUR: icaclient](https://aur.archlinux.org/packages/icaclient) and long-standing Arch community reports — Citrix's download-gate behavior behind the AUR build (page itself is bot-walled from automated fetches, so this is corroborated via community threads rather than the PKGBUILD directly — flagged as the one lower-confidence item here)
- `checkupdates` (pacman-contrib) and `yay -Qua` — standard non-root ways to check for available updates without touching the system package db
- [Running Emacs with systemd](https://emacsredux.com/blog/2020/07/16/running-emacs-with-systemd/) — the `--fg-daemon` + `Type=simple` systemd unit pattern this script/chezmoi tree follows
- [GNU Emacs manual: emacsclient Options](https://www.gnu.org/software/emacs/manual/html_node/emacs/emacsclient-Options.html) and the [Arch manual page](https://man.archlinux.org/man/emacsclient.1.en) — confirms every flag used in the `ec`/`emax`/`semacs`/`ekill` aliases (`-c`, `-t`, `-n`, `-q`, `-u`, `-a`, `-T`/TRAMP prefix, `--eval`)
- XDG Base Directory / Desktop Entry spec — `$XDG_DATA_HOME` (`~/.local/share`) is searched before `$XDG_DATA_DIRS` (`/usr/share`), which is why a user-level `emacs.desktop` overrides a system one of the same name
