#!/usr/bin/env bash
# PreToolUse hook — runs before Write/Edit.
# 1. Blocks modification of 🔴 high-risk files unless ADK_ALLOW_HIGH_RISK=1
# 2. Enforces the 3-files-per-batch rule via a session counter

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(printf '%s' "$INPUT" | node -e "
try {
  const i = JSON.parse(require('fs').readFileSync(0, 'utf8'));
  process.stdout.write(i.tool_input?.file_path || '');
} catch { process.stdout.write(''); }
")

# --- 1. High-risk file block ---------------------------------------
HIGH_RISK_FILE="${CLAUDE_PROJECT_DIR:-.}/.md/설계문서/수정위험도.md"
if [[ -f "$HIGH_RISK_FILE" && -n "$FILE_PATH" ]]; then
  BASENAME=$(basename "$FILE_PATH")
  if grep -q "🔴.*${BASENAME}\|${BASENAME}.*🔴" "$HIGH_RISK_FILE" 2>/dev/null; then
    if [[ "${ADK_ALLOW_HIGH_RISK:-0}" != "1" ]]; then
      cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "🔴 High-risk file: ${FILE_PATH}. Set ADK_ALLOW_HIGH_RISK=1 to bypass after reviewing 수정위험도.md."
  }
}
EOF
      exit 0
    fi
  fi
fi

# --- 2. 3-files-per-batch counter ---------------------------------
COUNTER_DIR="${TMPDIR:-/tmp}/adk-${CLAUDE_SESSION_ID:-default}"
mkdir -p "$COUNTER_DIR"
COUNTER_FILE="$COUNTER_DIR/batch-count"
[[ -f "$COUNTER_FILE" ]] || echo "0" > "$COUNTER_FILE"
CURRENT=$(cat "$COUNTER_FILE")

# Only count unique files in the current batch
SEEN_FILE="$COUNTER_DIR/seen-files"
touch "$SEEN_FILE"
if ! grep -Fxq "$FILE_PATH" "$SEEN_FILE" 2>/dev/null; then
  echo "$FILE_PATH" >> "$SEEN_FILE"
  CURRENT=$((CURRENT + 1))
  echo "$CURRENT" > "$COUNTER_FILE"
fi

if (( CURRENT > 3 )); then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "Batch limit: already modified ${CURRENT} files in this batch (max 3). Stop and report to user, then reset by touching ${COUNTER_DIR}/reset."
  }
}
EOF
  exit 0
fi

# Reset on explicit signal
if [[ -f "$COUNTER_DIR/reset" ]]; then
  echo "0" > "$COUNTER_FILE"
  : > "$SEEN_FILE"
  rm -f "$COUNTER_DIR/reset"
fi

exit 0
