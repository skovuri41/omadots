# Omarchy setup — customization checklist

Running checklist of major customization work. Check off `[ ]` → `[x]` as
items get done; add new `- [ ]` lines under Next steps as new ideas come up.
Details/reasoning for anything here live in the claude.ai project docs
(`dotfiles-migration-plan.md`, `dev-stack-setup.md`, `chord-atlas-reference.md`)
or chat history — this file stays a scannable checklist.

## Dotfiles / chezmoi

- [x] Migrate dotfiles to a chezmoi-managed tree
- [x] Merge the full standard Omarchy config set into it
- [x] Sort out XDG placement per tool
- [x] Replace git submodules with a chezmoi external (doom.d)
- [x] Remove an insecure git TLS-disable setting
- [x] Fix alias/function collisions with newly installed tools
- [x] Modernize several stale aliases/functions
- [x] Rename the device folder (archdots → omadots)

## Dev stack installer

- [x] Build `install-dev-stack.sh` for the full dev toolchain
- [x] Refactor it to be registry-driven / open-closed
- [x] Add `--status` and `--check` modes
- [x] Add failsafe error handling
- [x] Wire it up as a self-updating Omarchy post-update hook
- [x] Enable Emacs as a systemd daemon, clean up emacsclient aliases
- [x] Add GitHub CLI
- [x] Build a single-page HTML doc-site generator

## Hyprland

- [x] Fix the windowrulev2 full-string-match regex bug
- [x] Add workspace back-and-forth on SUPER+P
- [x] Increase top-bar/font size via a shell.toml override

## Keybinding coherence (Doom/evil <-> herdr <-> tmux)

- [x] Align focus + split keys to h/j/k/l
- [x] Resolve the resulting keybinding collisions
- [x] Match resize keys to Hyprland's pattern, make them sticky/repeatable
- [x] Build and publish the Chord Atlas cross-tool keybinding reference

## Other

- [x] Citrix Workspace manual-install instructions

## Reliability fixes

- [x] Fix Emacs daemon "second daemon appears" bug (ALTERNATE_EDITOR/-a
      race) + safe emacsclient wrapper + estart/erestart/estop/estatus/elog
      aliases + emacs.service WantedBy=graphical-session.target
- [x] Make Emacs follow Omarchy's system monospace font (new
      font-set.d hook restarts the daemon on font change); font *size*
      sync evaluated and deliberately deferred (see Next steps)
- [x] Switch chezmoi's secret backend from `bw` to `bws` (Bitwarden
      Secrets Manager) — `bw`'s per-`chezmoi apply` master-password
      prompt was structural (sessions never persist across processes),
      not a config bug; see `dev-stack-setup.md`'s "Bitwarden secret
      backend: bw → bws" section for the full writeup

## Next steps

- [ ] Apply the doom.d snippet by hand (separate repo, outside chezmoi):
      change `doom-font`/`doom-big-font`'s `:family` from
      `"JetBrains Mono"` to `"Monospace"`, keep `:size` unchanged
- [ ] After that: `chezmoi apply`, then run `omarchy-font-set <font>` once
      to confirm both the terminals re-theme and the new hook restarts
      the Emacs daemon with the new font
- [ ] Revisit Emacs font *size* sync later if wanted — no Omarchy hook
      exists for text-size changes; a float `font-spec :size` (e.g.
      `11.0`, matching the terminal's point size) sizes consistently —
      confirmed Emacs's PGTK point→pixel conversion uses a fixed 96dpi
      assumption, not the HiDPI `scale=2` monitor setting, so no
      scale-factor math is needed (corrects an earlier assumption here)
- [ ] Configure Vimium (Chromium) to complete the 4-tool h/j/k/l coherence system
- [ ] Execute the drafted "dotfiles review" batch: shell alias bugs, tmux
      escape-time conflict, terminal config parity/dedup, Hyprland
      monitor/zathura theme comments, Neovim load-order & Mason fixes
- [ ] Verify herdr's copy-mode h/j/k/l navigation (flagged unverified in Chord Atlas)
- [ ] Confirm zathurarc's Omarchy theme integration (needs an on-device check)
- [ ] Check `chromium-flags.conf` for drift vs. Omarchy's own default
- [ ] Check whether kitty's remote-control socket is still needed under Quickshell
- [ ] Add a live `bws`-backed secret template (pattern documented in
      CHEZMOI-GUIDE.md's rewritten SSH-keypair example, none created
      yet — needs a Bitwarden Secrets Manager org/project/machine
      account + access token set up in the web vault first)
- [ ] Author per-machine chezmoi overrides once a second machine joins
- [ ] Confirm emacs-wayland has libsystemd notify support, then optionally
      flip emacs.service to Type=notify (`ldd $(command -v emacs) | grep -i systemd`)
- [ ] Review and commit the pending chezmoi changes (`chezmoi diff` / `git add` / `git commit`)
