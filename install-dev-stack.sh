#!/usr/bin/env bash
# install-dev-stack.sh
#
# Bootstrap AND ongoing-maintenance script for a fresh Omarchy install.
# What it installs is NOT in this file - it's declared in
# dev-stack-software.txt (same directory), one line per tool. To add,
# remove, or change a piece of software, edit that file; this script never
# needs to change for that (open/closed - see below). Currently that list
# covers Java, Maven, Clojure CLI, Polylith (poly), Node/npm (LTS), Emacs +
# Doom Emacs, uv, curl, sqlite, tree, tre, jq, zathura, Citrix Workspace,
# chezmoi, the Bitwarden CLI (bw, for ad hoc personal-vault access), bws
# (Bitwarden Secrets Manager CLI - chezmoi's actual secret backend as of
# 2026-08-31, see CHEZMOI-GUIDE.md), and the GitHub CLI.
#
# Also enables the Emacs daemon as a systemd --user service, once chezmoi
# has put its unit file in place (see below) - emacsclient (ec/emax/semacs/
# ekill aliases, see CHEZMOI-GUIDE.md) then always has a running daemon to
# talk to, and the app launcher gets an emacsclient-backed .desktop entry.
#
# Pairs with the chezmoi source state in omadots/home (see
# omadots/README.md) - run `chezmoi init --apply` BEFORE this script on a
# fresh box so ~/.config/doom is already your real config by the time Doom
# gets installed here, and so ~/.config/systemd/user/emacs.service and
# ~/.local/share/applications/emacs.desktop already exist by the time this
# script tries to enable the daemon.
#
# Usage:
#   ./install-dev-stack.sh              install/upgrade everything (safe to re-run)
#   ./install-dev-stack.sh --status     print a table of what's installed, and
#                                       what's newer upstream, with no changes
#   ./install-dev-stack.sh --check NAME help decide how to install something new:
#                                       probes pacman/AUR/mise for NAME and
#                                       prints a suggested dev-stack-software.txt
#                                       line - makes no changes
#   ./install-dev-stack.sh -h           this help
#
# Design principles:
#   - Open/closed: the software list lives in dev-stack-software.txt, not in
#     this script. Adding pacman/AUR/mise-installable software is a one-line
#     text edit, never a script edit. Only a genuinely new *bespoke* install
#     (like Doom or Polylith below) needs a new function here - see "custom
#     entries" in dev-stack-software.txt's header comment for why that one
#     case is intentionally not made pluggable.
#   - Prefer the same install method Omarchy/Arch would use for everything:
#     official pacman package first, AUR (via yay) second, and only a raw
#     GitHub-release download as a last resort (Polylith - see below).
#   - Skip anything already provided by a standard Omarchy install. Every
#     step below is idempotent and checks before it acts, so it's also safe
#     to just run this on top of an existing setup.
#   - Failsafe: one tool failing to install must not stop the rest. Every
#     step is wrapped so failures are logged and collected into a summary
#     at the end, never a hard abort. (Citrix Workspace is the one item
#     here that's genuinely likely to fail on a fully unattended run - it's
#     flagged aur-fragile in dev-stack-software.txt and handled by
#     step_aur_fragile below, not a hard failure.)
#   - "Same script" maintenance: this file copies itself (and
#     dev-stack-software.txt alongside it) to
#     ~/.local/share/dev-stack/ on first run and registers that copy as an
#     Omarchy post-update hook. So `omarchy update` re-runs this exact
#     script against this exact software list (install is idempotent, so a
#     re-run is just an upgrade pass), rather than a second hand-rolled
#     updater living in the hooks directory.
#   - Any PATH additions a custom install needs are written idempotently to
#     ~/.config/dev-stack/env.sh, never directly into ~/.bashrc or any other
#     chezmoi-managed file - chezmoi overwrites its managed files from its
#     own source state on every `chezmoi apply`, so anything this script
#     appended directly to one of them would silently vanish on the next
#     apply. dev-stack-software.txt's chezmoi-tracked counterpart
#     (home/dot_bash_exports) sources env.sh once, unconditionally; this
#     script only ever writes inside env.sh after that.
#
# Verified against Omarchy 4.0.0 "Quattro" (tag v4.0.0, 2026-08-14). See
# README-dev-stack.md for the full source list and reasoning per tool.

set -uo pipefail

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------
log()  { echo -e "\e[32m\n==> $*\e[0m"; }
warn() { echo -e "\e[33m$*\e[0m" >&2; }
err()  { echo -e "\e[31m$*\e[0m" >&2; }

FAILURES=()
fail() { FAILURES+=("$1"); warn "$1 - FAILED (continuing)"; }

DEV_STACK_DIR="$HOME/.local/share/dev-stack"
POLY_DIR="$DEV_STACK_DIR/polylith"
POLY_BIN="$HOME/.local/bin/poly"
BWS_DIR="$DEV_STACK_DIR/bws"
BWS_BIN="$HOME/.local/bin/bws"
SELF_COPY="$DEV_STACK_DIR/install-dev-stack.sh"
PATH_ENV_FILE="$HOME/.config/dev-stack/env.sh"

# Resolves next to wherever THIS script actually lives - when run from the
# installed self-copy (via the Omarchy post-update hook), that's
# $DEV_STACK_DIR, where install_hook() also copies the software list; when
# run directly from a checkout, that's the checkout directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REGISTRY_FILE="${DEV_STACK_REGISTRY_FILE:-$SCRIPT_DIR/dev-stack-software.txt}"

mkdir -p "$DEV_STACK_DIR" "$HOME/.local/bin"

# ---------------------------------------------------------------------------
# Tool registry - open/closed: the actual software list lives in
# $REGISTRY_FILE (dev-stack-software.txt), not here. See that file's header
# comment for the name|method|spec|status_pkg|note format. This script only
# knows how to READ that format and dispatch on `method` - adding a new
# pacman/AUR/mise-installable tool is a one-line edit there, never here.
# ---------------------------------------------------------------------------
REGISTRY=()

load_registry() {
  if [[ ! -f $REGISTRY_FILE ]]; then
    err "Software list not found: $REGISTRY_FILE"
    err "Expected dev-stack-software.txt next to install-dev-stack.sh (or set"
    err "DEV_STACK_REGISTRY_FILE to point at it explicitly)."
    exit 1
  fi

  local lineno=0 line
  while IFS= read -r line || [[ -n $line ]]; do
    lineno=$((lineno + 1))
    [[ -z ${line// } ]] && continue      # blank (or whitespace-only) line
    [[ $line == \#* ]] && continue       # comment

    local field_count
    field_count=$(awk -F'|' '{print NF}' <<<"$line")
    if [[ $field_count -ne 5 ]]; then
      warn "Skipping $REGISTRY_FILE line $lineno - expected 5 '|'-separated fields, found $field_count: $line"
      continue
    fi
    REGISTRY+=("$line")
  done <"$REGISTRY_FILE"

  if [[ ${#REGISTRY[@]} -eq 0 ]]; then
    err "$REGISTRY_FILE has no usable entries - nothing to do."
    exit 1
  fi
}

load_registry

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
if ! command -v omarchy-pkg-add >/dev/null 2>&1; then
  err "This script expects Omarchy's helper commands (omarchy-pkg-add, mise, ...) on PATH."
  err "Run it on an Omarchy install, in a normal login shell."
  exit 1
fi

if ! command -v mise >/dev/null 2>&1; then
  log "mise (not found - installing; Omarchy ships this by default, so this is a fallback)"
  # Omarchy 4 "Quattro" renamed the base package from mise-bin to mise.
  omarchy-pkg-add mise || { err "Could not install mise - aborting (everything else depends on it)."; exit 1; }
fi

eval "$(mise activate bash)"

# ---------------------------------------------------------------------------
# Install/upgrade steps
# ---------------------------------------------------------------------------
step_pacman() {
  local desc="$1"; shift
  if omarchy-pkg-add "$@"; then
    log "$desc"
  else
    fail "$desc"
  fi
}

step_aur() {
  local desc="$1" pkg="$2"
  if omarchy-pkg-aur-add "$pkg"; then
    log "$desc"
  else
    fail "$desc"
  fi
}

step_mise() {
  local desc="$1" spec="$2"
  if mise use --global "$spec"; then
    log "$desc"
  else
    fail "$desc"
  fi
}

# Generic handler for method=aur-fragile: same as step_aur, but a failed
# build is treated as "needs a one-time manual step", not a plain failure -
# it's marked with a per-tool marker file (so --status can show "ACTION
# NEEDED" instead of "NOT INSTALLED") and given more actionable guidance
# than a generic AUR failure would. $note comes straight from the tool's
# dev-stack-software.txt line. A few status_pkg values get extra, more
# specific guidance below (currently just icaclient/Citrix) - everything
# else still gets a useful generic message, no script change required.
step_aur_fragile() {
  local desc="$1" pkg="$2" status_pkg="$3" note="$4"
  log "$desc"
  local marker="$DEV_STACK_DIR/${status_pkg}.needs-manual-download"
  if omarchy-pkg-aur-add "$pkg"; then
    rm -f "$marker"
    return
  fi

  warn "$pkg didn't build via AUR. This package is flagged 'aur-fragile' in"
  warn "dev-stack-software.txt - it's known to sometimes need a manual step"
  warn "makepkg can't do unattended (a login/EULA-gated download is the most"
  warn "common cause)."
  [[ -n $note ]] && warn "Note: $note"
  case "$status_pkg" in
    icaclient)
      warn "To finish manually:"
      warn "  1. Download the current Linux Workspace app tarball from citrix.com/downloads"
      warn "     (Workspace App > Linux) - a free Citrix account is required."
      warn "  2. Run 'yay -S $pkg' again; when the automatic download fails, yay"
      warn "     will let you point it at the file you just downloaded."
      warn "  If the AUR package itself is out of date (not just download-gated -"
      warn "  yay retry above still fails after step 2), see"
      warn "  CITRIX-WORKSPACE-MANUAL-INSTALL.md in this repo for the full manual"
      warn "  tarball install that's known to work instead. --status detects that"
      warn "  install too, so it won't keep reporting NOT INSTALLED once you're done."
      ;;
    *)
      warn "Try 'yay -S $pkg' by hand to see exactly what it's waiting on."
      ;;
  esac
  touch "$marker"
  fail "$desc - needs manual attention, see message above"
}

# ---------------------------------------------------------------------------
# Idempotent PATH management for custom installs.
#
# Writes/updates $PATH_ENV_FILE (~/.config/dev-stack/env.sh), NEVER a
# chezmoi-managed file directly - see the design-principles comment at the
# top of this script for why. home/dot_bash_exports sources this file once,
# unconditionally, so anything appended here takes effect in every new
# shell without any further chezmoi involvement.
#
# Usage: dev_stack_path_add '<absolute-path>' '<comment, e.g. tool name>'
# Safe to call every run - only appends the export line if it's not there
# already.
# ---------------------------------------------------------------------------
dev_stack_path_add() {
  local dir="$1" comment="$2"
  mkdir -p "$(dirname "$PATH_ENV_FILE")"
  if [[ ! -f $PATH_ENV_FILE ]]; then
    cat >"$PATH_ENV_FILE" <<'EOF'
# Managed by install-dev-stack.sh - do not hand-edit, changes will be
# overwritten. Sourced once, unconditionally, from home/dot_bash_exports
# (chezmoi-managed). Safe to delete: it'll be regenerated on the next run
# of install-dev-stack.sh for whichever custom installs still need it.
EOF
  fi
  local export_line="export PATH=\"$dir:\$PATH\""
  if ! grep -qF "$export_line" "$PATH_ENV_FILE" 2>/dev/null; then
    { echo "# $comment"; echo "$export_line"; } >>"$PATH_ENV_FILE"
  fi
  export PATH="$dir:$PATH"
}

install_doom() {
  log "Doom Emacs"
  if [[ -d "$HOME/.config/emacs" ]]; then
    if "$HOME/.config/emacs/bin/doom" upgrade --force && "$HOME/.config/emacs/bin/doom" sync --force; then
      log "Doom Emacs upgraded"
    else
      fail "Doom Emacs upgrade"
    fi
    return
  fi

  if ! git clone --depth 1 https://github.com/doomemacs/core "$HOME/.config/emacs"; then
    fail "Doom Emacs clone"
    return
  fi
  # Doom's language/feature modules live in a separate repo, wired in as a
  # git submodule (sources/doom+). doom install/sync fetch it automatically;
  # pre-fetching here just makes the first install deterministic.
  git -C "$HOME/.config/emacs" submodule update --init --recursive || true

  if ! "$HOME/.config/emacs/bin/doom" install --force; then
    fail "Doom Emacs install"
    return
  fi

  # home/dot_bash_exports already prepends this path statically once chezmoi
  # is applied; this is the failsafe for running the script before that (or
  # on a shell dev_stack_path_add hasn't reached yet) - see the PATH design
  # note at the top of this script. (No fish handling here: this setup is
  # bash-only - see home/ in omadots - and fish doesn't understand the
  # bash `export` syntax that used to be blindly appended to its config.)
  dev_stack_path_add "$HOME/.config/emacs/bin" "Doom Emacs"

  # If chezmoi already populated ~/.config/doom (its .chezmoiexternal.toml
  # points doom.d at your real config), `doom install` above will have found
  # it already there and left it alone - so this template edit only ever
  # touches the vanilla generated init.el, never your real one. Run
  # `chezmoi init --apply` before this script on a fresh box for that to
  # apply; see omadots/README.md.
  local doom_init="$HOME/.config/doom/init.el"
  if [[ -f $doom_init ]]; then
    log "Enabling :lang java and :lang clojure in $doom_init"
    sed -i \
      -e 's/^\(\s*\);;(java +lsp)/\1java/' \
      -e 's/^\(\s*\);;clojure /\1clojure /' \
      "$doom_init"
  fi

  if "$HOME/.config/emacs/bin/doom" sync --force; then
    log "Doom Emacs installed"
  else
    fail "Doom Emacs sync"
  fi
}

enable_emacs_daemon() {
  log "Emacs daemon (systemd --user service)"
  local unit="$HOME/.config/systemd/user/emacs.service"

  if [[ ! -f $unit ]]; then
    warn "No unit file at $unit yet - this comes from chezmoi"
    warn "(home/dot_config/systemd/user/emacs.service). Run 'chezmoi apply'"
    warn "and re-run this script to enable the daemon."
    fail "Emacs daemon (systemd --user service) - unit file not present, skipped"
    return
  fi

  if ! command -v systemctl >/dev/null 2>&1; then
    fail "Emacs daemon (systemd --user service) - systemctl not found"
    return
  fi

  systemctl --user daemon-reload
  if systemctl --user enable --now emacs.service; then
    log "Emacs daemon enabled and started ('systemctl --user status emacs' to check)"
  else
    fail "Emacs daemon (systemd --user service) - enable/start failed"
  fi
}

install_keyd() {
  log "keyd (kernel-level key remapper: capslock + home row mods)"

  if ! omarchy-pkg-add keyd; then
    fail "keyd - package install failed"
    return
  fi

  if ! command -v chezmoi >/dev/null 2>&1; then
    fail "keyd - chezmoi not on PATH, can't locate keyd/default.conf in your dotfiles repo"
    return
  fi

  local source_path repo_root conf_src
  source_path=$(chezmoi source-path 2>/dev/null)
  if [[ -z $source_path ]]; then
    fail "keyd - 'chezmoi source-path' failed, is chezmoi initialized yet?"
    return
  fi

  # chezmoi source-path returns the .chezmoiroot-adjusted dir (this repo's
  # home/, per .chezmoiroot: home) - NOT the git repo root. keyd/default.conf
  # lives one level up, alongside install-dev-stack.sh, so resolve the real
  # repo root via git instead of assuming a fixed number of '..' hops (keeps
  # working even if .chezmoiroot ever changes).
  repo_root=$(git -C "$source_path" rev-parse --show-toplevel 2>/dev/null)
  if [[ -z $repo_root ]]; then
    fail "keyd - couldn't resolve the dotfiles repo root from $source_path (not a git checkout?)"
    return
  fi

  conf_src="$repo_root/keyd/default.conf"
  if [[ ! -f $conf_src ]]; then
    warn "No config at $conf_src yet - this isn't chezmoi-managed (keyd reads root-owned"
    warn "/etc/keyd/default.conf; chezmoi only manages your home dir), so it's just stored"
    warn "in the repo for version control. Add it, then re-run this script."
    fail "keyd - default.conf not found in dotfiles repo, skipped"
    return
  fi

  if [[ -f /etc/keyd/default.conf ]] && diff -q "$conf_src" /etc/keyd/default.conf >/dev/null 2>&1; then
    log "keyd config already up to date"
  elif sudo cp "$conf_src" /etc/keyd/default.conf; then
    log "keyd config deployed to /etc/keyd/default.conf"
  else
    fail "keyd - couldn't copy config to /etc/keyd/default.conf"
    return
  fi

  if ! command -v systemctl >/dev/null 2>&1; then
    fail "keyd - systemctl not found"
    return
  fi

  if systemctl is-active --quiet keyd; then
    if sudo keyd reload; then
      log "keyd already running, reloaded new config"
    else
      fail "keyd - reload failed"
    fi
  elif sudo systemctl enable --now keyd; then
    log "keyd enabled and started ('sudo systemctl status keyd' to check)"
  else
    fail "keyd - enable/start failed"
  fi
}

poly_latest_tag() {
  curl -fsSL -o /dev/null -w '%{url_effective}' \
    https://github.com/polyfy/polylith/releases/latest 2>/dev/null | sed -E 's#.*/tag/##'
}

poly_installed_version() {
  local jar
  jar=$(ls "$POLY_DIR"/poly-*.jar 2>/dev/null | sort -V | tail -1)
  [[ -n $jar ]] && basename "$jar" | sed -E 's/^poly-(.*)\.jar$/\1/'
}

install_polylith() {
  log "Polylith (poly)"
  local tag version current
  tag=$(poly_latest_tag)
  if [[ -z $tag ]]; then
    fail "Polylith (poly) - couldn't resolve the latest GitHub release (network?)"
    return
  fi
  version=${tag#v}
  current=$(poly_installed_version)
  if [[ $current == "$version" ]]; then
    log "Polylith (poly) $version already up to date"
    return
  fi

  mkdir -p "$POLY_DIR"
  local jar_url="https://github.com/polyfy/polylith/releases/download/${tag}/poly-${version}.jar"
  if ! curl -fsSL -o "$POLY_DIR/poly-${version}.jar.tmp" "$jar_url"; then
    fail "Polylith (poly) - download failed: $jar_url"
    rm -f "$POLY_DIR/poly-${version}.jar.tmp"
    return
  fi
  mv "$POLY_DIR/poly-${version}.jar.tmp" "$POLY_DIR/poly-${version}.jar"
  # Keep only the current jar so version lookup stays unambiguous.
  find "$POLY_DIR" -maxdepth 1 -name 'poly-*.jar' ! -name "poly-${version}.jar" -delete

  local java_bin
  java_bin=$(command -v java || echo /usr/bin/java)
  cat >"$POLY_BIN" <<EOF
#!/bin/sh
ARGS=""
while [ "\$1" != "" ]; do
  ARGS="\$ARGS \$1"
  shift
done
exec "$java_bin" \$JVM_OPTS -jar "$POLY_DIR/poly-${version}.jar" \$ARGS
EOF
  chmod +x "$POLY_BIN"
  log "Polylith (poly) $version installed to $POLY_BIN"
}

# No official Arch/AUR package could be verified for bws (Bitwarden Secrets
# Manager CLI) at the time this was written - Bitwarden's own docs point at
# a prebuilt-binary GitHub release, so this mirrors that install method
# rather than Polylith's "latest via redirect" approach: sdk-sm is a shared
# monorepo for several Bitwarden products, so /releases/latest doesn't
# reliably mean "latest bws" the way it does for Polylith's single-purpose
# repo. Version is pinned instead and bumped by hand - see BWS_TARGET_VERSION.
BWS_TARGET_VERSION="2.1.0"

bws_installed_version() {
  [[ -x $BWS_BIN ]] || return 0
  "$BWS_BIN" --version 2>/dev/null | awk '{print $NF}'
}

install_bws() {
  log "Bitwarden Secrets Manager CLI (bws)"
  local current
  current=$(bws_installed_version)
  if [[ $current == "$BWS_TARGET_VERSION" ]]; then
    log "bws $BWS_TARGET_VERSION already up to date"
    return
  fi

  if ! command -v unzip >/dev/null 2>&1; then
    fail "bws - 'unzip' not found, can't extract the release download"
    return
  fi

  local os_name platform arch_name
  os_name=$(uname -s)
  if [[ $os_name != Linux ]]; then
    fail "bws - unsupported OS '$os_name' (this script only targets Omarchy/Linux)"
    return
  fi
  platform="unknown-linux-gnu"

  arch_name=$(uname -m)
  case "$arch_name" in
    x86_64|aarch64) : ;; # matches bitwarden/sdk-sm's release-asset naming directly
    *)
      fail "bws - unsupported architecture '$arch_name'"
      return
      ;;
  esac

  mkdir -p "$BWS_DIR"
  local asset="bws-${arch_name}-${platform}-${BWS_TARGET_VERSION}.zip"
  local zip_url="https://github.com/bitwarden/sdk-sm/releases/download/bws-v${BWS_TARGET_VERSION}/${asset}"
  local sum_url="https://github.com/bitwarden/sdk-sm/releases/download/bws-v${BWS_TARGET_VERSION}/bws-sha256-checksums-${BWS_TARGET_VERSION}.txt"
  local zip_file="$BWS_DIR/$asset"
  local sum_file="$BWS_DIR/bws-${BWS_TARGET_VERSION}-checksums.txt"

  if ! curl -fsSL -o "$zip_file" "$zip_url"; then
    fail "bws - download failed: $zip_url"
    rm -f "$zip_file"
    return
  fi
  if ! curl -fsSL -o "$sum_file" "$sum_url"; then
    fail "bws - checksum file download failed: $sum_url"
    rm -f "$zip_file" "$sum_file"
    return
  fi

  local expected actual
  expected=$(grep -F "$asset" "$sum_file" | awk '{print $1}')
  actual=$(sha256sum "$zip_file" 2>/dev/null | awk '{print $1}')
  if [[ -z $expected || $expected != "$actual" ]]; then
    fail "bws - checksum verification failed for $asset (expected '$expected', got '$actual')"
    rm -f "$zip_file" "$sum_file"
    return
  fi

  if ! unzip -oq "$zip_file" -d "$BWS_DIR"; then
    fail "bws - extraction failed"
    rm -f "$zip_file" "$sum_file"
    return
  fi
  rm -f "$zip_file" "$sum_file"

  if [[ ! -f "$BWS_DIR/bws" ]]; then
    fail "bws - expected binary not found in extracted archive"
    return
  fi
  install -m 755 "$BWS_DIR/bws" "$BWS_BIN"
  # ~/.local/bin is already on PATH via home/dot_bash_exports's static
  # prepend_path - same reasoning as Polylith's $POLY_BIN above, no
  # dev_stack_path_add call needed here.
  log "bws $BWS_TARGET_VERSION installed to $BWS_BIN"
}

# install_citrix_manual() - DISABLED, reference only.
#
# dev-stack-software.txt still lists Citrix Workspace as method=aur-fragile
# (see step_aur_fragile() above), and that stays the intended long-term
# install path - this function is NOT wired into dispatch_custom() below, so
# it never runs, and nothing in dev-stack-software.txt points at it. It's
# left here, commented out, purely as a live copy of
# CITRIX-WORKSPACE-MANUAL-INSTALL.md's steps so a future "make this
# automatic" pass has real shell to start from instead of re-deriving it.
#
# Why it exists at all: the AUR icaclient package was out of date enough
# (as of 2026-08-23) that step_aur_fragile()'s normal retry-with-downloaded-
# tarball flow didn't help either - so Citrix was installed by hand from
# the tarball instead. print_status()'s icaclient special-case (see
# citrix_manual_bin() below) already detects that manual install directly,
# so --status doesn't need this function to report correctly.
#
# To bring this back once you want it automated: uncomment the body,
# add `citrix-manual) install_citrix_manual ;;` to dispatch_custom() below,
# and either add a new `method=custom` line for it to dev-stack-software.txt
# or swap the existing Citrix Workspace line's method - whichever you'd
# rather maintain once the AUR package is fixed and this is no longer needed
# at all.
#
# install_citrix_manual() {
#   log "Citrix Workspace (manual tarball install)"
#   warn "This is disabled - see CITRIX-WORKSPACE-MANUAL-INSTALL.md and the"
#   warn "comment above install_citrix_manual() in this script before enabling it."
#   return
#
#   # 1. Download linuxx64-<version>.tar.gz yourself first - Citrix gates
#   #    this behind a login/EULA wall, no unattended download is possible.
#   #    https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html
#   local tarball="$1"   # path to the downloaded tarball, passed in by caller
#   if [[ -z $tarball || ! -f $tarball ]]; then
#     fail "Citrix Workspace (manual) - no tarball path given/found"
#     return
#   fi
#
#   # 2. Dependencies the tarball installer doesn't check for itself.
#   step_pacman "Citrix Workspace deps" gtk2 webkit2gtk gdk-pixbuf2 nss
#
#   # 3. Extract and run the installer non-interactively isn't supported by
#   #    setupwfc (it's a menu-driven installer) - this would need expect/
#   #    a here-string of prompt answers to fully automate, which is why
#   #    this stayed manual rather than becoming a real custom entry yet.
#   local extract_dir="$DEV_STACK_DIR/citrix-extract"
#   mkdir -p "$extract_dir"
#   tar xzf "$tarball" -C "$extract_dir"
#   # ./setupwfc lives somewhere under $extract_dir - run it, answer its
#   # prompts (1, Enter, y, y/n, 3) same as CITRIX-WORKSPACE-MANUAL-INSTALL.md.
#
#   # 4. ICAROOT - wire via dev_stack_path_add-style env.sh, not dot_bash_exports.
#   # dev_stack_path_add "$HOME/ICAClient/linuxx64" "Citrix Workspace ICAROOT"
#
#   # 5. Certs - see CITRIX-WORKSPACE-MANUAL-INSTALL.md step 5, same commands.
#
#   log "Citrix Workspace (manual) installed"
# }

# Fixed dispatch table for method=custom entries - see dev-stack-software.txt's
# header for why this is intentionally NOT a pluggable/external mechanism.
# A status_pkg with no case here fails loudly (not silently skipped), so a
# typo'd or genuinely new custom entry is obvious in the run's summary
# instead of just quietly doing nothing.
dispatch_custom() {
  local desc="$1" status_pkg="$2"
  case "$status_pkg" in
    doom) install_doom ;;
    poly) install_polylith ;;
    bws) install_bws ;;
    emacs-daemon) enable_emacs_daemon ;;
    keyd) install_keyd ;;
    *)
      fail "$desc - no custom install handler registered for status_pkg '$status_pkg' (add a case to dispatch_custom() in install-dev-stack.sh)"
      ;;
  esac
}

# Generic, registry-driven install loop - every entry in dev-stack-software.txt
# is installed by dispatching on its `method` field. This is the one place
# that has to change if a genuinely new *method* is ever needed; adding new
# *software* never touches this function - see dev-stack-software.txt.
run_install() {
  local entry name method spec status_pkg note
  for entry in "${REGISTRY[@]}"; do
    IFS='|' read -r name method spec status_pkg note <<<"$entry"
    case "$method" in
      pacman)
        # spec may be multiple space-separated package names (e.g. "zathura
        # zathura-pdf-mupdf") - deliberately unquoted to word-split.
        # shellcheck disable=SC2086
        step_pacman "$name" $spec
        ;;
      aur)
        step_aur "$name" "$spec"
        ;;
      aur-fragile)
        step_aur_fragile "$name" "$spec" "$status_pkg" "$note"
        ;;
      mise)
        step_mise "$name" "$spec"
        ;;
      custom)
        dispatch_custom "$name" "$status_pkg"
        ;;
      *)
        warn "Skipping '$name' - unknown method '$method' in $REGISTRY_FILE (expected pacman, aur, aur-fragile, mise, or custom)"
        ;;
    esac
  done

  install_hook
}

install_hook() {
  log "Wiring this script into Omarchy's update pipeline"

  # Keep a stable copy so the hook always has something to call, regardless
  # of where/how this script was first run from - and copy the software
  # list alongside it, so the hook's re-runs read the same list this run
  # did, not whatever happens to be at $REGISTRY_FILE later.
  if [[ "$(readlink -f "$0" 2>/dev/null || echo "$0")" != "$SELF_COPY" ]]; then
    cp "$0" "$SELF_COPY"
    chmod +x "$SELF_COPY"
  fi
  if [[ "$(readlink -f "$REGISTRY_FILE" 2>/dev/null || echo "$REGISTRY_FILE")" != "$DEV_STACK_DIR/dev-stack-software.txt" ]]; then
    cp "$REGISTRY_FILE" "$DEV_STACK_DIR/dev-stack-software.txt"
  fi

  local hook_dir="$HOME/.config/omarchy/hooks/post-update.d"
  mkdir -p "$hook_dir"
  cat >"$hook_dir/dev-stack-upgrade.sh" <<EOF
#!/bin/bash
# Installed by install-dev-stack.sh. Re-runs the same script on every
# 'omarchy update' - every step in it is idempotent, so this doubles as
# the upgrade path for everything it doesn't already get for free from
# mise/pacman (Doom Emacs, Polylith).
[[ -x "$SELF_COPY" ]] && "$SELF_COPY"
EOF
  chmod 755 "$hook_dir/dev-stack-upgrade.sh"
}

# ---------------------------------------------------------------------------
# Status table
# ---------------------------------------------------------------------------

# Detects a Citrix Workspace install that pacman doesn't know about - see
# CITRIX-WORKSPACE-MANUAL-INSTALL.md and install_citrix_manual() above. Echoes
# the first Citrix binary found (wfica or selfservice) and returns non-zero
# if none exist. Checked in a few plausible install dirs since the exact
# subdirectory name (e.g. "linuxx64" vs "platform") varies by version/build -
# see the note in CITRIX-WORKSPACE-MANUAL-INSTALL.md's step 3.
citrix_manual_bin() {
  local dir bin
  for dir in "$HOME"/ICAClient/*/ "$HOME/ICAClient/"; do
    for bin in wfica selfservice; do
      [[ -x "${dir}${bin}" ]] && { echo "${dir}${bin}"; return 0; }
    done
  done
  command -v wfica 2>/dev/null && return 0
  return 1
}

print_status() {
  echo "Checking installed vs. available versions..."
  echo "(pacman upgrade check via 'checkupdates', AUR via 'yay -Qua' - both read-only, no sudo)"

  local pac_updates aur_updates
  pac_updates=$(checkupdates 2>/dev/null || true)
  aur_updates=$(yay -Qua 2>/dev/null || true)

  printf "\n%-20s %-12s %-14s %-14s %s\n" "SOFTWARE" "METHOD" "INSTALLED" "LATEST" "STATUS"
  printf '%s\n' "----------------------------------------------------------------------------------"

  local entry name method spec status_pkg
  for entry in "${REGISTRY[@]}"; do
    IFS='|' read -r name method spec status_pkg _ <<<"$entry"
    local installed="" latest="" status=""

    case "$method" in
      pacman|aur|aur-fragile)
        installed=$(pacman -Q "$status_pkg" 2>/dev/null | awk '{print $2}')
        if [[ -z $installed && $status_pkg == icaclient ]] && citrix_manual_bin >/dev/null; then
          # pacman doesn't know about this - it's the manual tarball install
          # from CITRIX-WORKSPACE-MANUAL-INSTALL.md, done because the AUR
          # package was out of date. Report it as installed instead of
          # false-alarming NOT INSTALLED every run.
          installed="manual install"
          latest="-"
          status="OK (manual - see CITRIX-WORKSPACE-MANUAL-INSTALL.md; switch back to AUR once it's current)"
        elif [[ -z $installed ]]; then
          status="NOT INSTALLED"
          latest="-"
          [[ $status_pkg == icaclient ]] &&
            status="NOT INSTALLED (see CITRIX-WORKSPACE-MANUAL-INSTALL.md if AUR keeps failing)"
        else
          local upline
          if [[ $method == pacman ]]; then
            upline=$(grep "^$status_pkg " <<<"$pac_updates")
          else
            upline=$(grep "^$status_pkg " <<<"$aur_updates")
          fi
          if [[ -n $upline ]]; then
            latest=$(awk '{print $NF}' <<<"$upline")
            status="UPDATE AVAILABLE"
          else
            latest="$installed"
            status="OK"
          fi
        fi
        # Don't let a stale marker from an earlier failed AUR attempt stomp
        # the "OK (manual)" status just set above once a manual install is
        # actually detected.
        if [[ $method == aur-fragile && -f "$DEV_STACK_DIR/${status_pkg}.needs-manual-download" && $installed != "manual install" ]]; then
          status="ACTION NEEDED (manual download)"
        fi
        ;;
      mise)
        installed=$(mise current "$status_pkg" 2>/dev/null | awk '{print $1}')
        if [[ -z $installed ]]; then
          status="NOT INSTALLED"
          latest=$(mise latest "$status_pkg" 2>/dev/null || echo "?")
        else
          latest=$(mise latest "$status_pkg" 2>/dev/null || echo "$installed")
          [[ "$installed" == "$latest" ]] && status="OK" || status="UPDATE AVAILABLE"
        fi
        ;;
      custom)
        case "$status_pkg" in
          doom)
            if [[ -x "$HOME/.config/emacs/bin/doom" ]]; then
              installed=$("$HOME/.config/emacs/bin/doom" version 2>/dev/null | head -1 | awk '{print $NF}')
              [[ -z $installed ]] && installed="installed"
              latest="(via doom upgrade)"
              status="OK"
            else
              installed=""
              latest="-"
              status="NOT INSTALLED"
            fi
            ;;
          poly)
            installed=$(poly_installed_version)
            local tag
            tag=$(poly_latest_tag)
            latest=${tag#v}
            if [[ -z $installed ]]; then
              status="NOT INSTALLED"
            elif [[ -n $latest && "$installed" != "$latest" ]]; then
              status="UPDATE AVAILABLE"
            else
              status="OK"
              [[ -z $latest ]] && latest="$installed"
            fi
            ;;
          bws)
            installed=$(bws_installed_version)
            latest="$BWS_TARGET_VERSION"
            if [[ -z $installed ]]; then
              status="NOT INSTALLED"
            elif [[ $installed != "$latest" ]]; then
              status="UPDATE AVAILABLE"
            else
              status="OK"
            fi
            ;;
          emacs-daemon)
            latest="-"
            if ! command -v systemctl >/dev/null 2>&1 || ! systemctl --user is-enabled emacs.service >/dev/null 2>&1; then
              installed=""
              status="NOT ENABLED"
            elif systemctl --user is-active emacs.service >/dev/null 2>&1; then
              installed="running"
              status="OK"
            else
              installed="enabled, not running"
              status="ACTION NEEDED (systemctl --user start emacs)"
            fi
            ;;
          keyd)
            if systemctl is-active --quiet keyd 2>/dev/null; then
              installed=$(pacman -Q keyd 2>/dev/null | awk '{print $2}')
              [[ -z $installed ]] && installed="running"
              latest="$installed"
              status="OK"
            elif pacman -Qq keyd >/dev/null 2>&1; then
              installed="installed, not running"
              latest="-"
              status="NOT ENABLED"
            else
              installed=""
              latest="-"
              status="NOT INSTALLED"
            fi
            ;;
        esac
        ;;
    esac

    printf "%-20s %-12s %-14s %-14s %s\n" "$name" "$method" "${installed:--}" "${latest:--}" "$status"
  done
  echo
}

# ---------------------------------------------------------------------------
# Decision support: "how would I install this?"
#
# Probes pacman (official/Omarchy repos), the AUR (via yay), and mise's
# registry for NAME and prints what it found, plus a suggested
# dev-stack-software.txt line using this precedence: pacman > mise > AUR >
# custom. Rationale: pacman is simplest and best-maintained; mise gives
# per-project version control for dev tools where that matters; AUR is
# community-maintained (more to go wrong, see step_aur_fragile above) and
# only preferred over custom because it's still less work than a bespoke
# install function. Read-only - never installs anything or edits the file
# for you.
# ---------------------------------------------------------------------------
check_availability() {
  local name="$1"
  local pac_hit="" aur_hit="" mise_hit=""

  echo "Checking pacman/Omarchy repos, the AUR, and mise for '$name'..."

  echo
  echo "-- pacman / Omarchy repos --"
  if pacman -Si "$name" >/dev/null 2>&1; then
    pac_hit="$name"
    pacman -Si "$name" 2>/dev/null | grep -E '^(Repository|Name|Version|Description)'
  else
    echo "No exact package named '$name'. Similarly-named packages:"
    pacman -Ss "$name" 2>/dev/null | head -10 || echo "  (none found)"
  fi

  echo
  echo "-- AUR (via yay) --"
  if ! command -v yay >/dev/null 2>&1; then
    echo "yay not on PATH - can't check the AUR here (it's installed as part of"
    echo "this script's own preflight, so this is only a concern before first run)."
  elif yay -Si "$name" >/dev/null 2>&1; then
    aur_hit="$name"
    yay -Si "$name" 2>/dev/null | grep -E '^(Repository|Name|Version|Description)'
  else
    echo "No exact AUR package named '$name'. Similarly-named packages:"
    yay -Ss "$name" 2>/dev/null | head -10 || echo "  (none found)"
  fi

  echo
  echo "-- mise registry --"
  local mise_backend
  mise_backend=$(mise registry "$name" 2>/dev/null | head -1)
  if [[ -n $mise_backend ]]; then
    mise_hit="$name"
    echo "'$name' -> $mise_backend"
  else
    echo "No exact registry shorthand '$name'. Fuzzy matches:"
    mise search "$name" 2>/dev/null | head -10 || echo "  (none found, or this mise version has no 'search' command)"
  fi

  echo
  echo "-- Suggestion --"
  if [[ -n $pac_hit ]]; then
    echo "Add to dev-stack-software.txt:"
    echo "  <Display Name>|pacman|$pac_hit|$pac_hit|"
  elif [[ -n $mise_hit ]]; then
    echo "Add to dev-stack-software.txt:"
    echo "  <Display Name>|mise|$mise_hit@latest|$mise_hit|"
  elif [[ -n $aur_hit ]]; then
    echo "Add to dev-stack-software.txt:"
    echo "  <Display Name>|aur|$aur_hit|$aur_hit|"
  else
    echo "No exact match anywhere. Check the fuzzy matches above for a"
    echo "different package name, or - if this is a real one-off (like Doom"
    echo "or Polylith) - it needs a dedicated function in install-dev-stack.sh"
    echo "(a 'custom' entry always does; see dev-stack-software.txt's header)."
  fi
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
case "${1:-}" in
  -s|--status|--table)
    print_status
    exit 0
    ;;
  --check)
    if [[ -z "${2:-}" ]]; then
      err "Usage: $0 --check <name>"
      exit 1
    fi
    check_availability "$2"
    exit 0
    ;;
  -h|--help)
    sed -n '25,33p' "$0"
    exit 0
    ;;
  "")
    run_install
    ;;
  *)
    err "Unknown option: $1 (try --status, --check <name>, or --help)"
    exit 1
    ;;
esac

echo
if ((${#FAILURES[@]} > 0)); then
  warn "Finished with ${#FAILURES[@]} issue(s):"
  for f in "${FAILURES[@]}"; do warn "  - $f"; done
  warn "Everything else installed cleanly. Re-run this script any time - it's safe to repeat."
else
  log "Done. Everything installed cleanly."
fi
echo "Run '$0 --status' any time for a version/upgrade table."
echo "Open a new terminal (or 'source ~/.bashrc') to pick up new PATH entries."
