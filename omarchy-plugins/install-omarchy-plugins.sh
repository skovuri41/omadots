#!/usr/bin/env bash
# install-omarchy-plugins.sh
#
# Install/track/remove third-party Omarchy 4 ("Quattro") shell plugins -
# Quickshell bar widgets/panels distributed via Omarchy's own `omarchy
# plugin` CLI (github.com/basecamp/omarchy, docs at
# omarchy.org/manual/shell-plugins/). This is a DIFFERENT thing from
# agent-extensions/install-agent-extensions.sh next door: that script
# manages coding-agent (Claude Code/Codex) skills and plugins; this one
# manages Omarchy desktop-shell plugins. Different CLI (`omarchy` vs.
# `claude`/`npx skills`), different registry, different install
# directory (~/.config/omarchy/plugins/<id>/, not
# ~/.claude/plugins/... or ~/.agents/skills/...) - kept as two separate
# scripts/registries rather than one that branches on plugin "kind",
# matching this repo's existing philosophy of decoupled, single-purpose
# pieces (see README.md's top table).
#
# Usage:
#   ./install-omarchy-plugins.sh                 install/enable/position
#                                                 everything in
#                                                 omarchy-plugins.toml
#                                                 (safe to re-run)
#   ./install-omarchy-plugins.sh --status         what's registered vs.
#                                                 actually installed, no
#                                                 changes
#   ./install-omarchy-plugins.sh --remove <id>    disable + remove one
#                                                 plugin by id (does NOT
#                                                 touch the registry file
#                                                 or delete any state/
#                                                 cache directory the
#                                                 plugin itself created -
#                                                 see "Removal is
#                                                 deliberately shallow"
#                                                 below)
#   ./install-omarchy-plugins.sh -h               this help
#
# What "installing" a plugin here actually does, verified against each
# plugin's own README (WebFetch, 2026-09-10) rather than assumed from the
# id-naming convention alone:
#   omarchy plugin add <source> --enable --yes    clone + register + turn on
#   omarchy bar move <id> --section <section>     position it, if the
#                                                  registry declares one
#                                                  (some plugins, like
#                                                  notification-center,
#                                                  document their own
#                                                  preferred spot and
#                                                  don't need this)
#
# The `--yes` matters and was missing from this script's first version
# (fixed 2026-09-10, found from a real failure on the user's machine -
# see CHEZMOI-GUIDE.md): `omarchy plugin add` shows a mandatory safety
# warning before cloning ("plugins run as unsandboxed code inside your
# long-lived shell process") and waits on stdin for a yes/no - documented
# in Omarchy's shell/README.md (a different, more technical doc than the
# public manual page, which omits this flag entirely - triangulated
# across three separate fetches before trusting it, since the first
# attempt at this claim didn't hold up under a literal-text check) as
# "Pass `--yes` to skip every prompt - this is the path for scripts and
# AI agents". Without it, this script's own `>/dev/null 2>&1` redirect
# was also hiding the prompt text, so a run just blocked/failed silently
# instead of visibly asking anything - which is exactly why running the
# same command by hand prompted for permission while the script didn't
# appear to. `enable`/`disable`/`remove` don't show `--yes` in any
# documented example (they take the plugin id as their one required
# argument and, per the same doc, "[commands are] fully non-interactive
# when given arguments") - left as-is below; flag it if one of those
# ever blocks too.
#
# Removal is deliberately shallow: `--remove <id>` runs
#   omarchy plugin disable <id> ; omarchy plugin remove <id>
# and stops there. It does NOT delete any state/cache directory a plugin
# created on its own (e.g. notification-center's own README says it
# keeps a notification archive at ~/.local/state/omarchy-notification-center
# even after `plugin remove`, "by design", until you `rm -rf` it
# yourself). This script won't guess which of those you want to keep -
# it prints a one-line reminder to check for one instead of deleting
# anything.
#
# Design principles (same as install-dev-stack.sh /
# install-agent-extensions.sh):
#   - Open/closed: what to install lives in omarchy-plugins.toml, never
#     hardcoded here.
#   - Failsafe: one entry failing (missing dep, add/enable/move failure)
#     doesn't stop the rest; failures collect into a summary at the end.
#   - Idempotent-as-far-as-verified: `omarchy plugin add` on an
#     already-added id is NOT documented either way (checked the manual
#     directly - it's silent on this), so this script checks
#     `omarchy plugin list --json` first and only calls `add` for an id
#     that isn't already known, same defensive style
#     install-agent-extensions.sh uses for `claude plugin install`.
#   - Registry format: omarchy-plugins.toml is read via `yq` (mikefarah/yq,
#     the Go one) + python3, same TOML+yq approach, `deps` field upgrade
#     (comma-separated string -> real TOML array), and the same
#     "malformed file fails the whole load, not just one bad entry"
#     tradeoff as the other two install-*.sh scripts - see
#     install-dev-stack.sh's header and CHEZMOI-GUIDE.md's "Registry
#     files moved to TOML" section for the full comparison/rationale.
#     `git log` on this file has the earlier pipe-delimited
#     omarchy-plugins.txt format if useful.
#
# Known limitation, disclosed up front rather than discovered the hard
# way (again - see install-agent-extensions.sh's own history with
# `claude plugin list --json` for exactly this class of bug): the exact
# field names in `omarchy plugin list --json`'s output are NOT confirmed.
# The manual page confirms the flag exists and that plain-text `list`
# shows "its id, whether it's enabled, whether it's first-party or
# third-party, its kinds, and its display name" - but not the JSON key
# names for any of that. plugin_state() below guesses `id` for the
# identifier (near-certain - every `omarchy plugin`/`omarchy bar` command
# addresses plugins by an `id` string, so the list output almost has to
# echo it back the same way) and tries a short list of plausible keys for
# the enabled flag (`enabled`, then `isEnabled`) since that part is
# genuinely unconfirmed. If your real output uses neither, plugin_state()
# will under-detect and this script will just re-run `add`/`enable` on an
# already-installed plugin - annoying (extra network fetch) but not
# damaging, same "probably fine, not proven" tradeoff documented in
# install-agent-extensions.sh. Run `omarchy plugin list --json` for real
# once you have a plugin installed and compare against what --status
# reports; mismatch = tell me the real field names and this gets a
# one-line fix, same as the claude plugin_status() bug did.

set -uo pipefail

# ---------------------------------------------------------------------------
# Small helpers - identical style to the other two install-*.sh scripts
# ---------------------------------------------------------------------------
log()  { echo -e "\e[32m\n==> $*\e[0m"; }
warn() { echo -e "\e[33m$*\e[0m" >&2; }
err()  { echo -e "\e[31m$*\e[0m" >&2; }

FAILURES=()
fail() { FAILURES+=("$1"); warn "$1 - FAILED (continuing)"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PLUGINS_REGISTRY_FILE="${OMARCHY_PLUGINS_REGISTRY_FILE:-$SCRIPT_DIR/omarchy-plugins.toml}"

require_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# omarchy-plugins.toml registry - open/closed: the actual plugin list
# lives in $PLUGINS_REGISTRY_FILE, not here. See that file's header
# comment for the [[plugin]] table format. Reading it uses the exact same
# yq(mikefarah)->JSON->python3(NUL/\x1f-delimited)->process-substitution
# pattern as install-dev-stack.sh's load_registry() - see that script's
# header comment for the full rationale (JSON over yq's own `-o tsv` to
# avoid its CSV-style quote-doubling on fields containing `"`; process
# substitution over a `$(...)` variable capture because bash variables
# can't hold NUL bytes). The one difference from the other two scripts:
# `deps` is a real TOML array here, joined with a comma into this
# script's existing internal "comma-separated deps" representation at
# extraction time - check_deps() below is unchanged and still just splits
# on commas, so this is a registry-format upgrade with zero change to any
# consumer's logic. A missing registry file is empty, not fatal.
# ---------------------------------------------------------------------------
PLUGINS_REGISTRY=()

# Checks for mikefarah/yq specifically, not just "a binary named yq" -
# see install-dev-stack.sh's require_yq() for the full kislyuk/yq
# naming-collision writeup (confirmed live in this repo's own dev sandbox).
require_yq() {
  if ! command -v yq >/dev/null 2>&1; then
    err "'yq' not found on \$PATH - needed to read $PLUGINS_REGISTRY_FILE (TOML)."
    err "Install it with: sudo pacman -S go-yq"
    err "(NOT 'yq' from the AUR or pip - that's a different, unrelated tool. See CHEZMOI-GUIDE.md.)"
    return 1
  fi
  local version_line
  version_line="$(yq --version 2>&1)"
  if [[ $version_line != *mikefarah* ]]; then
    err "The 'yq' on your \$PATH doesn't look like mikefarah/yq (got: $version_line)."
    err "Install the right one with: sudo pacman -S go-yq"
    return 1
  fi
  return 0
}

load_registry() {
  if [[ ! -f $PLUGINS_REGISTRY_FILE ]]; then
    warn "No registry at $PLUGINS_REGISTRY_FILE - skipping (this is fine if you don't use this script)."
    return
  fi
  require_yq || exit 1
  if ! command -v python3 >/dev/null 2>&1; then
    err "'python3' not found - needed alongside yq to safely read $PLUGINS_REGISTRY_FILE."
    exit 1
  fi

  local yq_err_file json
  yq_err_file="$(mktemp)"
  json="$(yq -p toml -o json "$PLUGINS_REGISTRY_FILE" 2>"$yq_err_file")"
  if [[ $? -ne 0 ]]; then
    err "Failed to parse $PLUGINS_REGISTRY_FILE as TOML:"
    err "$(cat "$yq_err_file")"
    rm -f "$yq_err_file"
    exit 1
  fi
  rm -f "$yq_err_file"

  while IFS= read -r -d $'\0' record; do
    PLUGINS_REGISTRY+=("$record")
  done < <(python3 -c '
import json, sys
data = json.loads(sys.stdin.read() or "{}")
for e in data.get("plugin", []):
    deps = ",".join(e.get("deps") or [])
    fields = [e.get("id", ""), e.get("source", ""), e.get("section", ""), deps, e.get("note", "")]
    sys.stdout.write("\x1f".join(fields) + "\x00")
' <<<"$json")
}

load_registry

# ---------------------------------------------------------------------------
# omarchy plugin list --json state - see the header comment's "Known
# limitation" note before trusting the field names below blindly.
# ---------------------------------------------------------------------------
OMARCHY_PLUGIN_JSON=""

refresh_omarchy_json() {
  OMARCHY_PLUGIN_JSON="$(omarchy plugin list --json 2>/dev/null)"
}

# $1 = plugin id. Prints "OK" (installed+enabled), "DISABLED"
# (installed, not enabled), or "NOT INSTALLED" to stdout; exits 0 for the
# first two, 1 for the last - mirrors install-agent-extensions.sh's
# plugin_status() shape exactly, including the "installed but disabled
# doesn't get silently treated as not-installed" fix that script needed.
plugin_state() {
  CHECK_ID="$1" python3 -c '
import json, os, sys
target = os.environ["CHECK_ID"]
try:
    data = json.loads(sys.stdin.read() or "[]")
except Exception:
    print("NOT INSTALLED")
    sys.exit(1)
items = data if isinstance(data, list) else data.get("plugins", []) if isinstance(data, dict) else []
for p in items:
    if not isinstance(p, dict):
        continue
    if p.get("id") == target:
        enabled = p.get("enabled", p.get("isEnabled", True))
        print("OK" if enabled else "DISABLED")
        sys.exit(0)
print("NOT INSTALLED")
sys.exit(1)
' <<<"$OMARCHY_PLUGIN_JSON"
}

# $1 = comma-separated command names (or "-" for none). Warns (doesn't
# fail) for each one missing from $PATH - the plugin still gets
# installed either way, since a missing runtime dep is the user's to fix
# and shouldn't block the rest of the registry.
check_deps() {
  local deps_csv="$1" id="$2"
  [[ -z $deps_csv || $deps_csv == "-" ]] && return
  local dep dep_list
  IFS=',' read -ra dep_list <<<"$deps_csv"
  for dep in "${dep_list[@]}"; do
    require_cmd "$dep" || warn "  $id declares a dependency on '$dep', not found on \$PATH - the plugin will install but may not work until that's available"
  done
}

# ---------------------------------------------------------------------------
# Install / reconcile
# ---------------------------------------------------------------------------
ensure_plugin_installed() {
  local id="$1" source="$2" section="$3" deps="$4"
  local desc="omarchy plugin: $id"

  check_deps "$deps" "$id"

  local state cmd_err
  state="$(plugin_state "$id")"

  if [[ $state == "NOT INSTALLED" ]]; then
    # --yes is required, not optional - see the header comment above for
    # why: without it, `add` blocks on an unsandboxed-code safety prompt
    # this script has no way to answer.
    if cmd_err="$(omarchy plugin add "$source" --enable --yes 2>&1 >/dev/null)"; then
      log "$desc (installed + enabled, from $source)"
      refresh_omarchy_json
    else
      fail "$desc - 'omarchy plugin add $source --enable --yes' failed: ${cmd_err:-no error output captured}"
      return
    fi
  elif [[ $state == "DISABLED" ]]; then
    if cmd_err="$(omarchy plugin enable "$id" 2>&1 >/dev/null)"; then
      log "$desc (was installed but disabled - re-enabled)"
      refresh_omarchy_json
    else
      fail "$desc - already installed but 'omarchy plugin enable $id' failed: ${cmd_err:-no error output captured}"
    fi
  else
    log "$desc (already installed and enabled)"
  fi

  if [[ -n $section && $section != "-" ]]; then
    if cmd_err="$(omarchy bar move "$id" --section "$section" 2>&1 >/dev/null)"; then
      log "$desc (positioned in bar section: $section)"
    else
      fail "$desc - 'omarchy bar move $id --section $section' failed: ${cmd_err:-no error output captured}"
    fi
  fi
}

run_plugin_installs() {
  [[ ${#PLUGINS_REGISTRY[@]} -eq 0 ]] && return
  if ! require_cmd omarchy; then
    fail "omarchy-plugins section - 'omarchy' not found on \$PATH, skipping (this script only makes sense on an actual Omarchy install)"
    return
  fi
  if ! require_cmd python3; then
    fail "omarchy-plugins section - 'python3' not found, skipping (needed to parse 'omarchy plugin list --json' safely)"
    return
  fi

  refresh_omarchy_json
  local entry id source section deps
  for entry in "${PLUGINS_REGISTRY[@]}"; do
    IFS=$'\x1f' read -r id source section deps _ <<<"$entry"
    ensure_plugin_installed "$id" "$source" "$section" "$deps"
  done
}

# ---------------------------------------------------------------------------
# Removal - explicit, one id at a time, never automatic. See the header
# comment's "Removal is deliberately shallow" note for why this doesn't
# touch state/cache directories.
# ---------------------------------------------------------------------------
remove_plugin() {
  local id="$1"

  if [[ -z $id ]]; then
    err "--remove needs a plugin id, e.g. --remove jankeesvw.herdr"
    err "Registered ids: $(printf '%s\n' "${PLUGINS_REGISTRY[@]}" | cut -d$'\x1f' -f1 | paste -sd, -)"
    exit 1
  fi
  if ! require_cmd omarchy; then
    err "'omarchy' not found on \$PATH - can't remove anything"
    exit 1
  fi

  local cmd_err
  omarchy plugin disable "$id" >/dev/null 2>&1
  if cmd_err="$(omarchy plugin remove "$id" 2>&1 >/dev/null)"; then
    log "omarchy plugin: $id (disabled + removed)"
    warn "Note: this does NOT delete any state/cache directory the plugin created on its own (e.g. a notification archive, a config cache) - check for one under ~/.local/state/ or ~/.cache/ if you want a full purge, and remove that by hand."
    warn "This also doesn't touch omarchy-plugins.toml - if you don't want it reinstalled on the next plain run, delete its [[plugin]] entry from that file too."
  else
    err "omarchy plugin: $id - 'omarchy plugin remove $id' failed: ${cmd_err:-no error output captured} (already removed? wrong id? run --status to check)"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Status table
# ---------------------------------------------------------------------------
print_status() {
  echo "Omarchy shell plugins (declared in $PLUGINS_REGISTRY_FILE):"
  if [[ ${#PLUGINS_REGISTRY[@]} -eq 0 ]]; then
    echo "(nothing registered)"
    return
  fi
  if ! require_cmd omarchy || ! require_cmd python3; then
    warn "'omarchy' and/or 'python3' not found - can't check installed state, showing registry only."
    local entry id source
    for entry in "${PLUGINS_REGISTRY[@]}"; do
      IFS=$'\x1f' read -r id source _ <<<"$entry"
      printf "%-32s %-14s %s\n" "$id" "UNKNOWN" "$source"
    done
    return
  fi

  refresh_omarchy_json
  printf "%-32s %-14s %-8s %s\n" "ID" "STATUS" "SECTION" "SOURCE"
  printf '%s\n' "--------------------------------------------------------------------------------------"
  local entry id source section deps status
  for entry in "${PLUGINS_REGISTRY[@]}"; do
    IFS=$'\x1f' read -r id source section deps _ <<<"$entry"
    status="$(plugin_state "$id")"
    printf "%-32s %-14s %-8s %s\n" "$id" "$status" "${section:--}" "$source"
  done
  echo
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
case "${1:-}" in
  -s|--status|--table)
    print_status
    exit 0
    ;;
  --remove)
    remove_plugin "${2:-}"
    exit 0
    ;;
  -h|--help)
    sed -n '1,70p' "$0"
    exit 0
    ;;
  "")
    run_plugin_installs
    ;;
  *)
    err "Unknown option: $1 (try --status, --remove <id>, or --help)"
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
echo "Run '$0 --status' any time to see what's registered vs. actually installed."
