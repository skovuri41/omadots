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
# chezmoi, the Bitwarden CLI (chezmoi's secret backend), and the GitHub CLI.
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
    emacs-daemon) enable_emacs_daemon ;;
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
        if [[ -z $installed ]]; then
          status="NOT INSTALLED"
          latest="-"
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
        [[ $method == aur-fragile && -f "$DEV_STACK_DIR/${status_pkg}.needs-manual-download" ]] &&
          status="ACTION NEEDED (manual download)"
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
