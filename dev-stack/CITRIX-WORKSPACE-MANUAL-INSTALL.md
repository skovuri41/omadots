# Citrix Workspace App — manual install (AUR out of date)

`dev-stack-software.txt` lists Citrix Workspace as `aur-fragile` (`icaclient`),
installed via `yay`/`makepkg` like any other AUR package — see
`README-dev-stack.md`'s "Citrix Workspace" section and
`step_aur_fragile()` in `install-dev-stack.sh`. That's still the intended
long-term path.

As of 2026-08-23, the AUR `icaclient` package was out of date enough that
the automated route wasn't usable, so Citrix Workspace was installed by hand
from the official tarball instead. This file is that procedure, verified
working on this machine (aditya — X1 Carbon Aura Gen 13, Omarchy 4.0.0
"Quattro", Hyprland/Wayland).

**Once the AUR package is current again**, this whole file becomes
reference-only — just run `./install-dev-stack.sh` (or `yay -S icaclient`
directly) and the existing `aur-fragile` entry takes over. Nothing needs to
change in `dev-stack-software.txt` for that; see the note at the bottom.

## 1. Download

From <https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html>
("Workspace App > Linux") — a free Citrix account is required. Grab the
`linuxx64-<version>.tar.gz` tarball (64-bit Intel; use `linuxarm64-*` on ARM).

## 2. Install the libraries Citrix needs first

The tarball installer does **no** dependency resolution — it fails or
segfaults silently if something's missing:

```bash
sudo pacman -S --needed gtk2 webkit2gtk gdk-pixbuf2 nss
```

## 3. Extract and run the installer

```bash
cd ~/Downloads   # wherever the download landed
tar xvzf linuxx64-*.tar.gz
cd ICAClient      # or wherever it extracted to - check with `tar tzf` if unsure
./setupwfc
```

Walk through the prompts: `1` to install, Enter to accept the default path
(`$HOME/ICAClient/platform` as a normal user, `/opt/Citrix/ICAClient` under
`sudo`), `y` for desktop integration, `y`/`n` for GStreamer multimedia
support as preferred, `3` to exit once done.

On this machine it landed at `~/ICAClient/linuxx64` (not the generic
`.../platform` the official docs describe — the exact subdirectory name
varies by version/build, so check with `ls ~/ICAClient` after install rather
than assuming).

## 4. Point ICAROOT at the install

Add to your shell rc (`home/dot_bash_exports`, or wherever you keep
exports):

```bash
export ICAROOT="$HOME/ICAClient/linuxx64"   # match whatever setupwfc actually used
```

## 5. Wire up SSL certificates

Needed for HDX connections to resolve — Citrix doesn't pick up the system
trust store automatically:

```bash
mkdir -p "$ICAROOT/keystore/cacerts"
cd "$ICAROOT/keystore/cacerts"
cp /etc/ca-certificates/extracted/tls-ca-bundle.pem .
awk 'BEGIN{c=0} /BEGIN CERT/{c++} {print > "cert."c".pem"}' tls-ca-bundle.pem
"$ICAROOT/util/ctx_rehash"
```

## 6. Hyprland/Wayland gotcha

Omarchy runs Wayland by default, and there's a known issue on Arch-family
systems where a Citrix session hangs forever on "Connecting…". Two things
fix it (confirmed via an active Arch Linux Forums thread):

- Force the GTK backend to X11 (XWayland) when launching, since the Citrix
  GTK UI isn't Wayland-native:
  ```bash
  GDK_BACKEND=x11 "$ICAROOT/selfservice"
  ```
- If that alone doesn't clear it, install `gdk-pixbuf2-noglycin` from the
  AUR — one user's confirmed fix for the same infinite "Connecting…" hang (a
  `gdk-pixbuf2` image-loader incompatibility, unrelated to the actual server
  connection).

## 7. Launch and configure a store

```bash
"$ICAROOT/selfservice" -icaroot "$ICAROOT" +addStore
```

If the desktop-integration prompt in step 3 said yes, there should also be a
launcher entry now (check `~/.local/share/applications/` for a
`wfica.desktop`/`selfservice.desktop` entry) — worth binding to a Hyprland
keybind or webapp-style launcher the way the other apps in `bindings.lua`
are, if wanted.

## Switching back to the AUR install later

`dev-stack-software.txt` doesn't need to change — the `Citrix Workspace|aur-fragile|icaclient|icaclient|...`
entry is already there and untouched. `install-dev-stack.sh --status` checks
for this manual install directly (see the `icaclient` special-case in
`print_status()`) so it won't misreport "NOT INSTALLED" in the meantime.
There's also a `install_citrix_manual()` reference function, commented out,
sitting next to `install_keyd()`/`install_polylith()` in
`install-dev-stack.sh` — it mirrors this file so the two can't drift apart
silently, but it's intentionally not wired into `dispatch_custom()`, so it
never runs on its own. When the AUR package is fixed, just delete/ignore
this file and that function; nothing else needs to change.

## Sources

- [Install, Uninstall, and Update — Citrix Workspace app for Linux docs](https://docs.citrix.com/en-us/citrix-workspace-app-for-linux/installation.html)
- [Configuring Citrix Workspace on Arch Linux](https://nithiya.gitlab.io/post/configure-citrix-workspace-linux/)
- [Arch Linux Forums: Citrix Workspace won't work, while on Debian yes [SOLVED]](https://bbs.archlinux.org/viewtopic.php?id=312653)
- [Citrix Workspace app for Linux download page](https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html)
