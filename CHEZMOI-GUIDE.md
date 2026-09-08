# Using chezmoi with omadots

This is the day-to-day guide for the chezmoi setup in `omadots/home/`. For
the one-time bootstrap on a fresh machine (`chezmoi init --apply`) and how
this fits together with `install-dev-stack.sh`, see `README.md` — this doc
picks up from there.

A couple of things worth keeping in mind throughout: chezmoi never touches
your real dotfiles (`~/.bashrc`, `~/.config/hypr/...`, etc.) directly — it
only reads and writes them when you explicitly run `chezmoi apply`. Until
then, all edits live in the **source state**, a plain directory at
`~/.local/share/chezmoi` that's a git checkout of this repo (via
`.chezmoiroot`, that's really `omadots/home/` on disk). Every command below
either moves content from source → target (`apply`) or target → source
(`add`/`re-add`), or talks to the git remote.

## How chezmoi decides what to apply on a given machine

Short answer: **by default, it doesn't decide anything — every machine that
runs `chezmoi apply` gets the entire source state, identically.** There's no
built-in concept of "this file belongs to that host." Every `dot_*` and
`dot_config/*` entry in `omadots/home/` gets applied everywhere, in full,
every time. As of today, that's true for everything in this repo — nothing
in the tree is currently host-conditional at the *file* level.

The one place host-awareness already exists is *inside* a couple of
templates, not at the file-selection level: the per-machine SSH key example
above uses `{{ .chezmoi.hostname }}` to change what a `.tmpl` file's
*content* resolves to — the file `~/.ssh/id_ed25519` still gets created on
every machine, it just contains a different key depending on which machine
rendered the template. That's a different mechanism from making a file
exist on some machines and not others.

If you actually want a file to not exist at all on certain machines, there
are two ways, and it's worth knowing which one you need:

- **`.chezmoiignore`** (in `home/`, alongside `.chezmoi.toml.tmpl` and
  `.chezmoiexternal.toml` — note this is inside `home/`, not next to
  `.chezmoiroot` itself, which lives one level up in the repo root) — a
  gitignore-style pattern list that's *always* treated as a template,
  whether or not it's named `.chezmoiignore.tmpl`. Anything it matches is
  skipped by `chezmoi apply` entirely, on whichever machine the condition
  is true for. Example — say a future machine is work-only and you don't
  want your Citrix config appearing anywhere else:

  ```
  {{- if ne .chezmoi.hostname "worklaptop" }}
  .ICAClient
  {{- end }}
  ```

  **Patterns match against the rendered *target* path, not the source
  filename** — this took a real test against the chezmoi binary to get
  right: the first version of this example used the source-directory name
  (`private_dot_ICAClient`) and silently matched nothing, because
  `.chezmoiignore` only ever sees the path *after* the `private_`/`dot_`
  prefixes are stripped (`.ICAClient`, exactly what shows up under
  `$HOME`). Worth double-checking any ignore pattern with
  `chezmoi ignored` after writing it — it prints exactly what's currently
  being skipped, so a typo here fails silently otherwise. One more nuance:
  chezmoi
  doesn't auto-delete a file that *used* to apply and is now ignored — an
  ignored file is invisible to chezmoi going forward (never created,
  updated, or removed by it), not retroactively cleaned up. If you ignore
  something that's already on disk from a previous apply, remove it
  yourself.
- **Conditional content inside a `.tmpl` file** (what the SSH key example
  does) — use this when the file should exist everywhere but differ, not
  when it shouldn't exist at all somewhere.

**Update**: `.chezmoiignore` is no longer unused (it was, when this was first
written) — it now has two entries: a host-conditional block (only on
"aditya") ignoring `.ssh`/`mise/config.toml`/`foot/foot.ini` to dodge a
Bitwarden vault-unlock prompt on every `apply`, and an unconditional
`.config/bws/access-token` entry (added 2026-09-05) as a backstop so the
`bws` access token can never be `chezmoi add`ed by accident — see the
"Bitwarden secret backend" section below for both. Everything else in
`omadots/home/` — bashrc, the whole `hypr/`, `nvim/`, etc. tree — is still
genuinely identical on every machine that applies it. If another real
per-host difference comes up later (e.g. a laptop-only Hyprland monitor
layout, or config that only makes sense on a work machine), that's the
file to add it to.

## External git repos (`.chezmoiexternal.toml`)

A `.chezmoiexternal.toml` entry with `type = "git-repo"` tells chezmoi to
`git clone` (first `apply`) then `git pull` (every later `apply`/`update`)
a repo straight into a target path under `$HOME` — the full `.git` history
is kept, so the result is a normal, independently-committable git working
copy, not a snapshot. This is what replaced the old dotfiles repo's git
submodules (see `claude/dotfiles-migration-plan.md` for that history).

Two entries exist today:

```toml
[".config/doom"]
    type = "git-repo"
    url = "git@github.com:skovuri41/doom.d.git"
    clone.args = ["--depth", "1"]

[".config/clojure"]
    type = "git-repo"
    url = "git@github.com:skovuri41/clojure-deps-edn.git"
    clone.args = ["--depth", "1"]
```

`doom.d` → `~/.config/doom` — your real Doom Emacs config, pulled in before
`install-dev-stack.sh` ever runs `doom install` (see `README.md`'s "Why
this order matters"). `clojure-deps-edn` (added 2026-09-06, a personal fork
of `practicalli/clojure-deps-edn`) → `~/.config/clojure` — user-level
Clojure CLI aliases (`deps.edn`) available to every `deps.edn` project on
the machine, the same "add stuff to `-M:`/`-X:`/`-T:` aliases here once,
use everywhere" convenience Java/Node devs get from a global config file.

**Why `.config/clojure` and not `.clojure` — this needed checking, not
assuming, and went through two iterations.** The upstream project's own
install instructions clone into `$XDG_CONFIG_HOME/clojure`, falling back to
`$HOME/.clojure` only if that env var isn't set. The Clojure CLI's own
config-dir resolution — confirmed directly from clojure.org's CLI
reference, not the generic XDG spec — is **`$CLJ_CONFIG` →
`$XDG_CONFIG_HOME/clojure` → `$HOME/.clojure`**, with no "default
`XDG_CONFIG_HOME` to `~/.config` if unset" fallback baked in the way some
XDG-aware tools implement themselves. At the time this external was first
added, this repo didn't export `XDG_CONFIG_HOME` anywhere, so the first
version of this entry targeted `.clojure` to match what the CLI would
actually read.

That was then revisited: rather than leave `XDG_CONFIG_HOME` unset forever
for one tool's sake, `home/dot_bash_exports` now exports
`XDG_CONFIG_HOME="$HOME/.config"` globally (2026-09-06) — but only after
auditing every other tool on this machine that reads that variable, to
confirm the change was actually safe:

| Tool | Reads `XDG_CONFIG_HOME`? | Effect of exporting it |
|---|---|---|
| Clojure CLI | Yes, explicit legacy fallback to `~/.clojure` | **Changes** — now resolves to `~/.config/clojure` |
| mise | Yes, full spec fallback (`${XDG_CONFIG_HOME:-$HOME/.config}/mise`, per mise's own docs) | No-op — already `~/.config/mise` |
| chezmoi | Yes, documents itself as fully XDG-compliant | No-op — already `~/.config/chezmoi` |
| GitHub CLI (`gh`) | Yes, full spec fallback (`$HOME/.config/gh`, per `gh_help_environment`) | No-op |
| Bitwarden CLI (`bw`) | Yes, confirmed directly from `bw.ts` source (`XDG_CONFIG_HOME ?? path.join(HOME, ".config/Bitwarden CLI")`) | No-op |
| Maven | No — `~/.m2` always, XDG support is still an open, unimplemented request (`MNG-6603`) | Unaffected either way |
| npm | No — `~/.npmrc` always, no XDG support per npm's own docs | Unaffected either way |
| Babashka (`bb`) | No — uses its own `~/.babashka` convention, unrelated to the Clojure CLI's `deps.edn` resolution | Unaffected either way |

So of everything currently installed, the export changes exactly one
thing: where the Clojure CLI (and therefore this external) looks. Everyone
else was already there, or was never going to be. `.chezmoiexternal.toml`'s
target was updated to `.config/clojure` to match. **Installing Clojure CLI
via `mise` doesn't change any of this**: mise's `clojure` tool
(`vfox:jdx/vfox-clojure` or `asdf:mise-plugins/mise-clojure`, per mise's
own registry) just runs the same official Clojure installer under the hood
and puts the resulting `clojure`/`clj` scripts on `PATH` via a shim — the
config-dir logic lives inside those scripts themselves, identical
regardless of who installed them or where the binary lives.

**Update (2026-09-06, later the same day): also set at the Hyprland level.**
The `dot_bash_exports` export only reaches bash-launched processes — a GUI
app spawned directly by Hyprland (the app launcher, a keybinding `exec`,
an autostart entry) never sources `dot_bash_exports` and so never saw it.
Rather than leave that as a standing limitation, `home/dot_config/hypr/envs.lua`
now sets all four standard XDG Base Directories directly in Hyprland's own
config, via `hl.env(...)` — the Lua-config equivalent of the classic
`env = VAR,VALUE` hyprland.conf directive, and the same mechanism already in
use one file over in `monitors.lua` (`hl.env("GDK_SCALE", ...)`):

```lua
local home = os.getenv("HOME")

hl.env("XDG_CONFIG_HOME", home .. "/.config")
hl.env("XDG_CACHE_HOME", home .. "/.cache")
hl.env("XDG_DATA_HOME", home .. "/.local/share")
hl.env("XDG_STATE_HOME", home .. "/.local/state")
```

Since Hyprland is the parent process for everything in the graphical
session, every child it spawns — including terminal windows, and therefore
the bash shells running inside them — inherits these, making the
`dot_bash_exports` export effectively a no-op re-assertion for anything
launched inside Hyprland. It's kept anyway because it's still the only one
of the two that reaches a bash shell opened *outside* Hyprland entirely —
SSH into this machine, a bare TTY login, cron.

Two things were confirmed directly from Hyprland's own sources before
writing `envs.lua`, not assumed:

1. `hl.env()` does **not** do shell-style `$VAR` expansion the way the
   classic `env = VAR,VALUE` directive does — confirmed directly by
   Hyprland's maintainer (vaxry) on the official forum
   ([thread](https://forum.hypr.land/t/lua-config-hl-env-doesn-t-do-parameter-expansion/1568)):
   HyprLang has built-in `$VAR` expansion, Lua has none. `envs.lua` resolves
   `$HOME` itself via `os.getenv("HOME")` rather than passing the literal
   string `"$HOME/.config"`, which would otherwise set `XDG_CONFIG_HOME` to
   the four literal characters `$HOME` followed by `/.config`, not an
   expanded path.
2. `env` values only take effect on a **fresh Hyprland session start**
   (log out/in, or a full compositor restart) — `hyprctl reload` re-parses
   the rest of the config but does not re-apply already-set env vars to the
   already-running compositor process. Confirmed via
   [hyprwm/Hyprland#8403](https://github.com/hyprwm/Hyprland/issues/8403),
   closed "not planned" — this is intentional upstream behavior. After
   `envs.lua` lands, log out and back in (or reboot) rather than expecting
   `hyprctl reload` alone to pick it up.

`hyprland.lua` was updated to `require("hypr.envs")` first among the
personal-override requires, before `hypr.monitors`, so these are set before
anything later in the require chain might spawn a process that cares.

No separate "installation" step exists beyond the external itself — unlike
Doom Emacs (a program `install-dev-stack.sh` has to actually build/install
via `install_doom()`), `clojure-deps-edn` is pure configuration (a
`deps.edn` plus alias definitions), and the Clojure CLI itself is already
on the machine via the existing `mise`-managed registry entry. The upstream
README's other "setup requirements" (Clojure CLI ≥ `1.11.1.xxxx`) are
satisfied automatically since `dev-stack-software.txt` tracks
`clojure@latest`. First real use: `cd` into any `deps.edn` project and run
one of the aliases this repo defines, e.g. `clojure -M:repl/rebel` for a
Rebel-readline REPL — `clojure` resolves user-level aliases from
`~/.clojure/deps.edn` and merges them with the project's own, automatically,
no extra flag needed.

## Everyday commands

| Command | What it does |
|---|---|
| `chezmoi edit ~/.bashrc` | Opens the *source* file for `~/.bashrc` in `$EDITOR`. Doesn't touch the real file until you `apply`. |
| `chezmoi edit --apply ~/.bashrc` | Same, but applies immediately after you save and quit. |
| `chezmoi diff` | Shows what `chezmoi apply` *would* change, without changing anything. Run this before every `apply` out of habit. |
| `chezmoi status` | Short one-line-per-file version of `diff`. |
| `chezmoi apply` | Writes source state → real dotfiles. |
| `chezmoi re-add ~/.config/hypr/looknfeel.lua` | The reverse: pulls a direct edit you made to the *real* file back into the source state. Chezmoi automatically skips this for template (`.tmpl`) files so it can't accidentally clobber a `{{ .email }}` placeholder with a literal value — edit those with `chezmoi edit` instead. |
| `chezmoi add ~/.config/newtool/config.toml` | Starts tracking a file that isn't in the source state yet. |
| `chezmoi merge ~/.bashrc` | Opens a three-way merge if both the source and the real file changed since the last apply. |
| `chezmoi cd` | Drops you into a subshell inside the source directory so you can run plain `git` commands. `exit` to leave it. |
| `chezmoi update` | `git pull --autostash --rebase` in the source directory, then `apply` — the one-command way to pick up changes pushed from another machine. |

## Worked example: change a file, push it to GitHub, pull it on another machine

Say you're tweaking Hyprland on your main machine — nudging the blur and gap
settings in `~/.config/hypr/looknfeel.lua` — and you want that change
tracked and available on your other machine too.

**1. Make the edit.** Either edit the real file directly (e.g. because
you're iterating live and want Hyprland to pick it up immediately), or go
through chezmoi from the start with `chezmoi edit --apply ~/.config/hypr/looknfeel.lua`.
If you used `chezmoi edit --apply`, the source state is already updated —
skip to step 3.

**2. Pull the direct edit back into the source state.**

```sh
chezmoi re-add ~/.config/hypr/looknfeel.lua
```

This copies your live edit back into `omadots/home/dot_config/hypr/looknfeel.lua`
on disk. `chezmoi diff` should now report no difference (target and source
match again) — the change has moved from "live only" to "tracked."

**3. Review and commit the source-state change.**

```sh
chezmoi cd
git diff                                  # see exactly what changed, in context
git add dot_config/hypr/looknfeel.lua
git commit -m "hypr: increase blur, tighten gaps"
git push
exit
```

(You can skip `chezmoi cd` and run the same three git steps prefixed with
`chezmoi git --`, e.g. `chezmoi git add dot_config/hypr/looknfeel.lua` then
`chezmoi git -- commit -m "..."` then `chezmoi git push` — same effect,
no subshell.)

**4. Pull it down on your other machine.**

```sh
chezmoi update
```

This runs `git pull --autostash --rebase` in that machine's source
directory, then `chezmoi apply` — so the new `looknfeel.lua` lands and
Hyprland picks it up on next reload, no manual copying required. If you'd
rather review before it touches anything: `chezmoi git pull` (or `git pull`
inside `chezmoi cd`), then `chezmoi diff` to see what's about to change,
then `chezmoi apply` when you're happy.

That's the whole loop — `re-add` (if you edited live) → `git commit`/`push`
→ `chezmoi update` on every other machine. The same four steps work for any
tracked file, not just Hyprland config.

## Using Bitwarden to manage secrets with chezmoi

**Updated 2026-08-31 — switched from `bw` to `bws` (Bitwarden Secrets
Manager) as the backend chezmoi templates use.** The original design here
used `bitwarden.unlock = "auto"` plus the regular `bw` CLI, on the
assumption that "auto" meant "only unlock once." In practice it doesn't:
`bitwarden.unlock = "auto"` only skips calling `bw unlock` if `BW_SESSION`
is *already* set in the environment — it never persists a session across
separate processes, and Bitwarden's own CLI is explicit that a session
"will not persist if you open a new terminal window." So every fresh
`chezmoi apply` (a new shell, a fresh terminal, the `omarchy update` hook)
had no `BW_SESSION`, "auto" called `bw unlock` again, and every single
apply prompted for the master password — not a chezmoi bug, just how `bw
unlock` sessions work. That's what led to keeping Bitwarden-backed secret
files out of the tree entirely up to now (see the checklist item this
closes out).

**Secrets Manager sidesteps the problem structurally, not by tuning a
setting.** It authenticates with a static **access token** issued to a
"machine account" (a service identity, not your personal login) — there's
no master-password unlock step at all, so there's nothing that can expire
mid-session or fail to persist across processes. The tradeoff: it's a
genuinely separate product from your personal vault (secrets live in
"projects" under a Bitwarden *organization*, not alongside your normal
vault items), and it only stores plain text values — no file attachments,
so a private key has to be pasted in as text rather than uploaded as a
file. `bitwarden-cli` (`bw`) stays installed for ad hoc personal-vault
lookups (browsing your own logins, etc.) — it's just no longer what chezmoi
templates depend on.

**One-time account setup** (once per Bitwarden account, not per machine —
skip if you already have a Secrets Manager org):

1. In the Bitwarden web vault, if you don't already have an organization
   with Secrets Manager: **Secrets Manager → Get started**, or from an
   existing Families/Premium account, create a new **Free** organization
   (Free tier: unlimited secrets, up to 2 users, 3 projects, 3 machine
   accounts — plenty for one person's dotfiles).
2. **Projects → New project** — e.g. `omadots`. Projects are just a
   grouping; one is enough here.
3. **Machine accounts → New machine account** — e.g. `aditya-laptop` (or
   one per machine, if you want to be able to revoke one machine's access
   to secrets without affecting others — same one-key-per-device tradeoff
   as the old GitHub SSH key setup below, just at the token level instead).
   Grant it read access to the `omadots` project.
4. On that machine account's page, **New access token** — copy it
   immediately, Bitwarden only shows it once.

**Per-machine setup** (once per machine, after `install-dev-stack.sh` has
installed `bws` — see `README-dev-stack.md`):

```sh
mkdir -p -m 700 ~/.config/bws
install -m 600 /dev/stdin ~/.config/bws/access-token   # paste the token, then Ctrl-D
```

`home/dot_bash_exports` sources this file automatically (if present) and
exports it as `BWS_ACCESS_TOKEN` in every new shell — chezmoi's
`bitwardenSecrets` template function picks it up from there with no
per-apply prompt at all. This file is **deliberately not chezmoi-managed**
(same reasoning as `~/.config/dev-stack/env.sh` — it holds a live
credential, which has no business in git even in a repo that's otherwise
just retrieval logic) — you create it once by hand per machine, and it's
also how you'd revoke/rotate: delete the file (or the machine account's
token in Bitwarden) and the machine loses access.

Two backstops against this file ever ending up in the git repo by accident:
`home/.chezmoiignore` lists `.config/bws/access-token` - verified with a
real `chezmoi add` (including `-r ~/.config/bws` and `--force`) that a
matched path is actually skipped, not just warned about, so `chezmoi add`
can't put it in the source state even by muscle memory. The repo's root
`.gitignore` also has a `*access-token*` pattern as a second layer, in case
a copy ever lands in the tree some other way (e.g. hand-copied in).

The rule of thumb, unchanged from before: **the chezmoi source state (and
the GitHub repo) should only ever contain the *retrieval logic* — `{{
bitwardenSecrets ... }}` and a secret's *ID* — never the secret's value.**
A Secrets Manager secret ID is an opaque UUID, not a name, so it's fine to
commit in plain sight (same as the old setup committing a Bitwarden *item
name*, just a UUID instead of a string) — the actual value only ever
exists on disk, in the real target file, after `chezmoi apply` fetches it
live.

**Worked example: an SSH keypair for GitHub, managed through Secrets
Manager.**

*1. Generate the keypair, once, on one machine.*

```sh
ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/id_ed25519
```

`ed25519` is what GitHub itself recommends over RSA today. You'll be
prompted for a passphrase — optional, but worth considering even though
Secrets Manager already gates access to the value: it's a second layer in
case the private key ever ends up copied somewhere outside Bitwarden's
control.

*2. Store the private key as a Secrets Manager secret.*

In the Bitwarden web vault, under the `omadots` project: **New secret** —
name it something like `omadots-ssh-github`, and for the value, paste the
**entire contents** of `~/.ssh/id_ed25519` (the whole PEM block, including
the `-----BEGIN`/`-----END` lines — Secrets Manager stores it as plain
text, multi-line values are fine). After saving, open the secret and copy
its **Secret ID** (a UUID) — that's what the template below needs, not the
name.

Unlike the old attachment-based setup, the **public** key doesn't need
Bitwarden at all — it isn't sensitive, so it's tracked as a normal plain
file below.

*3. Add the chezmoi source files.*

```
home/private_dot_ssh/private_id_ed25519.tmpl   # the private key (templated, restricted perms)
home/dot_ssh/id_ed25519.pub                    # the public key (plain file, add via `chezmoi add`)
home/dot_ssh/config                            # tells ssh to use this key for github.com
```

The `private_` prefix on both the directory and the file makes chezmoi set
restrictive permissions on apply (`0700` on `~/.ssh`, `0600` on the key
itself) — SSH refuses to use a private key that's group- or world-readable,
so this isn't optional. `private_id_ed25519.tmpl` contains only the
retrieval call, with the Secret ID from step 2 pasted in:

```
{{- (bitwardenSecrets "11111111-2222-3333-4444-555555555555").value -}}
```

`dot_ssh/config` is a normal tracked file:

```
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  AddKeysToAgent yes
```

`AddKeysToAgent yes` means `ssh-agent` picks the key up automatically the
first time it's used each session — no manual `ssh-add` step, and (if you
set a passphrase in step 1) you're only asked for it once per session
rather than on every `git push`.

*4. Apply.*

```sh
chezmoi apply
```

`bitwardenSecrets` shells out to `bws secret get <id>` using
`BWS_ACCESS_TOKEN` from the environment — no prompt, no unlock step,
whether this is the first apply of the day or the fifth. Writes
`~/.ssh/id_ed25519` (mode `0600`), `~/.ssh/id_ed25519.pub`, and
`~/.ssh/config`. Nothing secret ever touches the git repo — `git log` on
the `.tmpl` file only ever shows the retrieval call and the (non-secret)
UUID, never the key content.

*5. Register the public key with GitHub.*

Copy the public key — on Omarchy (Wayland) that's `wl-copy < ~/.ssh/id_ed25519.pub`,
or just `cat ~/.ssh/id_ed25519.pub` and select the output manually. Then in
GitHub: profile picture (top right) → **Settings** → **SSH and GPG keys**
(under Access) → **New SSH key** → paste it in → **Add SSH key**.

*6. Test it.*

```sh
ssh -T git@github.com
```

A successful connection replies with `Hi <username>! You've successfully
authenticated...` — at that point `git clone git@github.com:...` and
`git push` over SSH both work without a password prompt.

*7. Get the same key onto your other machines.*

Commit and push the three new files from step 3 (`chezmoi cd` → `git add`
→ `commit` → `push`, per the worked example earlier in this doc), then on
each other machine: complete "Per-machine setup" above (its own machine
account, its own `~/.config/bws/access-token`) if you haven't already,
then `chezmoi update`. Chezmoi fetches the same secret and writes out the
identical key — so every machine authenticates to GitHub as the same
identity, with nothing copied by hand.

One tradeoff worth knowing before you commit to this: GitHub's model
assumes one key per device, so it can label and revoke them individually.
Reusing a single Secrets-Manager-sourced key everywhere is simpler and is
exactly what this setup makes easy — but it means revoking that key (e.g.
because one machine was compromised) logs *every* machine out of GitHub at
once, not just the affected one. If that tradeoff doesn't sit well with
you, use the per-machine variant below instead.

### Variant: a different key per machine

`bws secret get` takes a secret's **ID**, not a name, so this can't
branch the way the old `bw`-based version did (building an item *name* at
apply time with `printf "...-%s" .chezmoi.hostname`). Instead, keep a
small, non-secret **map of hostname → secret ID** in chezmoi's own
template data, and look up that machine's ID from it.

*1. Confirm each machine's hostname as chezmoi sees it.*

On each machine, run:

```sh
chezmoi execute-template '{{ .chezmoi.hostname }}'
```

This is the short hostname (up to the first `.`) — write down what it
prints for each machine (e.g. `aditya`, `worklaptop`).

*2. Generate a separate keypair on each machine, and store each as its own
Secrets Manager secret* (same as steps 1–2 of the worked example above, but
name each secret after its machine, e.g. `omadots-ssh-github-aditya`,
`omadots-ssh-github-worklaptop`, and copy each one's Secret ID).

*3. Add the ID map to `home/.chezmoi.toml.tmpl`* (create this file if it
doesn't exist yet — it's chezmoi's own config, templated so it can vary per
machine, and lives in `home/` alongside `.chezmoiexternal.toml`). IDs are
opaque UUIDs, not secrets, so this is safe to commit:

```toml
[data.bwsSecrets]
  aditya      = "11111111-2222-3333-4444-555555555555"
  worklaptop  = "66666666-7777-8888-9999-000000000000"
```

*4. Update the chezmoi templates to branch on hostname:*

```
home/private_dot_ssh/private_id_ed25519.tmpl
home/dot_ssh/id_ed25519.pub.tmpl        ← now a .tmpl too, since its content differs per machine
home/dot_ssh/config                      ← unchanged, same IdentityFile path on every machine
```

```
{{/* home/private_dot_ssh/private_id_ed25519.tmpl */}}
{{- (bitwardenSecrets (index .bwsSecrets .chezmoi.hostname)).value -}}
```

The public key can't be derived from the same secret the way the old
attachment version did (Secrets Manager has no second attachment slot) —
store it as its own secret per machine too, named e.g.
`omadots-ssh-github-aditya-pub`, and add a matching `.pub` entry to the
`bwsSecrets` map, or simplest: since public keys aren't sensitive, just
`chezmoi add` each machine's `~/.ssh/id_ed25519.pub` as a plain
per-machine file instead of round-tripping it through Secrets Manager at
all.

`index .bwsSecrets .chezmoi.hostname` looks up whichever machine is running
the apply — on `aditya` it resolves the first UUID above; on `worklaptop`,
the second. A hostname missing from the map renders an empty string
(`index` on a missing map key doesn't error in Go templates) rather than
failing loudly, so double-check `chezmoi execute-template` output after
adding a new machine to the map. `dot_ssh/config` needs no change from the
shared-key version, since `IdentityFile ~/.ssh/id_ed25519` is the same path
on every machine — only what's *in* that file differs now.

*5. Apply on each machine.*

```sh
chezmoi apply
```

Run on each machine after its own "Per-machine setup" (its own machine
account + `~/.config/bws/access-token`) is done. Each one fetches its own
secret and writes its own distinct key — same command everywhere, different
result per machine, by design.

*6. Register each machine's public key with GitHub separately.*

Repeat the GitHub step from the shared-key version (Settings → SSH and GPG
keys → New SSH key) once per machine, pasting that machine's own
`~/.ssh/id_ed25519.pub`. Give each one a title that matches its hostname
(e.g. "aditya", "worklaptop") so GitHub's key list tells them apart — this
is what makes revoking one machine's access, later, not touch the others.

*7. Test on each machine.*

```sh
ssh -T git@github.com
```

Same command as before, run separately on each machine — each authenticates
with its own key but the same GitHub identity.

*8. Push the template once — it's already done for every machine.*

Commit and push the files from step 3–4 (`chezmoi cd` → `git add` →
`commit` → `push`). Unlike a normal config change, you do **not** need to
touch these templates again when you add a future machine — just repeat
steps 1–2 and 6–7 for the new machine (new keypair, new Secrets Manager
secret, register its public key with GitHub), add one line to the
`bwsSecrets` map, and the same already-pushed template picks it up on
`chezmoi apply`.

**Other Bitwarden template functions still available**, if you want ad hoc
access to your *personal* vault (not Secrets Manager) from a template:

- `{{ (bitwarden "item" "some-login").login.password }}` — a plain login
  password field.
- `{{ (bitwardenFields "item" "some-login").token.value }}` — a *custom
  field* you defined on the Bitwarden item yourself.
- `{{ bitwardenAttachmentByRef "filename" "item" "item-name" }}` — a file
  attachment (the mechanism the old SSH-key setup used).

All three still shell out to `bw`, so they carry the same per-apply
master-password prompt discussed at the top of this section unless you
persist `BW_SESSION` yourself (e.g. by running
`export BW_SESSION=$(bw unlock --raw)` once per login, from wherever your
Hyprland/uwsm session sets up its environment, rather than per-shell) —
not something this setup currently does, since nothing here depends on
`bw` for anything needed on every `apply` anymore. Fine for something you
reach for occasionally by hand; `bitwardenSecrets`/`bws` is the mechanism
for anything chezmoi needs unattended.

Same pattern every time, whichever function you use: store the secret,
reference it with a template call inside a `.tmpl` file in the source
state, let `chezmoi apply` do the fetching. This is the mechanism to reach
for the first time you actually need a live secret (API token, GPG key,
etc.) — none of the files migrated so far needed one.

## Claude Code's own config (`~/.claude`)

Added 2026-09-06. `~/.claude` is Claude Code's own global config directory
— the natural next question once everything *else* on the machine is
chezmoi-managed. It's a mixed bag, though: alongside genuinely portable
config it holds a live OAuth credential and a lot of session/app state that
should never be synced. Rather than guess at the split from memory, the
real directory was copied into a connected folder and inspected file by
file before deciding anything.

**What was actually found** (your mileage may vary as Claude Code adds
features — see the note on the ignore pattern's shape below):

- `settings.json` — small, portable: TUI mode, theme, notification toggle,
  and a `SessionStart` hook wired up by `herdr` (the pane-management tool
  already referenced elsewhere in this repo, via `dot_config/herdr`). One
  catch: the hook command hardcoded this
  machine's home directory (`bash '/home/shyam/.claude/hooks/...'`) —
  chezmoi-managing it as a plain file would have baked that literal path
  into every future machine's copy. Managed instead as
  `home/dot_claude/settings.json.tmpl`, with `{{ .chezmoi.homeDir }}`
  substituted in — verified by rendering it against a scratch `$HOME`
  simulating a completely different username and confirming the hook
  command came out pointing at *that* machine's home, not this one's.
- `themes/omarchy.json` — a custom Claude Code color theme matching the
  Omarchy palette. Plain, portable, no templating needed. Managed as
  `home/dot_claude/themes/omarchy.json`.
- `.credentials.json` — a live OAuth token. **Never chezmoi-managed.**
- `history.jsonl`, `.last-cleanup`, `backups/`, `cache/`, `session-env/`,
  `sessions/`, `shell-snapshots/` — session and app state Claude Code
  writes and manages itself, not config you'd author by hand.
- `projects/` — full conversation transcripts and auto-memory. Worth
  calling out specifically: Claude Code's own docs are explicit that these
  are **plaintext, unencrypted at rest**, and that if a tool reads a
  `.env` file or a command prints a credential during a session, that
  value lands directly in the transcript file. Committing this to git
  would be exactly the kind of accidental-secret-exposure this repo's
  `bws`/`access-token` ignore rules (above) exist to prevent — never
  chezmoi-manage it.
- `plugins/` — installed-plugin cache and cloned marketplaces, managed by
  `claude plugin` commands, not hand-edited.
- `chrome/chrome-native-host` — a wrapper script Claude Code generates
  itself ("do not edit manually," per its own header comment), hardcoding
  the exact `mise`-installed Claude Code binary path and version on this
  machine. Regenerated automatically; nothing to sync.
- `hooks/herdr-agent-state.sh` — installed and overwritten by herdr's own
  integration ("managed by herdr; reinstalling or updating the integration
  overwrites this file," per its own header). Chezmoi-managing it would
  fight herdr's next reinstall or update, so it's excluded — the
  `settings.json` hook entry above still points at wherever herdr puts it,
  templated to the right `$HOME`, but the script itself is herdr's to own.
- `skills/diagnose-crash`, `skills/omarchy` — turned out to be symlinks
  (confirmed with `ls -la` over the device bridge, not assumed from the
  directory listing alone) into
  `/usr/share/omarchy/default/agents/skills/` — Omarchy's own package
  content, already present on any Omarchy install. Nothing to sync; these
  aren't user-authored.

**The `.chezmoiignore` shape is deliberately a default-deny allowlist, not
a named block-list** — the opposite of the bws entry above, and for a
specific reason: `~/.claude` holds a live credential, so the safe posture
is "ignore everything by default, explicitly allow only what's been
checked," not "ignore the things I currently know about." If a future
Claude Code version adds some new file or directory here, it's excluded
automatically instead of silently getting swept in by an accidental
`chezmoi add -r ~/.claude`. Getting gitignore-style negation right took a
real test, not just reading the pattern and assuming it'd work — see
below.

```
.claude/**
!.claude
!.claude/settings.json
!.claude/themes
!.claude/themes/**
```

The `!.claude` line matters more than it looks: without it, the very first
line (`.claude/**`) causes chezmoi to prune the whole `.claude` directory
from traversal, and no later negation pattern can reach anything inside it
— a well-known gitignore-pattern gotcha (you can't un-ignore a file whose
parent directory is itself ignored). Confirmed this the hard way: the
first version of this pattern (without `!.claude`) silently produced
`chezmoi: warning: ignoring .claude` and added nothing at all, including
the two files meant to be allowed through.

**Validated against the real chezmoi v2.72.0 binary**, not just read and
assumed correct: built a scratch `$HOME` reproducing the exact directory
structure found above (including a dummy `.credentials.json` and the
Omarchy symlinks), then ran `chezmoi add -r ~/.claude` — confirmed only
`settings.json` and `themes/omarchy.json` land in source state, with an
explicit `chezmoi: warning: ignoring ...` line for every other path.
Repeated with a direct (non-recursive) `chezmoi add` targeting
`.credentials.json` and the herdr hook script individually, and again with
`--force` on `.credentials.json` — all three still correctly skipped.
Finally ran a full `chezmoi apply` against a scratch `$HOME` under a
different path entirely (simulating a different machine/username) to
confirm the `settings.json.tmpl` renders its hook command with *that*
machine's home directory, and that a second `apply`/`diff` is a clean
no-op.

### Update (2026-09-06, later still): agent-agnostic skills under `~/.agents`, symlinked into `~/.claude/skills`

Anthropic open-sourced the Skills file format itself (`agentskills.io`) — a
folder with `SKILL.md` (`name`/`description` frontmatter, plus optional
`scripts/`/`references/`/`assets/`) that's read natively by both Claude
Code and, as of the same research pass, OpenAI Codex. The two tools just
look in different places: Claude reads `~/.claude/skills/<name>/`, Codex
reads `~/.agents/skills/<name>/`. So personal, hand-authored skills (as
opposed to marketplace plugins — see `agent-extensions/` below) are
chezmoi-managed once, at the tool-neutral location, and symlinked into
Claude's:

- `home/dot_agents/skills/<name>/SKILL.md` (plus any `scripts/`/etc.) —
  the actual content, real chezmoi-managed files, materializing at
  `~/.agents/skills/<name>/`. First one added: `clojure-style`, a
  distillation of the community Clojure Style Guide
  (<https://guide.clojure.style/>) — naming, threading macros, namespace
  layout, control-flow/data idioms, docstrings, testing conventions.
  Written using only the open spec's plain frontmatter and markdown body —
  deliberately none of Claude Code's own runtime syntax (no `` !`cmd` ``
  shell injection, no `${CLAUDE_PROJECT_DIR}`-style substitution) — so it
  reads correctly in Codex too, not just Claude.
- `home/dot_claude/skills/symlink_<name>` — one chezmoi symlink source
  file per personal skill, content `../../.agents/skills/<name>` (the
  relative path from `~/.claude/skills/` up to `~/`, back down into
  `.agents/skills/<name>`). Chezmoi strips the trailing newline and treats
  a `symlink_*` source file's content as the link target — confirmed
  against chezmoi's own reference docs, not assumed.

**Important correction, caught before it shipped, not after**: the original
plan was to symlink the whole `~/.claude/skills` *directory* at
`~/.agents/skills`. Re-reading this very section's own findings above
first — `skills/diagnose-crash` and `skills/omarchy` are real, live
Omarchy-owned symlinks already sitting inside `~/.claude/skills/` — showed
that would have shadowed both of them the moment chezmoi applied it.
Symlinking each personal skill individually instead
(`~/.claude/skills/clojure-style`, not `~/.claude/skills` itself) leaves
Omarchy's own entries, and anything else that ever lands in that
directory, completely untouched. `.chezmoiignore`'s allowlist reflects
that precision — `!.claude/skills/clojure-style` by name, not a
`.claude/skills/**` wildcard:

```
!.claude/skills
!.claude/skills/clojure-style
```

Adding a future personal skill means three things, always together: the
content under `home/dot_agents/skills/<new-name>/`, a matching
`home/dot_claude/skills/symlink_<new-name>` (content
`../../.agents/skills/<new-name>`), and a matching
`!.claude/skills/<new-name>` line here.

**Validated against the real chezmoi v2.72.0 binary**, reproducing this
exact scenario: a scratch `$HOME` pre-populated with the same
`diagnose-crash`/`omarchy` Omarchy symlinks and a dummy `.credentials.json`
(so the test actually exercises the shadowing risk, not just an empty
directory) before running `chezmoi apply`. Confirmed: `clojure-style`
appears as a symlink resolving to `~/.agents/skills/clojure-style` and its
`SKILL.md` reads correctly through it; the two Omarchy symlinks and the
credentials file are untouched, byte-for-byte; a second `apply`/`diff` is
a clean no-op; and a defensive `chezmoi add -r ~/.claude` still correctly
skips everything except the two previously-allowed files plus the new
`skills/symlink_clojure-style` entry (which was already in source state,
so `add` left it alone rather than duplicating it).

The *other* half of agent-config management — skill repos you didn't write
yourself, and Claude Code plugins — is deliberately kept separate from
this personal-skills setup, via `agent-extensions/install-agent-extensions.sh`
(repo root, sibling to `install-dev-stack.sh`). See that script's own
header comment for the full reasoning; short version: those are other
people's code, fetched from a registry, not something to fork into this
repo the way a hand-written skill is.

### Update (2026-09-07 → corrected 2026-09-08): third-party skill repos, and why this dropped its own git-clone logic

Added `tt-a1i/archify` (a typed-JSON-to-interactive-HTML diagram-generator
skill - architecture/workflow/sequence/data-flow/lifecycle diagrams,
verified MIT-licensed with no Claude-Code-specific frontmatter or
terminology, explicitly designed to work from Claude Code, Codex CLI,
Cursor, and OpenCode alike) to `agent-extensions/agent-skills.txt`, and hit
a case the original registry format couldn't express: its `SKILL.md`
lives at `archify/SKILL.md`, one level inside the repo, not at the repo
root the way `mattpocock/skills` is.

**First attempt (2026-09-07, since replaced):** taught
`install-agent-extensions.sh` a `subpath` registry field, cloned each repo
into a cache dir, and symlinked `~/.agents/skills/<name>` at that subpath.
This worked, but only ever touched `~/.agents/skills` - it never created
the separate, Claude-specific `~/.claude/skills/<name>` symlink
hand-authored skills get (the mechanism documented above). Net effect:
`archify` was completely invisible to Claude Code, only reachable by
Codex-like tools reading `~/.agents/skills` natively - not discovered
until actually trying to use it.

**Root cause once found, and the bigger question it raised:** fixing the
missing Claude-side symlink imperatively would have worked, but
`tt-a1i/archify`'s own README already recommends installing it via `npx
skills add tt-a1i/archify -g` - a real, actively maintained, MIT-licensed
tool (`github.com/vercel-labs/skills`, not the same thing as the
agentskills.io spec site itself, but built for skills conforming to it).
Verified against its actual source rather than the README alone: it
auto-finds a nested `SKILL.md` up to 3 levels deep (no `subpath` field
needed at all), installs into a canonical `~/.agents/skills/<name>` and
then symlinks every OTHER requested agent's native directory to that
canonical copy in one call (including `~/.claude/skills/<name>` for
Claude Code - confirmed by inspecting the actual resulting symlink after
a real install), and re-running `add` on an already-installed skill is a
clean, safe overwrite (`rm -rf` the canonical dir + recopy, no error, no
prompt with `--yes`) - i.e. already idempotent, no state-tracking needed.
That made the hand-rolled cache/subpath/symlink code pure duplicated,
worse-maintained logic for a problem someone else had already solved
properly. Dropped it.

**Current shape:** `agent-skills.txt` is back down to 3 fields -
`name|source|note` - since `npx skills add` parses ref/subpath out of
`source` itself (a plain `owner/repo` is enough unless the repo has
multiple skills, `SKILL.md` sits deeper than 3 levels, or you need a
non-default branch). `install-agent-extensions.sh` just shells out to
`npx --yes skills add "$source" --agent claude-code codex --global --yes`
per entry - `SKILL_AGENTS` in the script controls which agents every
entry installs for. Trade-off, disclosed in both files: this replaces a
pure git+bash, fully-offline-auditable mechanism with one that runs
`npx skills@latest` - an unpinned third-party npm package - at
install/update time. Node/npx is already required by this dev stack, so
it's a new trust surface, not a new runtime dependency.

Verified with a full smoke test against the REAL `tt-a1i/archify` repo
(not a fake fixture this time, since the whole point was confirming the
real tool's real behavior) from a scratch `$HOME`: confirmed the
canonical copy lands at `~/.agents/skills/archify`, `~/.claude/skills/archify`
is a real symlink to it (`../../.agents/skills/archify`) with `SKILL.md`
readable through it, a second run overwrites cleanly with no errors, and
`--status` correctly reports `OK` - which needed its own fix along the
way: `npx skills list` defaults to *project* scope and prints `[]` for
everything installed `--global`, discovered by testing rather than
assumed from the `--help` text alone.

### Update (2026-09-08): Claude Code plugins moved into `settings.json`, `claude-plugins.txt` dropped

Same kind of reassessment as the `npx skills` switch above, this time for
the other half of `install-agent-extensions.sh` - the Claude-only plugin
section that used to maintain its own registry file,
`agent-extensions/claude-plugins.txt` (`marketplace-name|marketplace-
source|plugin-name|note`, one line per plugin), and call `claude plugin
marketplace add` / `claude plugin install` for each entry after checking
both with hand-written `claude plugin ... --json` parsing.

**What changed, and why:** checked Anthropic's own current docs rather
than assuming the CLI-wrapper approach was still the best one, and found
two things that mattered:

1. `claude plugin marketplace add` on an already-registered name is
   explicitly documented as a safe *replace*, not an error - so the
   script's own `marketplace_installed()` pre-check before adding was
   unnecessary complexity for that half. (`claude plugin install`'s
   idempotency on an already-installed plugin is a different story - not
   reliably documented, and real open Claude Code GitHub issues show
   buggy "already installed" detection - so that pre-check stayed.)
2. Anthropic's docs describe declaring `extraKnownMarketplaces` and
   `enabledPlugins` directly in `settings.json` as the *recommended* way
   to check plugin configuration into version control - not just an
   enterprise-policy mechanism. Since this repo already chezmoi-manages
   `~/.claude/settings.json.tmpl`, maintaining a second, parallel
   `claude-plugins.txt` list of the same information was duplicating a
   place to declare intent that already existed and was already
   version-controlled.

One nuance confirmed before relying on it: at **user/global** scope
(`~/.claude/settings.json`, what this repo manages - not a project's
`.claude/settings.json`), there's no "trust this folder" prompt gating
`extraKnownMarketplaces` the way there is for a project settings file
someone else's repo might ship - every documented instance of that trust
gate in Anthropic's docs is scoped to "the repository" / "teammates"
opening a project folder, never to the user's own global config. So a
marketplace declared in this repo's `settings.json.tmpl` registers itself
with no interaction needed. What declaring `enabledPlugins` does **not**
do, also confirmed against the docs: fetch the plugin's actual content -
Claude Code still needs `claude plugin install` run at least once for
that, which is exactly the part `install-agent-extensions.sh` still
handles.

**Current shape:** `home/dot_claude/settings.json.tmpl` carries the
declarations (a Go template comment - `{{/* ... */}}`, verified with a
real `text/template` render that it strips cleanly to nothing and leaves
valid JSON behind - documents the exact shape to add, since JSON itself
can't hold a comment the way `claude-plugins.txt` could). `agent-
extensions/claude-plugins.txt` is deleted.
`install-agent-extensions.sh`'s plugin section is now a small
reconciliation loop instead of a registry-driven install: read
`extraKnownMarketplaces`/`enabledPlugins` back out of the *applied*
`~/.claude/settings.json` (not the `.tmpl` source), register every
declared marketplace unconditionally (cheap and confirmed-idempotent),
then install-if-missing every declared-and-enabled plugin (still checked
first, per point 1 above).

Verified with a full smoke test using a fake `claude` CLI shim (no real
Claude Code plugin available to test against in this environment) that
tracks marketplace/plugin state on disk exactly like the real thing would
via `--json` output: a scratch `$HOME` with the `mattpocock`/
`mattpocock-skills` example live in `settings.json` - confirmed a first
run registers the marketplace and installs the plugin, a second run
re-registers the marketplace (harmless) but correctly reports the plugin
as already installed rather than reinstalling, `--status` reports `OK`,
and three failure paths behave correctly: a missing `settings.json` (warns
and skips, doesn't fail the run), invalid JSON in `settings.json` (clear
parse-error message, fails just that section), and nothing declared at
all (silently does nothing, not an error).

### Update (2026-09-08): `settings.json.tmpl` trimmed, `mattpocock` made live, marketplaces pinned by commit sha, `skipDangerousModePermissionPrompt` dropped

Three changes to `home/dot_claude/settings.json.tmpl` in one pass, all
requested directly rather than discovered:

1. **Comment trimmed.** The Go-template comment explaining the plugin
   mechanism (added in the update above) had grown into a multi-paragraph
   block duplicating most of what this file already says, plus a
   "hypothetical example" for `mattpocock/skills` shown only as inline
   JSON text, not live. Cut down to a few lines pointing back here, since
   this doc is where the full mechanism/rationale/troubleshooting
   history actually belongs - the template file's job is to declare
   config, not explain it.

2. **`mattpocock/skills` made live**, replacing the comment-only example.
   Before adding it, cloned the real repo and read its actual
   `marketplace.json` rather than trusting the earlier comment's claim -
   confirmed marketplace name `mattpocock` (not the repo slug `skills`)
   and plugin name `mattpocock-skills`, so the live entry is
   `"mattpocock-skills@mattpocock"` in `enabledPlugins`, matching
   `ayghri/i-have-adhd`'s existing shape.

3. **Both marketplaces pinned to a commit sha.** `extraKnownMarketplaces`'
   `github` source type supports optional `ref` (branch/tag) and `sha`
   fields; when `sha` is set, Claude Code checks out that exact commit
   regardless of what the default branch later becomes. A marketplace is
   arbitrary code these plugins can run, so floating on a branch HEAD
   means a marketplace repo's owner (or anyone who compromises their
   account) can silently change what gets installed on your machine on
   your next `claude plugin marketplace add`/reconcile - pinning closes
   that. Shas were read directly off each repo (`git ls-remote`/`git
   clone`, not assumed): `ayghri/i-have-adhd` at
   `58494af57962b2d7a996b4d419474380a299af5e`, `mattpocock/skills` at
   `3cca18b368ae95cdbdebbff572ccafa662551015`. Tradeoff worth knowing:
   pinning means neither marketplace picks up new plugins or fixes
   automatically - bump the `sha` by hand (`git ls-remote <repo> HEAD`)
   when you want to move it forward.

4. **`skipDangerousModePermissionPrompt: true` removed** from the top
   level of the file (it predated this repo's plugin work and wasn't
   related to it). It silently pre-accepts Claude Code's one-time
   "dangerous mode" (`bypassPermissions`, equivalent to
   `--dangerously-skip-permissions`) consent dialog for every future
   session, at user/global scope - meaning every project you ever open,
   not just trusted ones. Anthropic's own docs on this setting warn that
   `bypassPermissions` "offers no protection against prompt injection or
   unintended actions" and should only be used "in isolated environments
   like containers, VMs, or dev containers without internet access."
   Removing it restores the one-time confirmation dialog as a deliberate
   friction point before that mode activates - asked directly rather than
   changed unilaterally, since it's a real day-to-day behavior tradeoff,
   not a clear-cut bug.

Verified the resulting template with a real `text/template` render
(`go run`) into a scratch `$HOME`, then `json.load`'d the output to
confirm still-valid JSON.

### Update (2026-09-08): `install-agent-extensions.sh --status` wrongly showed installed plugins as NOT INSTALLED

Real bug, caught from the user's own machine, not from testing here. After
enabling `mattpocock-skills@mattpocock` and `i-have-adhd@i-have-adhd`
(previous update), `./install-agent-extensions.sh --status` reported both
as `NOT INSTALLED` even though `claude plugin list --json` on the same
machine showed both present with `"enabled": true`.

**Root cause:** the script's own header comment had already flagged this
as an open risk ("known limitations") - `plugin_installed()`'s schema
guess for `claude plugin list --json` was never confirmed against real
output. It checked for `name`/`marketplace`/`source` keys. The user's
actual output has neither - each entry looks like:

```json
{"id": "mattpocock-skills@mattpocock", "version": "1.2.3", "scope": "user",
 "enabled": true, "installPath": "...", "installedAt": "...", "lastUpdated": "..."}
```

The plugin+marketplace pair lives in `id`, already in `"plugin@marketplace"`
form. `p.get("name")` was always `None`, so the check always failed and
reported NOT INSTALLED regardless of reality - a pure detection bug, no
actual plugin was ever missing.

**Fix:** replaced `plugin_installed()` with `plugin_status()`, which
matches on `id` directly and also surfaces the `enabled` flag as a third
state (`OK` / `DISABLED` / `NOT INSTALLED`) instead of collapsing
"installed but disabled" into "not installed". `ensure_plugin_installed()`
now treats `DISABLED` as "leave it alone, tell the user how to
`claude plugin enable` it by hand" rather than either reinstalling or
silently doing nothing unexplained.

Verified with a fake `claude` CLI shim reproducing the user's exact real
output (marketplace list keeps its `name`-based shape, which was already
correct and untouched; plugin list uses the `id`/`enabled` shape) across
three cases: already-installed+enabled -> `OK`, installed-but-disabled ->
`DISABLED` with no reinstall attempt, and genuinely-not-installed -> a
real `claude plugin install` call fires. Could not re-verify against the
user's actual `claude` binary from this session (no live shell on the
real machine) - the fake-CLI test above is a byte-for-byte match of the
schema the user pasted back, which is as close to "real" as this session
can get without device access to the real `claude` install.
