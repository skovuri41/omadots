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

These three have to exist before anything else: step 3 clones via chezmoi
and step 5 uses it to lay down every other dotfile, and every
`install-*.sh` script in this repo
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

**3. Clone this repo — without applying anything yet.**

```sh
chezmoi init https://github.com/skovuri41/omadots.git
```

Deliberately `chezmoi init`, not `chezmoi init --apply`, and deliberately
the HTTPS URL. This clones the full repo into `~/.local/share/chezmoi` and
prompts once for your git name/email (cached after this, never asked again
on this machine) — but doesn't touch `$HOME` yet. Two things later in this
repo aren't ready for an apply this early:

- `.chezmoiexternal.toml`'s `doom.d`/`clojure-deps-edn` clones and this
  repo itself are all public, so the HTTPS URL needs no auth at all; the
  equivalent `git@github.com:...` SSH form would fail outright on a fresh
  machine ("Permission denied (publickey)") — SSH to GitHub always
  authenticates as a user, there's no anonymous SSH, even for a public
  repo.
- If you've already done the "Worked example" SSH keypair in the Secrets
  section on a previous machine, this repo now also contains a
  `private_dot_ssh/*.tmpl` file that calls `bitwardenSecrets` — which needs
  `bws` and a `BWS_ACCESS_TOKEN`, neither of which exist yet (see step 4a
  below). Applying now, before those exist, would fail trying to render it.

**4. Install the dev stack.** `chezmoi init` cloned the entire repo, not
just the `home/` subtree it applies to `$HOME` — `install-dev-stack.sh` and
its software registry live in this repo's `dev-stack/` subfolder:

```sh
cd ~/.local/share/chezmoi/dev-stack
./install-dev-stack.sh
```

Idempotent and safe to re-run. It registers itself as an `omarchy update`
post-update hook, so everything it installs stays current on every future
`omarchy update` — no separate maintenance step from here on. Among
everything else, this is what installs `bws` (no pacman/AUR package - see
"Secrets" below). See "Dev stack" below for the full tool list and how to
add more.

**4a. Set up the Bitwarden Secrets Manager access token**, if you haven't
on this machine yet — see "Per-machine setup" under "Secrets" below
(`~/.config/bws/access-token`). Skip this only if the repo has no
`private_*.tmpl` secrets yet (true the very first time you ever do this
setup, before the Secrets section's worked example exists).

**5. Now apply.**

```sh
chezmoi apply
```

Applies every `dot_*`/`dot_config/*` file to your real `$HOME` — including
exporting `XDG_CONFIG_HOME="$HOME/.config"` globally and, via
`.chezmoiexternal.toml`, your `doom.d` config into `~/.config/doom` (in
place before Doom Emacs itself is installed by step 4 — applied here, so
technically *after* step 4 ran; see "Why the order matters" below for why
that's still fine) and `clojure-deps-edn` into `~/.config/clojure`. Any
`private_*.tmpl` secret, if present, resolves now that step 4a covered its
prerequisites.

Confirm it landed cleanly:

```sh
chezmoi diff        # should print nothing - a fresh apply has nothing left to change
ls ~/.config/doom    # your real Doom config, not a placeholder
```

**6. Pick up new PATH entries.** Open a new terminal, or `source
~/.bashrc` in your current one.

**7. Authenticate the GitHub CLI.** `gh auth login` once — the package
installs the `gh` binary, but interactive OAuth login is deliberately not
automated by the script. This also sets up a credential helper that covers
pushing over HTTPS later - e.g. from `~/.config/doom` or this repo itself -
without needing an SSH key at all, if you'd rather skip the Secrets
section's SSH keypair entirely.

**8. Spot-check the pieces that talk to each other.**

```sh
./install-dev-stack.sh --status      # everything should read OK (or NOT ENABLED for
                                      # the Emacs daemon if step 5 didn't apply first)
doom doctor                          # Doom's own health check
systemctl --user status emacs        # daemon should be "active (running)"
emacsclient -e '(+ 1 2)'             # => 3, confirms a client can actually reach it
gh auth status                       # confirms step 7 took
```

**9. Optional: agent config and shell plugins**, once you're ready for
them (see their own sections below for what each installs):

```sh
cd ~/.local/share/chezmoi
agent-extensions/install-agent-extensions.sh   # needs `claude`/`codex` already logged in
omarchy-plugins/install-omarchy-plugins.sh
```

That's the whole sequence. From here on, day-to-day maintenance is just
`omarchy update` (covers the dev stack) plus `chezmoi update` (covers your
dotfiles) whenever you've pushed a change from another machine.

**Why the order matters.** Steps 4 and 5 are in tension and there's no
clean way to avoid it: `install-dev-stack.sh` runs `doom install`, which
wants chezmoi to have already placed your real config at `~/.config/doom`
(step 5) - otherwise Doom generates its own throwaway default config first.
But step 5's apply wants `bws` already installed first for step 4a, and
`bws` only comes from step 4 (no pacman/AUR package exists for it - see
"Secrets" below, and `install-dev-stack.sh` has no flag to install just one
tool ahead of the rest). Given that choice, this order picks the one that
fails loudly over the one that doesn't: running step 4 before step 5 just
means Doom's default config briefly exists on disk before chezmoi's
external overwrites it on the next `apply` anyway - cosmetic, self-healing,
no real breakage. The other order (apply before installing the dev stack)
breaks harder: if the repo already has a `private_*.tmpl` secret from a
previous machine, that apply fails outright trying to render it before
`bws`/the access token exist. Same reasoning covers the Emacs daemon - its
systemd unit file comes from chezmoi, not the script, so the script's
daemon-enable step (step 4) technically wants step 5 to have already run
too, with the same harmless brief-gap-then-self-heals shape.

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

## Known gaps / TODO

- **`settings.json` split (2026-09-26).** `home/dot_claude/settings.json.tmpl`
  currently tracks both the stable, deliberately-versioned bits (sha-pinned
  `extraKnownMarketplaces`/`enabledPlugins` — see "Agent skills and Claude
  Code plugins" above) and bits that get edited live and drift constantly
  (`permissions`, `tui`/`theme`). Every drift reconciliation risks silently
  clobbering a live change chezmoi doesn't know about yet (already happened
  once with the `permissions.deny` block). Fix: move the volatile keys to
  `~/.claude/settings.local.json` (Claude Code merges it automatically) and
  keep `settings.json.tmpl` scoped to just the plugin/marketplace
  declarations, so it stops drifting.
- **General live-vs-source drift.** A `chezmoi diff` run surfaced several
  files that had drifted between live and source, none from this repo's
  own tooling: `.config/kitty/kitty.conf` (`allow_remote_control`),
  `.config/git/config` (a `gh`-based credential helper),
  `.config/hypr/bindings.lua` (a "fathom" Omarchy plugin block),
  `.config/chromium-flags.conf` (a feature flag), `.claude/themes/
  omarchy.json` (color overrides) — all reconciled as of 2026-10-05 (each
  checked individually for *which* side was actually stale - two of these
  turned out to be source ahead of a live that hadn't been re-applied, not
  live ahead of source, so "pull into source" was the wrong fix for those
  two; `chezmoi apply` was). What's still unresolved is the underlying
  habit/mechanism: there's nothing that catches this before it piles up
  again. Worth deciding on something (a periodic `chezmoi diff` review, a
  pre-commit/cron reminder, etc.) rather than discovering it mid-unrelated-
  task like this time.

## Multi-machine notes

Two repos live outside chezmoi's direct management but are pulled in via
`.chezmoiexternal.toml` `git-repo` externals, so they stay independently
committable to their own repos: `doom.d` → `~/.config/doom`, and
`clojure-deps-edn` (a personal fork of `practicalli/clojure-deps-edn`) →
`~/.config/clojure`. Both are cloned/pulled automatically by `chezmoi
apply`/`chezmoi update`, same as any other part of the source state.

## Emacs/Hyprland daemon: issues hit and fixed

Both traced back to the same root cause on 2026-09-28 — the long-running
Emacs daemon's environment going stale relative to the *live* Hyprland/
Wayland session, because nothing refreshes a running process's environment
from the outside. If either symptom reappears on any machine (this one or a
fresh install), `erestart` (`systemctl --user restart emacs.service`) always
clears it: `PartOf=`/`After=graphical-session.target` in `emacs.service`
guarantees the replacement daemon starts with a correct, current
environment.

1. **SUPER+X (GTD capture) or SUPER+ALT+E (`+emacs-float`) throws
   `*ERROR*: JSON readtable error: 67`.** Both features shell out to
   `hyprctl -j activewindow` from inside the daemon to capture the origin
   window. If Hyprland's instance changes (reload, relogin, resume) without
   the daemon restarting, the daemon's cached `HYPRLAND_INSTANCE_SIGNATURE`
   no longer matches any live socket; `hyprctl` prints a connect-error
   string instead of JSON, and `json-read-from-string` throws on it.
   Fastest fix, no daemon restart / no lost buffers — from a shell in the
   *current* session:
   ```sh
   emacsclient --eval "(setenv \"HYPRLAND_INSTANCE_SIGNATURE\" \"$HYPRLAND_INSTANCE_SIGNATURE\")"
   ```
   Documented inline at `+org-capture-hypr--active-window-address` in
   `~/.config/doom/gtd.el` (tracked in `doom.d`, so it travels with the
   external repo pull above) and in that repo's `CLAUDE.md` (gitignored
   there — local-only, not portable; this README is the durable copy).
2. **`wl-copy`/`wl-paste` (Emacs's Wayland clipboard integration in
   `config.el`) silently stop working, historically fixed by `erestart`.**
   Same root cause, different trigger:
   `~/.local/share/applications/emacs.desktop`'s old
   `Exec=emacsclient -c -a "" %F` — the `-a ""` flag makes `emacsclient`
   self-fork a raw, unmanaged `emacs --daemon` if no server is reachable,
   bypassing systemd entirely and inheriting whatever environment the
   *launching* process happened to have (not necessarily a current
   `WAYLAND_DISPLAY`). `ec`/`emax` were already guarded against this via
   `emacsclient_safe()` in `dot_bash_functions`, but the `.desktop`
   launcher wasn't.
   **Permanently fixed**: `emacs.desktop`'s `Exec` now runs
   `systemctl --user start emacs.service` before `emacsclient`, so it only
   ever attaches to the systemd-managed daemon:
   ```
   Exec=sh -c 'systemctl --user start emacs.service; emacsclient -c -a "" "$@"' sh %F
   ```
   `systemctl --user start` on an already-running unit is a no-op, so this
   changes nothing when the daemon's already healthy. Since the `.desktop`
   file is chezmoi-managed, a fresh install gets this fix automatically.
