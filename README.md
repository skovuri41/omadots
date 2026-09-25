# omadots

Personal Omarchy Linux (Arch-based) setup: dotfiles, dev tools, coding-agent
config, and desktop-shell plugins, as four independent, composable pieces.
Clone this repo on a fresh Omarchy install and follow "Setting up a new
machine" below to get a fully configured system in about ten commands.

| Piece | What it manages | Tool |
|---|---|---|
| `home/` (chezmoi source state) | dotfiles: shell, git, tmux, readline, Hyprland (Lua config), zathura, herdr, systemd units, `doom.d` and `clojure-deps-edn` (pulled in as external git repos), Claude Code's own config | [chezmoi](https://www.chezmoi.io/) + [Bitwarden Secrets Manager](https://bitwarden.com/products/secrets-manager/) |
| `dev-stack/install-dev-stack.sh` | dev tools: Java, Clojure, Maven, Babashka, Node, Emacs + Doom Emacs (as a systemd `--user` daemon), Polylith, uv, curl, sqlite, tree, tre, jq, zathura, fonts, Citrix Workspace, chezmoi, Bitwarden CLIs, GitHub CLI | `mise`, pacman, AUR, self-updating Omarchy hook |
| `agent-extensions/install-agent-extensions.sh` | coding-agent config: third-party Agent Skills (`agent-skills.toml`, via [`npx skills`](https://github.com/vercel-labs/skills)) and Claude Code plugins (declared in `~/.claude/settings.json`) | Node/`npx`, `claude` CLI |
| `omarchy-plugins/install-omarchy-plugins.sh` | Omarchy 4 shell plugins: third-party Quickshell bar widgets/panels (`omarchy-plugins.toml`) | `omarchy` CLI (ships with Omarchy) |

They're deliberately decoupled: chezmoi never installs software,
`install-dev-stack.sh` never touches your dotfiles, and the two `install-*`
scripts under `agent-extensions/` and `omarchy-plugins/` are separate manual
steps from everything else — different domains, different CLIs, different
registries. Personal, hand-authored skills (as opposed to other people's
skill repos) aren't run through any script — they're plain chezmoi-managed
files under `home/dot_agents/skills/`, symlinked into `~/.claude/skills`
(see "Agent skills and Claude Code plugins" below).

## Setting up a new machine

The full sequence for a laptop that already has **Omarchy 4** installed and
booted, and nothing else done yet. Follow it in order — later steps depend
on earlier ones.

**0. Prerequisites.** A normal (non-root) user account, an internet
connection, and a terminal. Everything else below is installed as part of
the sequence.

**1. Install chezmoi, the Bitwarden CLI, and yq.**

```sh
sudo pacman -S chezmoi bitwarden-cli go-yq
```

These three have to exist before anything else: step 3 uses chezmoi to lay
down every other dotfile, and every `install-*.sh` script in this repo
reads its own `.toml` registry via `yq` — specifically **mikefarah/yq**
(the Go one; `go-yq` is the correct Arch package). There's a different,
unrelated `yq` on the AUR/pip (kislyuk/yq, a Python/jq wrapper) that does
**not** support the `-p toml -o json` usage these scripts need — every
script checks `yq --version` for the string "mikefarah" before trusting
whatever's on `$PATH`, and fails with an explicit `pacman` hint otherwise.
(`install-dev-stack.sh` also installs all three later as part of its normal
run — that's fine, `pacman -S` on an already-installed package is a no-op.
This manual step just breaks the chicken-and-egg problem of needing
chezmoi/yq to bootstrap before the scripts that need them can run.)

**2. Log into Bitwarden.**

```sh
bw login
```

`bw` (the personal-vault CLI) is only used for ad hoc lookups today — the
actual secret backend chezmoi templates use is **Bitwarden Secrets
Manager** (`bws`), a separate, token-based mechanism with no interactive
unlock step (see "Secrets" below). Log into `bw` anyway; it's the fastest
way to browse your vault by hand later.

**3. Bootstrap dotfiles from this repo.**

```sh
chezmoi init --apply git@github.com:skovuri41/omadots.git
```

This one command clones the full repo into `~/.local/share/chezmoi`,
prompts once for your git name/email (cached after this, never asked again
on this machine), applies every `dot_*`/`dot_config/*` file to your real
`$HOME` — including exporting `XDG_CONFIG_HOME="$HOME/.config"` globally —
and, via `.chezmoiexternal.toml`, clones your `doom.d` config into
`~/.config/doom` (in place before Doom Emacs itself is installed in step 5)
and your `clojure-deps-edn` config into `~/.config/clojure`.

Confirm it landed cleanly:

```sh
chezmoi diff        # should print nothing - a fresh apply has nothing left to change
ls ~/.config/doom    # your real Doom config, not a placeholder
```

**4. Install the dev stack.** `chezmoi init` cloned the entire repo, not
just the `home/` subtree it applies to `$HOME` — `install-dev-stack.sh` and
its software registry live in this repo's `dev-stack/` subfolder:

```sh
cd ~/.local/share/chezmoi/dev-stack
./install-dev-stack.sh
```

Idempotent and safe to re-run. It registers itself as an `omarchy update`
post-update hook, so everything it installs stays current on every future
`omarchy update` — no separate maintenance step from here on. See "Dev
stack" below for the full tool list and how to add more.

**5. Pick up new PATH entries.** Open a new terminal, or `source
~/.bashrc` in your current one.

**6. Authenticate the GitHub CLI.** `gh auth login` once — the package
installs the `gh` binary, but interactive OAuth login is deliberately not
automated by the script.

**7. Spot-check the pieces that talk to each other.**

```sh
./install-dev-stack.sh --status      # everything should read OK (or NOT ENABLED for
                                      # the Emacs daemon if step 3 didn't apply first)
doom doctor                          # Doom's own health check
systemctl --user status emacs        # daemon should be "active (running)"
emacsclient -e '(+ 1 2)'             # => 3, confirms a client can actually reach it
gh auth status                       # confirms step 6 took
```

**8. Optional: agent config and shell plugins**, once you're ready for
them (see their own sections below for what each installs):

```sh
cd ~/.local/share/chezmoi
agent-extensions/install-agent-extensions.sh   # needs `claude`/`codex` already logged in
omarchy-plugins/install-omarchy-plugins.sh
```

That's the whole sequence. From here on, day-to-day maintenance is just
`omarchy update` (covers the dev stack) plus `chezmoi update` (covers your
dotfiles) whenever you've pushed a change from another machine.

**Why the order matters.** `install-dev-stack.sh` runs `doom install`. If
chezmoi already placed your real config at `~/.config/doom` (step 3), Doom
finds it there and leaves it alone; skip step 3 first and Doom generates
its own default config, which chezmoi's external then overwrites on the
next `apply` anyway — the documented order just avoids a throwaway config
existing on disk even briefly. Same reasoning applies to the Emacs daemon:
its systemd unit file comes from chezmoi, not the script, so the script's
daemon-enable step needs step 3 to have already run.

## Day-to-day chezmoi commands

chezmoi never touches your real dotfiles directly — it only reads/writes
them when you run `chezmoi apply`. Until then, edits live in the **source
state**, a git checkout of this repo at `~/.local/share/chezmoi` (via
`.chezmoiroot`, really `home/` on disk).

| Command | What it does |
|---|---|
| `chezmoi edit ~/.bashrc` | Opens the *source* file for `~/.bashrc` in `$EDITOR`. Doesn't touch the real file until you `apply`. |
| `chezmoi edit --apply ~/.bashrc` | Same, but applies immediately after you save and quit. |
| `chezmoi diff` | Shows what `chezmoi apply` *would* change, without changing anything. Run this before every `apply` out of habit. |
| `chezmoi status` | Short one-line-per-file version of `diff`. |
| `chezmoi apply` | Writes source state → real dotfiles. |
| `chezmoi re-add ~/.config/hypr/looknfeel.lua` | The reverse: pulls a direct edit you made to the *real* file back into the source state. Skipped automatically for template (`.tmpl`) files, so it can't clobber a placeholder with a literal value — edit those with `chezmoi edit` instead. |
| `chezmoi add ~/.config/newtool/config.toml` | Starts tracking a file that isn't in the source state yet. |
| `chezmoi merge ~/.bashrc` | Opens a three-way merge if both the source and the real file changed since the last apply. |
| `chezmoi cd` | Drops you into a subshell inside the source directory so you can run plain `git` commands. `exit` to leave it. |
| `chezmoi update` | `git pull --autostash --rebase` in the source directory, then `apply` — the one-command way to pick up changes pushed from another machine. |

**Typical loop, on any file:** edit the real file directly, then
`chezmoi re-add <path>` → `chezmoi cd` → `git add`/`commit`/`push` → `exit`
→ (on any other machine) `chezmoi update`. Or edit through chezmoi from the
start with `chezmoi edit --apply <path>` and skip the `re-add`.

**Per-machine differences.** Nothing in this tree is currently
host-conditional — every machine that runs `chezmoi apply` gets the entire
source state, identically. If you add a second machine and need a file to
differ (or not exist at all) on it, two mechanisms are available with no
extra install:

- **`.chezmoiignore`** (in `home/`, always treated as a template) — a
  gitignore-style pattern list; anything it matches is skipped by `apply`
  entirely, on whichever machine a template condition is true for. Patterns
  match the rendered *target* path, not the source filename — check any new
  pattern with `chezmoi ignored`.
- **Conditional content inside a `.tmpl` file** — use `{{ .chezmoi.hostname
  }}` / `{{ .chezmoi.os }}` (or add data under `[data]` in
  `home/.chezmoi.toml.tmpl`) when the file should exist everywhere but
  differ, not when it shouldn't exist at all somewhere.

## Secrets: Bitwarden Secrets Manager

All secrets (SSH keys, GPG keys, API tokens) are intended to live in
**Bitwarden Secrets Manager** and be templated in via chezmoi's
`bitwardenSecrets` template function — never committed in plaintext. It
authenticates with a static **access token** issued to a machine account —
no master-password unlock step, so nothing expires mid-session or fails to
persist across a fresh terminal the way a personal-vault (`bw`) session
would.

**One-time account setup** (once per Bitwarden account, skip if you already
have a Secrets Manager org):

1. In the Bitwarden web vault: **Secrets Manager → Get started** (or create
   a Free organization — unlimited secrets, up to 2 users, 3 projects, 3
   machine accounts).
2. **Projects → New project** — e.g. `omadots`.
3. **Machine accounts → New machine account** — one per machine if you want
   to be able to revoke one machine's access independently. Grant it read
   access to the project.
4. On that machine account's page, **New access token** — copy it
   immediately, Bitwarden only shows it once.

**Per-machine setup** (once per machine, after `install-dev-stack.sh` has
installed `bws`):

```sh
mkdir -p -m 700 ~/.config/bws
install -m 600 /dev/stdin ~/.config/bws/access-token   # paste the token, then Ctrl-D
```

`home/dot_bash_exports` sources this file automatically and exports it as
`BWS_ACCESS_TOKEN` in every new shell — chezmoi's `bitwardenSecrets`
function picks it up from there with no per-apply prompt. This file is
**deliberately not chezmoi-managed** (it holds a live credential) — create
it once by hand per machine; deleting it (or the machine account's token in
Bitwarden) revokes that machine's access. `.chezmoiignore` and the root
`.gitignore` both also block `~/.config/bws/access-token` from ever being
`chezmoi add`ed by accident.

**Worked example: an SSH keypair for GitHub.**

```sh
ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/id_ed25519
```

In the Bitwarden web vault, under your project: **New secret** — paste the
entire contents of `~/.ssh/id_ed25519` (the whole PEM block) as the value.
Copy its **Secret ID** (a UUID, not the name) once saved. Then add the
chezmoi source files:

```
home/private_dot_ssh/private_id_ed25519.tmpl   # private key (templated, restricted perms)
home/dot_ssh/id_ed25519.pub                    # public key (plain file)
home/dot_ssh/config                            # tells ssh to use this key for github.com
```

The `private_` prefix sets `0700`/`0600` permissions on apply — SSH
refuses a private key that's group- or world-readable. The template file
contains only the retrieval call, with the Secret ID from above:

```
{{- (bitwardenSecrets "11111111-2222-3333-4444-555555555555").value -}}
```

```
# home/dot_ssh/config
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  AddKeysToAgent yes
```

`chezmoi apply` fetches the secret live via `bws secret get <id>` and
writes all three files — nothing secret ever touches the git repo, only
the retrieval call and the (non-secret) UUID. Register the public key with
GitHub (**Settings → SSH and GPG keys → New SSH key**), then verify:

```sh
ssh -T git@github.com
```

To reuse the same key on another machine: commit and push the three new
files, then on that machine complete its own "Per-machine setup" above and
run `chezmoi update`. To use a **different key per machine** instead
(trading simplicity for GitHub being able to revoke one machine without
logging the others out), store each machine's key as its own secret, keep
a `hostname → secret ID` map under `[data.bwsSecrets]` in
`home/.chezmoi.toml.tmpl`, and have the template look it up with
`index .bwsSecrets .chezmoi.hostname` instead of a hardcoded ID.

**Ad hoc personal-vault access.** `bw` stays installed for browsing your
own vault by hand, and its own template functions (`bitwarden`,
`bitwardenFields`, `bitwardenAttachmentByRef`) still work from a `.tmpl`
file if you want them — but they shell out to `bw`, which prompts for your
master password on every `apply` unless you persist `BW_SESSION` yourself.
`bitwardenSecrets`/`bws` is the mechanism for anything chezmoi needs
unattended.

## Dev stack

`dev-stack/install-dev-stack.sh` installs and then keeps current: Java,
Maven, Clojure CLI + Babashka, Node/npm (LTS), Emacs + Doom Emacs (as a
systemd `--user` daemon), fonts (JetBrains Mono Nerd Font, Overpass, Maple
Mono Nerd Font), Polylith, uv, curl, sqlite, tree, tre, jq, zathura,
Spotify, Citrix Workspace, chezmoi, the Bitwarden CLIs (`bw`/`bws`), the
GitHub CLI, Keyd (kernel-level key remapper), and a couple of spell-check
dictionaries. The full, current list — one `[[software]]` table per tool —
is `dev-stack/dev-stack-software.toml`.

```sh
cd ~/.local/share/chezmoi/dev-stack
./install-dev-stack.sh              # install everything (safe to re-run / upgrade with)
./install-dev-stack.sh --status     # read-only table, no changes
./install-dev-stack.sh --check foo  # read-only: how would 'foo' get installed?
```

**Design.** Same method Arch/Omarchy itself would use: official pacman
package first, AUR (via `yay`) second, a raw GitHub release only when
nothing else exists (Polylith). Every step checks before acting, so
re-running is both the retry path and the upgrade path — no single tool
failing stops the rest, and a failure is collected into a summary at the
end instead of aborting.

**Adding software.** Never edit the script — add a `[[software]]` table to
`dev-stack-software.toml` (`name`, `method` — `pacman`/`aur`/`aur-fragile`/
`mise`/`custom` —, `spec`, `status_pkg`, optional `note`). Not sure how a
new tool should be installed? `./install-dev-stack.sh --check <name>`
probes pacman/AUR/mise and prints a suggested block to paste in. A genuine
`custom` install (no package exists at all, like Doom Emacs or Polylith)
still needs a matching function wired up in the script itself via
`dispatch_custom()`.

**Verifying:**

```sh
java -version && mvn -version && clj --version
node --version && npm --version
poly version && uv --version && emacs --version
doom doctor                          # Doom's own health check, after first launch
systemctl --user status emacs        # daemon should be "active (running)"
emacsclient -e '(+ 1 2)'             # => 3, confirms a client can actually reach it
gh --version && gh auth status
```

**Ongoing maintenance** is just `omarchy update` — it re-runs
`install-dev-stack.sh` via its own post-update hook, which covers every
pacman/AUR package on the list plus every mise-managed tool, Doom Emacs,
and Polylith. `mup` (an Omarchy alias for `MISE_MINIMUM_RELEASE_AGE=0 mise
up`) updates just the mise tools, right now, without a full `omarchy
update`.

**Emacs daemon.** With it running: `ec` opens a new graphical frame, `emax`
a terminal-mode frame, `ekill` cleanly shuts the daemon (and every attached
frame) down; `estart`/`erestart`/`estop`/`estatus`/`elog` wrap the
underlying `systemctl --user`/`journalctl` calls. `ec`/`emax` are
`emacsclient`-safe wrapper functions that only ever ask **systemd** to
start the daemon if it's truly down, so at most one daemon ever exists.

**LSP (not enabled by default).** The script enables Doom's `java`/
`clojure` modules without `+lsp`, so first setup doesn't depend on a
language server that isn't installed yet. To add it: install a language
server (`clojure-lsp`, `eclipse.jdt-ls`), change `clojure`/`java` to
`(clojure +lsp)`/`(java +lsp)` in `~/.config/doom/init.el`, uncomment `lsp`
under `:tools`, and run `doom sync`.

**Citrix Workspace, if the AUR build is out of date.** The `aur-fragile`
registry entry tries `yay -S icaclient` first and falls back gracefully if
it fails — `--status` reports "ACTION NEEDED" rather than blocking the run.
If the AUR package itself is stale (not just download-gated), install
manually instead:

```sh
sudo pacman -S --needed gtk2 webkit2gtk gdk-pixbuf2 nss    # tarball installer does no dep resolution
# download the Linux Workspace tarball from citrix.com, then:
tar xvzf linuxx64-*.tar.gz && cd ICAClient && ./setupwfc   # 1 to install, defaults otherwise
```

Add `export ICAROOT="$HOME/ICAClient/<install-subdir>"` (check with `ls
~/ICAClient`, the subdirectory name varies by build) to your shell exports,
then wire up certificates and launch:

```sh
mkdir -p "$ICAROOT/keystore/cacerts" && cd "$ICAROOT/keystore/cacerts"
cp /etc/ca-certificates/extracted/tls-ca-bundle.pem .
awk 'BEGIN{c=0} /BEGIN CERT/{c++} {print > "cert."c".pem"}' tls-ca-bundle.pem
"$ICAROOT/util/ctx_rehash"
"$ICAROOT/selfservice" -icaroot "$ICAROOT" +addStore
```

If a session hangs on "Connecting…" under Wayland, force the GTK backend to
X11: `GDK_BACKEND=x11 "$ICAROOT/selfservice"` — if that alone doesn't clear
it, install `gdk-pixbuf2-noglycin` from the AUR. `--status` detects a
manual install directly (checks for `~/ICAClient/*/wfica`), so it won't
misreport "NOT INSTALLED" in the meantime; no registry change is needed to
switch back to the AUR path once it's current again.

## Agent skills and Claude Code plugins

`agent-extensions/install-agent-extensions.sh` is the counterpart to the
dev-stack script, for coding-agent config instead of OS packages. Run it
by hand after `claude` (and optionally `codex`) is installed **and**
authenticated via at least one interactive login — it's deliberately not
chained into `install-dev-stack.sh`'s unattended bootstrap.

```sh
cd ~/.local/share/chezmoi
agent-extensions/install-agent-extensions.sh              # install/upgrade everything registered
agent-extensions/install-agent-extensions.sh --status     # what's registered vs. installed
```

**Third-party skill repos** (`agent-extensions/agent-skills.toml`, one
`[[skill]]` table per repo — currently just `tt-a1i/archify`, a diagram
generator) install via [`npx skills`](https://github.com/vercel-labs/skills)
into every agent's native skills directory in one call (`~/.agents/skills`
and, for Claude Code, a symlink at `~/.claude/skills`).

**Personal, hand-authored skills** don't go through this registry — they're
plain chezmoi-managed content at `home/dot_agents/skills/<name>/`
(materializing at `~/.agents/skills/<name>/`), with a matching
`home/dot_claude/skills/symlink_<name>` source file symlinking it into
`~/.claude/skills/<name>`. Adding one means three things together: the
skill content, the symlink source file, and a matching
`!.claude/skills/<name>` allow-line in `home/.chezmoiignore` (see below).

**Claude Code plugins** are declared directly in
`home/dot_claude/settings.json.tmpl`'s `extraKnownMarketplaces`/
`enabledPlugins` (Anthropic's own recommended way to check plugin config
into version control) rather than a separate registry — currently
`i-have-adhd@i-have-adhd` and `mattpocock-skills@mattpocock`, both pinned
to a commit sha for supply-chain safety (a marketplace is arbitrary code
these plugins can run; bump the sha by hand via `git ls-remote <repo>
HEAD` to pick up updates). Declaring a plugin doesn't fetch its content —
`install-agent-extensions.sh` reconciles that half: it reads the *applied*
`settings.json`, registers every declared marketplace, and installs any
enabled-but-not-yet-installed plugin.

**Claude Code's own config (`~/.claude`) is managed via a default-deny
allowlist**, not a named block-list, in `home/.chezmoiignore` — it holds a
live OAuth credential (`.credentials.json`) alongside genuinely portable
config, so everything is ignored by default and only `settings.json` and
`themes/` are explicitly un-ignored (plus one `!.claude/skills/<name>` line
per personal skill). A future Claude Code version adding some new file
under `~/.claude` is excluded automatically rather than getting swept in
by an accidental `chezmoi add -r ~/.claude`.

## Omarchy shell plugins

`omarchy-plugins/install-omarchy-plugins.sh` installs/tracks/removes
third-party Omarchy 4 Quickshell bar widgets and panels via Omarchy's own
`omarchy plugin`/`omarchy bar` CLI — unrelated to coding agents, hence a
separate script and registry from `agent-extensions/`.

```sh
cd ~/.local/share/chezmoi
omarchy-plugins/install-omarchy-plugins.sh                 # install/enable/position everything registered
omarchy-plugins/install-omarchy-plugins.sh --status        # what's registered vs. installed
omarchy-plugins/install-omarchy-plugins.sh --remove <id>   # disable + remove one plugin by id
```

The registry, `omarchy-plugins/omarchy-plugins.toml`, currently declares
(all from github.com/jankeesvw unless noted): `jankeesvw.notification-center`
(searchable notification archive), `jankeesvw.herdr` (bar widget for herdr
coding-agent session status), `jankeesvw.downloads` (recent-downloads
widget), `jankeesvw.nag` (disposable bar alarms), `omamail` (full email
client — currently `disabled = true` in the registry), `bibek.focusd`
(Pomodoro timer), `bibek.ytdl` (YouTube downloader), `io.github.tyrichards.tray`
(system tray replacement), and `jeffmtb.moon-phase` (moon phase). Add a
`[[plugin]]` table (`id`, `source`, optional `section`/`deps`/`note`) to
add another; set `disabled = true` on an entry to register it without
installing it yet. `--remove` doesn't delete a plugin's own state/cache
directory — clean that up by hand if you actually want it gone.

## Multi-machine notes

Two repos live outside chezmoi's direct management but are pulled in via
`.chezmoiexternal.toml` `git-repo` externals, so they stay independently
committable to their own repos: `doom.d` → `~/.config/doom`, and
`clojure-deps-edn` (a personal fork of `practicalli/clojure-deps-edn`) →
`~/.config/clojure`. Both are cloned/pulled automatically by `chezmoi
apply`/`chezmoi update`, same as any other part of the source state.
