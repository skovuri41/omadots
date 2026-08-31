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

Nothing in `omadots/home/` uses `.chezmoiignore` today — every plain file
(bashrc, the whole `hypr/`, `nvim/`, etc. tree) is genuinely identical on
every machine that applies it. If a real per-host difference comes up later
(e.g. a laptop-only Hyprland monitor layout, or config that only makes
sense on a work machine), that's the file to add.

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
