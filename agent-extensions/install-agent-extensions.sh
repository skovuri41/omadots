#!/usr/bin/env bash
# install-agent-extensions.sh
#
# Bootstrap AND ongoing-maintenance script for coding-agent skills and
# Claude Code plugins - the counterpart to install-dev-stack.sh, but for
# agent config instead of OS/dev-tool packages. Deliberately NOT chained
# into install-dev-stack.sh or the Omarchy post-update hook: this needs
# `claude` (and optionally `codex`) already installed AND authenticated via
# at least one interactive run first (Anthropic's own docs say the official
# plugin marketplace only auto-registers on Claude Code's first interactive
# start), which install-dev-stack.sh's unattended bootstrap can't assume.
# Run this by hand, after you've logged into whichever agent CLIs you use.
#
# What it installs is split across two registries, next to this script,
# because they are genuinely different kinds of thing - see
# agent-skills.txt and claude-plugins.txt's own header comments for why:
#
#   agent-skills.txt    Plain git-repo skills (the open agentskills.io
#                       SKILL.md format), cloned into ~/.agents/skills/<name>.
#                       Agent-agnostic by construction: Claude reads this
#                       same tree via the ~/.claude/skills symlink chezmoi
#                       manages (see home/dot_claude/symlink_skills), Codex
#                       reads ~/.agents/skills natively, and any future
#                       agentskills.io-compliant tool would too - no
#                       per-tool branching needed for this registry.
#
#   claude-plugins.txt  Claude Code plugins - bundles of skills PLUS MCP
#                       servers/hooks/agents, discovered through a
#                       marketplace. This is a Claude-specific concept with
#                       no Codex equivalent today (Codex has no
#                       marketplace/plugin CLI at all, confirmed against
#                       its own docs - just plain skill folders, which is
#                       exactly what the other registry covers). If a
#                       future agent grows an equivalent, it gets its own
#                       sibling registry + dispatch function here, the same
#                       way dev-stack-software.txt grew new `method` values
#                       over time without restructuring install-dev-stack.sh.
#
# Usage:
#   ./install-agent-extensions.sh              install/upgrade everything
#                                               registered (safe to re-run)
#   ./install-agent-extensions.sh --status     print what's registered vs.
#                                               actually installed, no changes
#   ./install-agent-extensions.sh -h           this help
#
# Design principles (same as install-dev-stack.sh):
#   - Open/closed: what to install lives in the two .txt registries next to
#     this script, never hardcoded here. Adding a skill repo or a plugin is
#     a one-line text edit.
#   - Failsafe: one entry failing must not stop the rest. Every step is
#     wrapped so failures are logged and collected into a summary at the
#     end, never a hard abort.
#   - Idempotent: safe to re-run. Skill repos are git-pulled instead of
#     re-cloned if already present; marketplaces/plugins are checked via
#     `claude plugin ... --json` before adding/installing anything.
#   - Each registry's preconditions (git; claude + python3) are checked
#     independently - missing one degrades that section only, it doesn't
#     abort the whole run. (python3 is used for JSON parsing rather than
#     assuming jq is installed - see require_cmd calls below.)
#
# Known limitation, disclosed rather than hidden: a skill repo's `ref`
# field (branch/tag) is only applied at first clone. Re-runs just
# fast-forward-pull whatever branch is currently checked out - this script
# does not force-switch branches on an existing checkout, so if you change
# `ref` for an already-cloned entry, switch it by hand once
# (`git -C ~/.agents/skills/<name> checkout <new-ref>`) and re-run.
#
# Also disclosed: `claude plugin list --json`'s exact field for "which
# marketplace this plugin came from" isn't documented anywhere I could
# verify (checked Anthropic's plugins-reference page directly) - this
# script checks both a `marketplace` and a `source` key defensively. If
# neither matches your installed CLI version's actual output,
# plugin_installed() will under-detect and this script will just re-run
# `claude plugin install`, which the docs confirm is safe to repeat (a
# marketplace add "replaces" rather than erroring; re-installing a plugin
# is expected to be a no-op, though that exact behavior isn't spelled out
# either - if it turns out not to be, `claude plugin list` afterward will
# show you directly).

set -uo pipefail

# ---------------------------------------------------------------------------
# Small helpers - identical style to install-dev-stack.sh
# ---------------------------------------------------------------------------
log()  { echo -e "\e[32m\n==> $*\e[0m"; }
warn() { echo -e "\e[33m$*\e[0m" >&2; }
err()  { echo -e "\e[31m$*\e[0m" >&2; }

FAILURES=()
fail() { FAILURES+=("$1"); warn "$1 - FAILED (continuing)"; }

AGENT_SKILLS_DIR="$HOME/.agents/skills"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SKILLS_REGISTRY_FILE="${AGENT_SKILLS_REGISTRY_FILE:-$SCRIPT_DIR/agent-skills.txt}"
PLUGINS_REGISTRY_FILE="${CLAUDE_PLUGINS_REGISTRY_FILE:-$SCRIPT_DIR/claude-plugins.txt}"

require_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# Registries
# ---------------------------------------------------------------------------
SKILLS_REGISTRY=()
PLUGINS_REGISTRY=()

# Generic N-field loader: reads $1 into the array named by $3 (via
# nameref), skipping blank lines/comments and warning (not failing) on a
# line whose '|'-count doesn't match $2. A missing file is a warning, not
# an error - unlike install-dev-stack.sh's single required registry, either
# of these two is allowed to be empty/absent (e.g. you may only ever use
# Claude, never Codex-style skill repos, or vice versa).
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

load_registry "$SKILLS_REGISTRY_FILE" 4 SKILLS_REGISTRY
load_registry "$PLUGINS_REGISTRY_FILE" 4 PLUGINS_REGISTRY

if [[ ${#SKILLS_REGISTRY[@]} -eq 0 && ${#PLUGINS_REGISTRY[@]} -eq 0 ]]; then
  warn "Both registries are empty - nothing to do. Add a line to $SKILLS_REGISTRY_FILE"
  warn "or $PLUGINS_REGISTRY_FILE (see their header comments) and re-run."
  exit 0
fi

# ---------------------------------------------------------------------------
# Agent-agnostic skill repos -> ~/.agents/skills/<name>
# ---------------------------------------------------------------------------
install_skill_repo() {
  local name="$1" source="$2" ref="$3" desc="skill: $1"
  local target="$AGENT_SKILLS_DIR/$name"

  if [[ -d "$target/.git" ]]; then
    if git -C "$target" pull --quiet --ff-only >/dev/null 2>&1; then
      log "$desc (updated)"
    else
      fail "$desc - update failed (uncommitted local changes, or diverged history? check $target by hand)"
    fi
    return
  fi

  mkdir -p "$AGENT_SKILLS_DIR"
  local clone_args=(--quiet)
  [[ -n $ref ]] && clone_args+=(--branch "$ref")
  if git clone "${clone_args[@]}" "$source" "$target" >/dev/null 2>&1; then
    log "$desc (cloned from $source${ref:+ @ $ref})"
  else
    fail "$desc - clone failed: $source${ref:+ (branch/tag '$ref')}"
  fi
}

run_skill_installs() {
  [[ ${#SKILLS_REGISTRY[@]} -eq 0 ]] && return
  if ! require_cmd git; then
    fail "agent-skills section - 'git' not found, skipping all skill-repo entries"
    return
  fi

  local entry name source ref
  for entry in "${SKILLS_REGISTRY[@]}"; do
    IFS='|' read -r name source ref _ <<<"$entry"
    install_skill_repo "$name" "$source" "$ref"
  done
}

# ---------------------------------------------------------------------------
# Claude Code plugins (marketplace + plugin), Claude-only
# ---------------------------------------------------------------------------
CLAUDE_MARKETPLACE_JSON=""
CLAUDE_PLUGIN_JSON=""

refresh_claude_json() {
  CLAUDE_MARKETPLACE_JSON="$(claude plugin marketplace list --json 2>/dev/null)"
  CLAUDE_PLUGIN_JSON="$(claude plugin list --json 2>/dev/null)"
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

plugin_installed() {
  # $1 = plugin name, $2 = marketplace name. See the header comment above
  # for why both a `marketplace` and a `source` key are checked - the
  # exact field name in `claude plugin list --json`'s output for "which
  # marketplace this came from" isn't confirmed against Anthropic's docs.
  CHECK_PLUGIN="$1" CHECK_MARKETPLACE="$2" python3 -c '
import json, os, sys
plugin = os.environ["CHECK_PLUGIN"]
marketplace = os.environ["CHECK_MARKETPLACE"]
try:
    data = json.loads(sys.stdin.read() or "[]")
except Exception:
    sys.exit(1)
for p in (data if isinstance(data, list) else []):
    if p.get("name") == plugin and marketplace in (p.get("marketplace"), p.get("source")):
        sys.exit(0)
sys.exit(1)
' <<<"$CLAUDE_PLUGIN_JSON"
}

install_claude_plugin() {
  local mp_name="$1" mp_source="$2" plugin_name="$3"
  local desc="plugin: $plugin_name@$mp_name"

  if ! marketplace_installed "$mp_name"; then
    if claude plugin marketplace add "$mp_source" >/dev/null 2>&1; then
      log "marketplace: $mp_name (added from $mp_source)"
      refresh_claude_json
    else
      fail "marketplace: $mp_name - add failed: $mp_source"
      return
    fi
  fi

  if plugin_installed "$plugin_name" "$mp_name"; then
    log "$desc (already installed)"
    return
  fi

  if claude plugin install "${plugin_name}@${mp_name}" --scope user --yes >/dev/null 2>&1; then
    log "$desc (installed)"
  else
    fail "$desc - install failed"
  fi
}

run_plugin_installs() {
  [[ ${#PLUGINS_REGISTRY[@]} -eq 0 ]] && return
  if ! require_cmd claude; then
    fail "claude-plugins section - 'claude' not found on PATH, skipping all plugin entries"
    return
  fi
  if ! require_cmd python3; then
    fail "claude-plugins section - 'python3' not found, skipping all plugin entries (needed to parse 'claude plugin ... --json' safely)"
    return
  fi

  refresh_claude_json

  local entry mp_name mp_source plugin_name
  for entry in "${PLUGINS_REGISTRY[@]}"; do
    IFS='|' read -r mp_name mp_source plugin_name _ <<<"$entry"
    install_claude_plugin "$mp_name" "$mp_source" "$plugin_name"
  done
}

# ---------------------------------------------------------------------------
# Status table
# ---------------------------------------------------------------------------
print_status() {
  if [[ ${#SKILLS_REGISTRY[@]} -gt 0 ]]; then
    echo "Agent-agnostic skills (~/.agents/skills):"
    printf "%-24s %-14s %s\n" "NAME" "STATUS" "SOURCE"
    printf '%s\n' "----------------------------------------------------------------------"
    local entry name source ref target status
    for entry in "${SKILLS_REGISTRY[@]}"; do
      IFS='|' read -r name source ref _ <<<"$entry"
      target="$AGENT_SKILLS_DIR/$name"
      if [[ -d "$target/.git" ]]; then
        status="OK"
      else
        status="NOT INSTALLED"
      fi
      printf "%-24s %-14s %s\n" "$name" "$status" "$source${ref:+ @ $ref}"
    done
    echo
  fi

  if [[ ${#PLUGINS_REGISTRY[@]} -gt 0 ]]; then
    echo "Claude Code plugins:"
    printf "%-24s %-20s %-14s %s\n" "PLUGIN" "MARKETPLACE" "STATUS" "SOURCE"
    printf '%s\n' "----------------------------------------------------------------------"
    if ! require_cmd claude || ! require_cmd python3; then
      warn "'claude' and/or 'python3' not found - can't check installed state, showing registry only."
      local entry mp_name mp_source plugin_name
      for entry in "${PLUGINS_REGISTRY[@]}"; do
        IFS='|' read -r mp_name mp_source plugin_name _ <<<"$entry"
        printf "%-24s %-20s %-14s %s\n" "$plugin_name" "$mp_name" "UNKNOWN" "$mp_source"
      done
    else
      refresh_claude_json
      local entry mp_name mp_source plugin_name status
      for entry in "${PLUGINS_REGISTRY[@]}"; do
        IFS='|' read -r mp_name mp_source plugin_name _ <<<"$entry"
        if ! marketplace_installed "$mp_name"; then
          status="MARKETPLACE MISSING"
        elif plugin_installed "$plugin_name" "$mp_name"; then
          status="OK"
        else
          status="NOT INSTALLED"
        fi
        printf "%-24s %-20s %-14s %s\n" "$plugin_name" "$mp_name" "$status" "$mp_source"
      done
    fi
    echo
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
  -h|--help)
    sed -n '1,36p' "$0"
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
