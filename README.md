# omadots

*(renamed from `archdots` on 2026-08-20 - same repo, same content, new name. If you have an old clone lying around, `git remote -v` still points at whatever URL you cloned; nothing here depends on the local folder being named any particular thing.)*

Personal Omarchy Linux (Arch-based) setup, split into two independent, composable pieces:

| Piece | What it manages | Tool |
|---|---|---|
| `home/` (chezmoi source state) | dotfiles: shell, git, tmux, readline, zathura, doom.d, the Emacs daemon's systemd unit + launcher entry | [chezmoi](https://www.chezmoi.io/) + [Bitwarden CLI](https://bitwarden.com/help/cli/) |
| `install-dev-stack.sh` + `dev-stack-software.txt` | dev tools: Java, Clojure, Maven, Node, Emacs, Doom Emacs (as a systemd --user daemon), Polylith, uv, curl, sqlite, tree, tre, jq, zathura, Citrix Workspace, chezmoi, Bitwarden CLI, GitHub CLI | `mise`, pacman, AUR, self-updating hook |

They're deliberately decoupled: chezmoi never installs software, and `install-dev-stack.sh` never touches your dotfiles.

**Browsable docs.** `docs/index.html` is this README, `README-dev-stack.md`, and `CHEZMOI-GUIDE.md` rendered as one Tailwind-styled page (sidebar nav, per-doc outline, dark mode) - open it directly in a browser, no server needed. It's fully self-contained (no CDN calls at load time). Regenerate it after editing any of the three source `.md` files:

```sh
npm install        # one-time, installs the local Tailwind CLI
npm run docs:build  # or: python3 docs/build_docs.py
```

## Setting up a brand new laptop

This is the full sequence for a laptop that already has **Omarchy 4** installed and booted, and nothing else done yet. Follow it in order - later steps depend on earlier ones.

**0. Prerequisites.** You're logged into a normal (non-root) user account, connected to the internet, and have a terminal open. That's it - everything else below is installed as part of the sequence.

**1. Install chezmoi and the Bitwarden CLI.**

```sh
sudo pacman -S chezmoi bitwarden-cli
```

These two have to exist *before* anything else, since step 3 uses chezmoi to lay down every other dotfile. (`install-dev-stack.sh` also installs both later, as part of its normal registry-driven pass - that's fine, `pacman -S` on an already-installed package is a no-op. This manual step just breaks the chicken-and-egg problem of needing chezmoi to bootstrap, before the script that chezmoi's own tree points you at can run.)

**2. Log into Bitwarden.**

```sh
bw login
bw unlock
```

Needed so chezmoi's `bitwarden`/`bitwardenAttachmentByRef` template functions can fetch secrets during `apply` (`bitwarden.unlock = "auto"` in `.chezmoi.toml.tmpl` means chezmoi calls `bw unlock` itself from then on - you only do this by hand once, right after `bw login`). Nothing in this repo currently templates a live secret (see "Secrets" below), so this step is skippable *today* - but do it anyway, since the first time you add one (an SSH key, per `CHEZMOI-GUIDE.md`) is exactly when you don't want to be debugging an unauthenticated `bw` mid-`apply`.

**3. Bootstrap dotfiles from this repo.**

```sh
chezmoi init --apply git@github.com:skovuri41/omadots.git
```

(Swap in your actual repo URL if it's not that one.) This one command: clones the full repo into `~/.local/share/chezmoi`, prompts once for your git name/email (`promptStringOnce` - cached after this, never asked again on this machine), applies every `dot_*`/`dot_config/*` file to your real `$HOME`, and - via `.chezmoiexternal.toml` - clones your actual `doom.d` config into `~/.config/doom`, so it's already in place before Doom Emacs itself is installed in step 5.

Confirm it landed cleanly:

```sh
chezmoi diff        # should print nothing - a fresh apply has nothing left to change
ls ~/.config/doom    # your real Doom config, not a placeholder
```

**4. Find the dev-stack installer.** `chezmoi init` cloned the *entire* repo, not just the `home/` subtree it applies to `$HOME` - `install-dev-stack.sh`, `dev-stack-software.txt`, and this README all live at the top of that same clone, one level up from where `chezmoi cd` drops you:

```sh
cd ~/.local/share/chezmoi
./install-dev-stack.sh
```

**5. Install the dev stack.** (This is that same command, run from that directory.) Idempotent and safe to re-run. It registers itself as an `omarchy update` post-update hook, so Java/Clojure/Maven/Node stay current via `mise`, and Doom Emacs/Polylith stay current via the same script, on every future `omarchy update` - no separate maintenance step from here on.

Check what's installed and what's upgradable any time:

```sh
./install-dev-stack.sh --status
```

The actual software list lives in `dev-stack-software.txt`, not in the script - add/remove/change a tool there and the script never needs to change for it. Not sure how a new tool should be installed? `./install-dev-stack.sh --check <name>` probes pacman/AUR/mise for it and suggests a line to add. See `README-dev-stack.md` for the full tool-by-tool rationale, the file format, and verification steps.

**6. Pick up new PATH entries.** Open a new terminal, or `source ~/.bashrc` in your current one - this loads anything the dev-stack script's custom installs added (currently Doom Emacs's `bin/`) via its idempotent PATH mechanism (see `README-dev-stack.md`).

**7. Authenticate the GitHub CLI.** `gh auth login` once - the package installs the `gh` binary, but interactive OAuth login is deliberately not automated by the script.

**8. Spot-check the pieces that talk to each other.**

```sh
./install-dev-stack.sh --status      # everything should read OK (or NOT ENABLED for
                                      # the Emacs daemon if step 3 didn't apply first)
doom doctor                          # Doom's own health check
systemctl --user status emacs        # daemon should be "active (running)"
emacsclient -e '(+ 1 2)'             # => 3, confirms a client can actually reach it
gh auth status                       # confirms step 7 took
```

That's the whole sequence. From here on, day-to-day maintenance is just `omarchy update` (covers both the dev stack and, if you `chezmoi update` alongside it, your dotfiles) - see "Ongoing maintenance" in `README-dev-stack.md` and the "Everyday commands" table in `CHEZMOI-GUIDE.md`.

## Day-to-day chezmoi commands

```sh
chezmoi diff      # preview what would change
chezmoi apply     # apply local edits under ~/.local/share/chezmoi
chezmoi update    # git pull + apply, picks up changes pushed from another machine
chezmoi cd        # cd into the source directory's home/ subtree (see step 4 above for
                   # the repo-root-level files, like install-dev-stack.sh, that chezmoi
                   # cd doesn't take you to)
```

Per-host differences (multiple machines): use chezmoi's built-in
`.chezmoi.hostname` / `.chezmoi.os` template variables directly in any
`.tmpl` file, or add host-specific data under `[data]` in
`home/.chezmoi.toml.tmpl` and branch on it. Nothing extra to install.
Full day-to-day reference (worked examples, merge conflicts, etc.) is in
`CHEZMOI-GUIDE.md`.

## Why this order matters

`install_doom()` in `install-dev-stack.sh` runs `doom install`. If chezmoi
already placed your real config at `~/.config/doom` (step 3, above), Doom
finds it there and leaves it alone. If you skip step 3 and run the dev-stack
script first, Doom will generate its own default `~/.config/doom` from its
example template - then chezmoi's git-repo external in step 3 will just
overwrite that directory with your real config on the next `chezmoi apply`,
so nothing breaks either way, but doing it in the documented order avoids a
throwaway Doom config existing on disk even briefly.

Same reasoning applies to the Emacs daemon: `install-dev-stack.sh` enables
`~/.config/systemd/user/emacs.service` right after installing Doom, but that
unit file (and the `~/.local/share/applications/emacs.desktop` launcher
entry) comes from chezmoi, not the script. Skip step 3 and the daemon step
just logs "unit file not present, skipped" and moves on (failsafe, not
fatal) - run `chezmoi apply` and re-run the script to pick it up.

Once it's running: `ec` opens a new graphical frame, `emax` a terminal-mode
frame, `ekill` cleanly shuts the daemon (and every frame attached to it)
down. Details and the full alias list are in `CHEZMOI-GUIDE.md`.

## Secrets

All secrets (SSH keys, GPG keys, API tokens) are intended to live in
Bitwarden and be templated in via chezmoi's `bitwarden` / `bitwardenFields`
/ `bitwardenAttachment` template functions - never committed in plaintext.
None of the current dotfiles in this repo reference a live secret yet
(the original repo had none in scope either); this is the pattern to follow
when you add the first one, e.g. an SSH `config` or private key template.

## What changed from the old dotfiles repo

See the migration notes below (or ask - this was a deliberate cleanup, not
a blind copy). Highlights:

- Dropped everything macOS-only (this setup is Omarchy/Arch-only).
- Dropped the `scripts/` folder (Mac/X1-era, doesn't apply to Omarchy).
- Removed `git config http.sslverify = false` (was silently disabling TLS
  verification for all git remotes - a real security issue, not stylistic).
- Fixed two alias/function collisions with tools this setup now installs:
  `gh` (your old alias) renamed to `ghist` so it doesn't shadow the real
  GitHub CLI; the old `tre()` shell function dropped so it doesn't shadow
  the new AUR `tre` binary.
- Modernized `tmux.conf` (`mouse on` replaces removed `mode-mouse`),
  `fix-wifi`/`wifi-restart` (now `systemctl`), and `urlencode` (`python3`).
- `youtube-dl` alias renamed to `yt-dlp` (the maintained fork).
- Fixed a case-sensitivity bug in the `p`/`projects` alias and a smart-quote
  bug in `gch()`.
- `EDITOR` now points at `emacsclient` to match the Doom Emacs setup.
- Six git submodules replaced by `.chezmoiexternal.toml` `git-repo` entries
  (currently just `doom.d`) - same effect, no submodule commands to remember.

6 git submodules -> `.chezmoiexternal.toml`; 230 files in the old repo
pruned down to the files actually relevant to an Omarchy setup.
