#!/usr/bin/env bash
# install-agent-extensions.sh
#
# Bootstrap AND ongoing-maintenance script for coding-agent skills and
# Claude Code plugins - the counterpart to install-dev-stack.sh, but for
# agent config instead of OS/dev-tool packages. Deliberately NOT chained
# into install-dev-stack.sh or the Omarchy post-update hook: this needs
# `claude` (and optionally `codex`) already installed AND authenticated via
# at least one interactive run first (Anthropic's own docs say a plugin
# marketplace's actual plugin content still needs Claude Code to reach the
# network to fetch it), which install-dev-stack.sh's unattended bootstrap
# can't assume. Run this by hand, after you've logged into whichever agent
# CLIs you use.
#
# Two independent sections, because they're genuinely different kinds of
# thing:
#
#   Skill repos (agent-skills.txt)   Third-party agentskills.io SKILL.md
#                       repos, installed for every agent listed in
#                       SKILL_AGENTS below via `npx skills`
#                       (github.com/vercel-labs/skills). See
#                       agent-skills.txt's own header for the registry
#                       format, and this script's own history (`git log`
#                       on this file) for why that replaced a hand-rolled
#                       git-clone implementation.
#
#   Claude Code plugins (no registry file - see below)
#                       Marketplace-distributed bundles of skills PLUS MCP
#                       servers/hooks/agents. Claude-specific, with no
#                       Codex equivalent today (Codex has no marketplace/
#                       plugin CLI at all, confirmed against its own docs)
#                       and no `npx skills` equivalent either (that tool
#                       installs SKILL.md skills, not marketplace-bundled
#                       MCP servers/hooks).
#
# Usage:
#   ./install-agent-extensions.sh              install/upgrade everything
#                                               registered (safe to re-run)
#   ./install-agent-extensions.sh --status     print what's registered vs.
#                                               actually installed, no changes
#   ./install-agent-extensions.sh -h           this help
#
# Design principles (same as install-dev-stack.sh):
#   - Open/closed: what to install lives in agent-skills.txt (skill repos)
#     or ~/.claude/settings.json (plugins - see below), never hardcoded
#     here.
#   - Failsafe: one entry failing must not stop the rest. Every step is
#     wrapped so failures are logged and collected into a summary at the
#     end, never a hard abort.
#   - Idempotent: safe to re-run. `npx skills add` and `claude plugin
#     marketplace add` are both confirmed-idempotent by their own
#     tools/docs, so this script doesn't pre-check before calling either.
#     `claude plugin install` is the one exception - see below.
#
# Claude Code plugins: declared in settings.json, not a registry file
# here (rewritten 2026-09-08, replacing claude-plugins.txt - see
# CHEZMOI-GUIDE.md for the full writeup of why). Anthropic's own docs
# describe exactly this as the recommended way to check plugin config
# into version control: declare `extraKnownMarketplaces` and
# `enabledPlugins` directly in settings.json
# (home/dot_claude/settings.json.tmpl in this repo, chezmoi-managed like
# everything else under ~/.claude). Two things confirmed against
# Anthropic's docs that shape this section:
#   1. `claude plugin marketplace add` on an already-registered name is
#      documented as a safe replace, not an error - so every declared
#      marketplace is (re-)added unconditionally below, no pre-check
#      needed.
#   2. Declaring `enabledPlugins: {"name@marketplace": true}` does NOT by
#      itself fetch/install the plugin's content - Claude Code still
#      needs `claude plugin install` run at least once. That command's
#      idempotency on an already-installed plugin is NOT reliably
#      documented (real open Claude Code GitHub issues show buggy
#      "already installed" detection), so - unlike marketplace add - this
#      script DOES check via `claude plugin list --json` before calling
#      it, same defensive style as before.
# Net effect: this script's plugin half is now a small reconciliation
# loop - read what settings.json declares, make sure the marketplace is
# registered, make sure each enabled plugin is actually installed -
# instead of maintaining a second, parallel list of the same information.
#
# Why `npx skills`, not a hand-rolled git clone, for the skill-repo half
# (rewritten 2026-09-08): the previous version cloned each repo itself
# into a cache dir and symlinked ~/.agents/skills/<name> at a registry-
# declared `subpath`, to handle repos where SKILL.md isn't at the repo
# root. That worked, but it never created the separate, Claude-specific
# ~/.claude/skills/<name> symlink hand-authored skills get (see
# CHEZMOI-GUIDE.md's "agent-agnostic skills" section) - so a skill
# installed this way was invisible to Claude Code entirely. Chasing that
# bug led to `npx skills` (github.com/vercel-labs/skills, MIT, actively
# maintained) - verified against its actual source: it auto-finds a
# nested SKILL.md up to 3 levels deep, installs into every requested
# agent's own native directory in one call (Claude Code included), and
# re-running `add` on an already-installed skill is a confirmed clean,
# safe overwrite. That made the hand-rolled cache/subpath/symlink code
# pure duplicated, worse-maintained logic - dropped in favor of shelling
# out. `git log` on this file has the old implementation if this tradeoff
# (an unpinned third-party npm package fetched at install time - Node/npx
# is already required by this dev stack, so not a new runtime dependency,
# just a new trust surface) ever stops being worth it.
#
# Which agents get each skill: SKILL_AGENTS below (currently Claude Code +
# Codex). Add/remove slugs there to change it for every agent-skills.txt
# entry at once - see `npx skills add --help`'s agent table for valid
# slugs (they're the CLI's own names, e.g. `claude-code` not `claude`).
#
# Known limitations, disclosed rather than hidden:
#   - No "check for a pending update without applying it" query exists in
#     `npx skills` (verified against its source - `list --json` reports
#     what's installed, not whether upstream has moved on). Re-running
#     this script is how you actually refresh a skill.
#   - `claude plugin list --json`'s schema was unconfirmed when this
#     section was first written (2026-09-08), and the first version of
#     plugin_installed() guessed wrong: it checked for `name`/
#     `marketplace`/`source` keys that don't exist. A real installed-plugin
#     entry (confirmed 2026-09-08 against actual `claude plugin list
#     --json` output) looks like:
#       {"id": "mattpocock-skills@mattpocock", "version": "1.2.3",
#        "scope": "user", "enabled": true, "installPath": "...",
#        "installedAt": "...", "lastUpdated": "..."}
#     i.e. the plugin+marketplace pair is the `id` field, already in
#     "plugin@marketplace" form - no separate name/marketplace fields at
#     all. plugin_installed() below matches on `id` directly and reports
#     the `enabled` flag too, so a plugin someone disabled by hand (via
#     `claude plugin disable`) shows as disabled rather than being
#     silently confused with "not installed".

set -uo pipefail

# ---------------------------------------------------------------------------
# Small helpers - identical style to install-dev-stack.sh
# ---------------------------------------------------------------------------
log()  { echo -e "\e[32m\n==> $*\e[0m"; }
warn() { echo -e "\e[33m$*\e[0m" >&2; }
err()  { echo -e "\e[31m$*\e[0m" >&2; }

FAILURES=()
fail() { FAILURES+=("$1"); warn "$1 - FAILED (continuing)"; }

# Agents every agent-skills.txt entry is installed for. Valid values are
# whatever `npx skills add --help` lists in its agent table (CLI slugs,
# not display names) - currently just these two are things you actually
# use day to day.
SKILL_AGENTS=(claude-code codex)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SKILLS_REGISTRY_FILE="${AGENT_SKILLS_REGISTRY_FILE:-$SCRIPT_DIR/agent-skills.txt}"
CLAUDE_SETTINGS_FILE="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"

require_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# agent-skills.txt registry
# ---------------------------------------------------------------------------
SKILLS_REGISTRY=()

# Generic N-field loader: reads $1 into the array named by $3 (via
# nameref), skipping blank lines/comments and warning (not failing) on a
# line whose '|'-count doesn't match $2. A missing file is a warning, not
# an error.
load_registry() {
  local file="$1" expected_fields="$2"
  local -n out_array="$3"
  out_array=()

  if [[ ! -f $file ]]; then
    warn "No registry at $file - skipping that section (this is fine if you don't use it)."
    return
  fi

  local lineno=0 line
  while IFS= read -r line || [[ -n $line ]]; do
    lineno=$((lineno + 1))
    [[ -z ${line// } ]] && continue
    [[ $line == \#* ]] && continue

    local field_count
    field_count=$(awk -F'|' '{print NF}' <<<"$line")
    if [[ $field_count -ne $expected_fields ]]; then
      warn "Skipping $file line $lineno - expected $expected_fields '|'-separated fields, found $field_count: $line"
      continue
    fi
    out_array+=("$line")
  done <"$file"
}

# agent-skills.txt is name|source|note - 3 fields.
load_registry "$SKILLS_REGISTRY_FILE" 3 SKILLS_REGISTRY

# ---------------------------------------------------------------------------
# Third-party agentskills.io skill repos, via `npx skills` (vercel-labs/skills)
# ---------------------------------------------------------------------------
# `--yes` (skills' own flag) skips its confirm-before-overwrite prompt;
# `npx --yes` (before the package name) skips npx's separate "install this
# package?" prompt on a machine that hasn't run it before - two different
# tools, two different flags, both needed for zero-prompt behavior
# (verified against vercel-labs/skills' source: no other prompt, telemetry
# or otherwise, fires independently of these).
install_skill_repo() {
  local name="$1" source="$2" desc="skill: $1"

  if npx --yes skills add "$source" --agent "${SKILL_AGENTS[@]}" --global --yes >/dev/null 2>&1; then
    log "$desc (installed/refreshed for ${SKILL_AGENTS[*]}, from $source)"
  else
    fail "$desc - 'npx skills add $source --agent ${SKILL_AGENTS[*]} --global --yes' failed - re-run that exact command by hand to see the real error"
  fi
}

run_skill_installs() {
  [[ ${#SKILLS_REGISTRY[@]} -eq 0 ]] && return
  if ! require_cmd npx; then
    fail "agent-skills section - 'npx' (Node.js) not found, skipping all skill-repo entries"
    return
  fi

  local entry name source
  for entry in "${SKILLS_REGISTRY[@]}"; do
    IFS='|' read -r name source _ <<<"$entry"
    install_skill_repo "$name" "$source"
  done
}

# ---------------------------------------------------------------------------
# Claude Code plugins - declared in settings.json, reconciled here
# ---------------------------------------------------------------------------
CLAUDE_MARKETPLACE_JSON=""
CLAUDE_PLUGIN_JSON=""

refresh_claude_json() {
  CLAUDE_MARKETPLACE_JSON="$(claude plugin marketplace list --json 2>/dev/null)"
  CLAUDE_PLUGIN_JSON="$(claude plugin list --json 2>/dev/null)"
}

# Prints "name|source" - one line per marketplace declared under
# extraKnownMarketplaces in settings.json. `source` is resolved to
# whatever `claude plugin marketplace add` itself takes (a repo slug, a
# git/http URL, or a local path) from whichever of the source block's
# shapes is present.
read_declared_marketplaces() {
  CLAUDE_SETTINGS_PATH="$CLAUDE_SETTINGS_FILE" python3 -c '
import json, os, sys
path = os.environ["CLAUDE_SETTINGS_PATH"]
try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    sys.exit(0)
except Exception as e:
    print(f"{e}", file=sys.stderr)
    sys.exit(1)
for name, cfg in (data.get("extraKnownMarketplaces") or {}).items():
    src = (cfg or {}).get("source") or {}
    stype = src.get("source")
    if stype == "github":
        resolved = src.get("repo", "")
    elif stype in ("git", "url"):
        resolved = src.get("url", "")
    elif stype in ("directory", "path"):
        resolved = src.get("path", "")
    else:
        resolved = ""
    if name and resolved:
        print(f"{name}|{resolved}")
'
}

# Prints "plugin|marketplace" - one line per `"plugin@marketplace": true`
# entry under enabledPlugins in settings.json. Silently yields nothing on
# a missing/unparseable file - read_declared_marketplaces already reports
# the parse error once, no need to duplicate it.
read_enabled_plugins() {
  CLAUDE_SETTINGS_PATH="$CLAUDE_SETTINGS_FILE" python3 -c '
import json, os, sys
path = os.environ["CLAUDE_SETTINGS_PATH"]
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)
for key, val in (data.get("enabledPlugins") or {}).items():
    if val is True and "@" in key:
        plugin, marketplace = key.split("@", 1)
        print(f"{plugin}|{marketplace}")
' 2>/dev/null
}

marketplace_installed() {
  CHECK_NAME="$1" python3 -c '
import json, os, sys
name = os.environ["CHECK_NAME"]
try:
    data = json.loads(sys.stdin.read() or "[]")
except Exception:
    sys.exit(1)
names = [m.get("name") for m in data] if isinstance(data, list) else []
sys.exit(0 if name in names else 1)
' <<<"$CLAUDE_MARKETPLACE_JSON"
}

# $1 = plugin name, $2 = marketplace name. Prints one of "OK",
# "DISABLED", or "NOT INSTALLED" to stdout and exits 0 if installed
# (OK or DISABLED), 1 if not. Matches on the `id` field
# ("plugin@marketplace") - confirmed 2026-09-08 against real `claude
# plugin list --json` output; see the header comment's "Known
# limitations" note for why this replaced an earlier, wrong guess at the
# schema (name/marketplace/source keys that don't actually exist).
plugin_status() {
  CHECK_ID="${1}@${2}" python3 -c '
import json, os, sys
target = os.environ["CHECK_ID"]
try:
    data = json.loads(sys.stdin.read() or "[]")
except Exception:
    print("NOT INSTALLED")
    sys.exit(1)
for p in (data if isinstance(data, list) else []):
    if p.get("id") == target:
        print("OK" if p.get("enabled", True) else "DISABLED")
        sys.exit(0)
print("NOT INSTALLED")
sys.exit(1)
' <<<"$CLAUDE_PLUGIN_JSON"
}

# Just the "make sure it's actually installed" half - marketplace
# registration is handled unconditionally in run_plugin_installs below,
# since that part IS confirmed idempotent and doesn't need this same
# check-first treatment.
ensure_plugin_installed() {
  local plugin_name="$1" mp_name="$2"
  local desc="plugin: $plugin_name@$mp_name"
  local status

  status="$(plugin_status "$plugin_name" "$mp_name")"
  if [[ $status == "OK" ]]; then
    log "$desc (already installed)"
    return
  elif [[ $status == "DISABLED" ]]; then
    log "$desc (installed but disabled - run 'claude plugin enable ${plugin_name}@${mp_name}' if you want it back on; not doing that automatically here)"
    return
  fi

  if claude plugin install "${plugin_name}@${mp_name}" --scope user --yes >/dev/null 2>&1; then
    log "$desc (installed)"
  else
    fail "$desc - install failed"
  fi
}

run_plugin_installs() {
  if ! require_cmd claude; then
    fail "claude-plugins section - 'claude' not found on PATH, skipping"
    return
  fi
  if ! require_cmd python3; then
    fail "claude-plugins section - 'python3' not found, skipping (needed to read $CLAUDE_SETTINGS_FILE and parse 'claude plugin ... --json' safely)"
    return
  fi
  if [[ ! -f $CLAUDE_SETTINGS_FILE ]]; then
    warn "claude-plugins section - $CLAUDE_SETTINGS_FILE doesn't exist yet (run 'chezmoi apply' first if you're expecting one) - skipping"
    return
  fi

  local mp_lines enabled_lines parse_err
  parse_err="$(read_declared_marketplaces 2>&1 >/dev/null)"
  if [[ -n $parse_err ]]; then
    fail "claude-plugins section - couldn't parse $CLAUDE_SETTINGS_FILE as JSON: $parse_err"
    return
  fi
  mp_lines="$(read_declared_marketplaces 2>/dev/null)"
  enabled_lines="$(read_enabled_plugins)"

  if [[ -z $mp_lines && -z $enabled_lines ]]; then
    return
  fi

  # Register every declared marketplace unconditionally - confirmed
  # idempotent (re-adding the same name replaces it, no error) by
  # Anthropic's own docs, so no pre-check needed here, unlike the plugin
  # install step below.
  if [[ -n $mp_lines ]]; then
    local mp_name mp_source
    while IFS='|' read -r mp_name mp_source; do
      [[ -z $mp_name ]] && continue
      if claude plugin marketplace add "$mp_source" >/dev/null 2>&1; then
        log "marketplace: $mp_name (registered from $mp_source)"
      else
        fail "marketplace: $mp_name - add failed: $mp_source"
      fi
    done <<<"$mp_lines"
  fi

  [[ -z $enabled_lines ]] && return

  refresh_claude_json
  local plugin_name mp_name
  while IFS='|' read -r plugin_name mp_name; do
    [[ -z $plugin_name ]] && continue
    ensure_plugin_installed "$plugin_name" "$mp_name"
  done <<<"$enabled_lines"
}

# ---------------------------------------------------------------------------
# Status table
# ---------------------------------------------------------------------------
skills_list_json() {
  # --global is required - `list`/`ls` defaults to PROJECT scope (i.e. the
  # current directory), and every install this script does is `--global`.
  # Confirmed by testing: plain `npx skills list --json` prints `[]` right
  # after a successful global install; `--global` is what actually shows it.
  npx --yes skills list --global --json 2>/dev/null
}

# $1 = registered skill name. Prints "OK" if `npx skills list --global
# --json` shows an entry for it at all, "NOT INSTALLED" otherwise. Not
# checking per-agent coverage here even though SKILL_AGENTS names more
# than one - confirmed by testing that whichever agent's native directory
# IS the tool's own "universal"/canonical location (Codex, in every
# install observed) never appears in the `agents` array at all, only
# agents that got a separate symlink (Claude Code) do. So "agents doesn't
# list codex" is the NORMAL, fully-installed state, not a partial one -
# no reliable way from this JSON alone to tell that apart from "codex
# genuinely missing" if that behavior ever changes. See the header
# comment's "Known limitations" note - this also can't tell you if an
# installed skill is stale.
skill_status() {
  CHECK_NAME="$1" python3 -c '
import json, os, sys
name = os.environ["CHECK_NAME"]
try:
    data = json.loads(sys.stdin.read() or "[]")
except Exception:
    print("NOT INSTALLED")
    sys.exit(0)
found = any(entry.get("name") == name for entry in (data if isinstance(data, list) else []))
print("OK" if found else "NOT INSTALLED")
' <<<"$SKILLS_LIST_JSON_CACHE"
}

print_status() {
  if [[ ${#SKILLS_REGISTRY[@]} -gt 0 ]]; then
    echo "Third-party skills (via npx skills, target agents: ${SKILL_AGENTS[*]}):"
    printf "%-24s %-14s %s\n" "NAME" "STATUS" "SOURCE"
    printf '%s\n' "----------------------------------------------------------------------"
    if ! require_cmd npx || ! require_cmd python3; then
      warn "'npx' and/or 'python3' not found - can't check installed state, showing registry only."
      local entry name source
      for entry in "${SKILLS_REGISTRY[@]}"; do
        IFS='|' read -r name source _ <<<"$entry"
        printf "%-24s %-14s %s\n" "$name" "UNKNOWN" "$source"
      done
    else
      SKILLS_LIST_JSON_CACHE="$(skills_list_json)"
      local entry name source status
      for entry in "${SKILLS_REGISTRY[@]}"; do
        IFS='|' read -r name source _ <<<"$entry"
        status="$(skill_status "$name")"
        printf "%-24s %-14s %s\n" "$name" "$status" "$source"
      done
    fi
    echo
  fi

  echo "Claude Code plugins (declared in $CLAUDE_SETTINGS_FILE):"
  if ! require_cmd claude || ! require_cmd python3; then
    warn "'claude' and/or 'python3' not found - can't check installed state."
  elif [[ ! -f $CLAUDE_SETTINGS_FILE ]]; then
    warn "$CLAUDE_SETTINGS_FILE doesn't exist yet."
  else
    local mp_lines enabled_lines
    mp_lines="$(read_declared_marketplaces 2>/dev/null)"
    enabled_lines="$(read_enabled_plugins)"
    if [[ -z $mp_lines && -z $enabled_lines ]]; then
      echo "(nothing declared - see settings.json.tmpl's extraKnownMarketplaces/enabledPlugins)"
    else
      printf "%-24s %-20s %-14s %s\n" "PLUGIN" "MARKETPLACE" "STATUS" "SOURCE"
      printf '%s\n' "----------------------------------------------------------------------"
      refresh_claude_json
      local plugin_name mp_name mp_source status
      while IFS='|' read -r plugin_name mp_name; do
        [[ -z $plugin_name ]] && continue
        mp_source="$(grep "^${mp_name}|" <<<"$mp_lines" | cut -d'|' -f2-)"
        if ! marketplace_installed "$mp_name"; then
          status="MARKETPLACE MISSING"
        else
          status="$(plugin_status "$plugin_name" "$mp_name")"
        fi
        printf "%-24s %-20s %-14s %s\n" "$plugin_name" "$mp_name" "$status" "${mp_source:-?}"
      done <<<"$enabled_lines"
    fi
  fi
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
  -h|--help)
    sed -n '1,42p' "$0"
    exit 0
    ;;
  "")
    run_skill_installs
    run_plugin_installs
    ;;
  *)
    err "Unknown option: $1 (try --status or --help)"
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
