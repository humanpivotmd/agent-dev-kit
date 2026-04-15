#!/usr/bin/env bash
# ADK checkpoint — lightweight session state snapshot.
#
# Sourced by hooks via:
#   source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/checkpoint.sh"
#   adk_checkpoint_save "skill_name"  # at skill completion
#   adk_checkpoint_latest              # prints latest checkpoint JSON
#
# Stores at $ADK_CHECKPOINT_DIR (default: ~/.claude/adk-checkpoints/)
# One JSON file per save: <session_id>_<skill>_<ts>.json
# Keeps last 20 per session (older ones pruned).
#
# Inspired by md/checkpoint.py CheckpointStore. Key differences:
#   - Scoped to Claude Code session, not a standalone run_id
#   - Append-only snapshots (not full state machine — just "skill X completed")
#   - Silent failure (never breaks calling hook)

: "${ADK_CHECKPOINT_DIR:=${HOME:-$USERPROFILE}/.claude/adk-checkpoints}"
: "${ADK_CHECKPOINT_KEEP:=20}"

adk_checkpoint_init() {
  [[ -d "$ADK_CHECKPOINT_DIR" ]] || mkdir -p "$ADK_CHECKPOINT_DIR" 2>/dev/null || return 0
}

# Save a checkpoint marker for the current session.
# Usage: adk_checkpoint_save "skill_name"
adk_checkpoint_save() {
  adk_checkpoint_init || return 0
  local skill="${1:-unknown}"
  local session="${CLAUDE_SESSION_ID:-default}"
  local ts
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  local file="$ADK_CHECKPOINT_DIR/${session}_${skill}_${ts}.json"

  node -e '
    const file = process.argv[1];
    const session = process.argv[2];
    const skill = process.argv[3];
    const obj = {
      ts: new Date().toISOString(),
      session_id: session,
      skill: skill,
      cwd: process.env.CLAUDE_PROJECT_DIR || process.cwd(),
    };
    require("fs").writeFileSync(file, JSON.stringify(obj, null, 2));
  ' "$file" "$session" "$skill" 2>/dev/null || return 0

  adk_checkpoint_prune "$session"
}

# Prune old checkpoints for a session, keeping the last N.
adk_checkpoint_prune() {
  local session="${1:-default}"
  # List + sort + head tail — POSIX portable
  local files
  mapfile -t files < <(ls -1 "$ADK_CHECKPOINT_DIR"/"${session}"_*.json 2>/dev/null | sort)
  local count=${#files[@]}
  if (( count > ADK_CHECKPOINT_KEEP )); then
    local to_remove=$((count - ADK_CHECKPOINT_KEEP))
    for (( i=0; i<to_remove; i++ )); do
      rm -f "${files[$i]}" 2>/dev/null || true
    done
  fi
}

# Print the latest checkpoint JSON for a session (or most recent session if none given).
# Empty output if no checkpoints found.
adk_checkpoint_latest() {
  local session="${1:-}"
  adk_checkpoint_init || return 0

  local latest=""
  if [[ -n "$session" ]]; then
    latest=$(ls -1 "$ADK_CHECKPOINT_DIR"/"${session}"_*.json 2>/dev/null | sort | tail -1)
  else
    latest=$(ls -1 "$ADK_CHECKPOINT_DIR"/*.json 2>/dev/null | sort | tail -1)
  fi

  if [[ -n "$latest" && -f "$latest" ]]; then
    cat "$latest"
  fi
}

# Build a human-readable "last skill" hint from the latest checkpoint.
# Returns empty string if none.
adk_checkpoint_hint() {
  local latest
  latest=$(adk_checkpoint_latest 2>/dev/null)
  [[ -z "$latest" ]] && return 0

  node -e '
    try {
      const data = JSON.parse(process.argv[1]);
      const ts = new Date(data.ts);
      const ageMin = Math.round((Date.now() - ts.getTime()) / 60000);
      const ageStr = ageMin < 60 ? `${ageMin}m ago` : `${Math.round(ageMin/60)}h ago`;
      console.log(`Last checkpoint: ${data.skill} (${ageStr}, session ${(data.session_id||"").slice(0,8)})`);
    } catch {}
  ' "$latest" 2>/dev/null || return 0
}
