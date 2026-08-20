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

The setup already has this wired up: `home/.chezmoi.toml.tmpl` sets
`bitwarden.unlock = "auto"`, and `bitwarden-cli` (the `bw` command) is
installed by `install-dev-stack.sh`. That means chezmoi will call `bw
unlock` itself, on demand, the first time a template in a given `apply`
needs a secret — you just need to have run `bw login` once on that machine
beforehand (see `README.md`).

The rule of thumb: **the chezmoi source state (and the GitHub repo) should
only ever contain the *retrieval logic* — `{{ bitwarden ... }}` — never the
secret itself.** The actual value only ever exists on disk, in the real
target file, after `chezmoi apply` fetches it live from Bitwarden.

**Worked example: an SSH keypair for GitHub, managed through Bitwarden.**

This is the full end-to-end version — generate the key once, store it in
Bitwarden, have chezmoi deploy it (on this machine and every other one),
register the public half with GitHub, and confirm it works.

*1. Generate the keypair, once, on one machine.*

```sh
ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/id_ed25519
```

`ed25519` is what GitHub itself recommends over RSA today. You'll be
prompted for a passphrase — optional, but worth considering even though
Bitwarden already gates access to the file: it's a second layer in case the
private key ever ends up copied somewhere outside Bitwarden's control.

*2. Store the private key in Bitwarden.*

Create an item — a Login or Secure Note both work — name it something like
`omadots-ssh-github`, and attach the file `~/.ssh/id_ed25519` (the private
half; never upload the `.pub` file here, it doesn't need to be secret).

*3. Add the chezmoi source files.*

```
home/private_dot_ssh/private_id_ed25519.tmpl   # the private key (templated, restricted perms)
home/dot_ssh/id_ed25519.pub                    # the public key (plain, not secret)
home/dot_ssh/config                            # tells ssh to use this key for github.com
```

The `private_` prefix on both the directory and the file makes chezmoi set
restrictive permissions on apply (`0700` on `~/.ssh`, `0600` on the key
itself) — SSH refuses to use a private key that's group- or world-readable,
so this isn't optional. `private_id_ed25519.tmpl` contains only the
retrieval call:

```
{{- bitwardenAttachmentByRef "id_ed25519" "item" "omadots-ssh-github" -}}
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

The first `bitwarden*` template call in the run triggers `bw unlock`,
prompts once for your Bitwarden master password, fetches the attachment,
and writes `~/.ssh/id_ed25519` (mode `0600`), `~/.ssh/id_ed25519.pub`, and
`~/.ssh/config`. Nothing secret ever touches the git repo — `git log` on
the `.tmpl` file only ever shows the retrieval call, never the key content.

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
→ `commit` → `push`, per the worked example above), then on each other
machine: `bw login` once if you haven't already, then `chezmoi update`.
Chezmoi unlocks Bitwarden, fetches the same attachment, and writes out the
identical key — so every machine authenticates to GitHub as the same
identity, with nothing copied by hand.

One tradeoff worth knowing before you commit to this: GitHub's model
assumes one key per device, so it can label and revoke them individually.
Reusing a single Bitwarden-sourced key everywhere is simpler and is exactly
what this setup makes easy — but it means revoking that key (e.g. because
one machine was compromised) logs *every* machine out of GitHub at once,
not just the affected one. If that tradeoff doesn't sit well with you, use
the per-machine variant below instead.

### Variant: a different key per machine

Same mechanism, one change: instead of a single fixed Bitwarden item name,
the template looks up an item named after *the machine it's currently
running on*, using the `.chezmoi.hostname` built-in. That means you keep a
**single shared template file** in the repo — pushed once, applied on every
machine — and it resolves to a different key on each one automatically.
Nothing in the source tree needs to be duplicated per host.

*1. Confirm each machine's hostname as chezmoi sees it.*

On each machine, run:

```sh
chezmoi execute-template '{{ .chezmoi.hostname }}'
```

This is the short hostname (up to the first `.`) — write down what it
prints for each machine (e.g. `aditya`, `worklaptop`). You'll use these
exact, case-sensitive strings as the Bitwarden item-name suffix in step 3,
so a mismatch here means the template silently looks up the wrong item (or
none) on that machine.

*2. Generate a separate keypair on each machine.*

```sh
ssh-keygen -t ed25519 -C "your_email@example.com (aditya)" -f ~/.ssh/id_ed25519
```

Run this once per machine, changing the `-C` comment to identify that
machine — it's just a label embedded in the public key, purely for your
own reference in GitHub's key list later.

*3. Store each machine's keypair in Bitwarden under a per-host item name.*

Create one Bitwarden item per machine, named using that machine's hostname
from step 1 — e.g. `omadots-ssh-github-aditya`,
`omadots-ssh-github-worklaptop` — and attach **both** files to it:
`id_ed25519` (private) and `id_ed25519.pub` (public). Attaching the public
key too (rather than tracking it as a plain file like the shared-key
version did) is what lets a single template resolve to different content
per machine — see step 4.

*4. Update the chezmoi templates to branch on hostname.*

```
home/private_dot_ssh/private_id_ed25519.tmpl
home/dot_ssh/id_ed25519.pub.tmpl        ← now a .tmpl too, since its content differs per machine
home/dot_ssh/config                      ← unchanged, same IdentityFile path on every machine
```

```
{{/* home/private_dot_ssh/private_id_ed25519.tmpl */}}
{{- bitwardenAttachmentByRef "id_ed25519" "item" (printf "omadots-ssh-github-%s" .chezmoi.hostname) -}}
```

```
{{/* home/dot_ssh/id_ed25519.pub.tmpl */}}
{{- bitwardenAttachmentByRef "id_ed25519.pub" "item" (printf "omadots-ssh-github-%s" .chezmoi.hostname) -}}
```

`printf "omadots-ssh-github-%s" .chezmoi.hostname` builds the item name at
apply time from whichever machine is running it — on `aditya` it looks up
`omadots-ssh-github-aditya`; on `worklaptop`, `omadots-ssh-github-worklaptop`.
`dot_ssh/config` needs no change from the shared-key version, since
`IdentityFile ~/.ssh/id_ed25519` is the same path on every machine — only
what's *in* that file differs now.

*5. Apply on each machine.*

```sh
chezmoi apply
```

Run on each machine after `bw login` there. Each one fetches its own
attachment from its own Bitwarden item and writes its own distinct key —
same command everywhere, different result per machine, by design.

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

Commit and push the three files from step 4 (`chezmoi cd` → `git add` →
`commit` → `push`). Unlike a normal config change, you do **not** need to
touch this template again when you add a future machine — just repeat
steps 1–3 and 6–7 for the new machine (new keypair, new Bitwarden item
named after its hostname, register its public key with GitHub), and the
same already-pushed template picks it up on `chezmoi apply` with zero
further edits to the repo.

Other Bitwarden template functions worth knowing, for different kinds of
secrets:

- `{{ (bitwarden "item" "some-login").login.password }}` — a plain login
  password field (e.g. for a `.netrc` or an API client config that needs a
  password inline).
- `{{ (bitwardenFields "item" "some-login").token.value }}` — a *custom
  field* you defined on the Bitwarden item yourself (e.g. an API token you
  saved under a field literally named `token`).

Same pattern every time: store the secret in Bitwarden, reference it with a
`bitwarden*` call inside a `.tmpl` file in the source state, and let
`chezmoi apply` do the fetching. This is the mechanism to reach for the
first time you actually need a live secret (API token, GPG key, etc.) —
none of the files migrated so far needed one.
