#!/usr/bin/env bash
# UserPromptSubmit hook — inject short status summary as additionalContext
# so Claude gets essential rules/state without reading full CLAUDE.md.
#
# Sources (all optional — hook degrades gracefully):
#   1. ${PROJECT_ROOT}/.md/rules/active.md        — 10-line always-on rules
#   2. ${PROJECT_ROOT}/.md/co-update/cases.md     — category threshold alerts
#   3. ${PROJECT_ROOT}/.md/rules/danger-files.md  — 🔴 files list (first section)

set -uo pipefail
# shellcheck source=./lib/metrics.sh
source "$(dirname "$0")/lib/metrics.sh" 2>/dev/null || true

adk_log user_prompt_submit 2>/dev/null || true

# CWD is the project root when Claude Code runs hooks
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

PARTS=()

# 1. Active rules (short, curated)
ACTIVE_RULES="$PROJECT_ROOT/.md/rules/active.md"
if [[ -f "$ACTIVE_RULES" ]]; then
  # Strip markdown headers, trim empty lines, cap 15 lines
  CONTENT=$(grep -vE '^(#|>|$)' "$ACTIVE_RULES" | head -15)
  if [[ -n "$CONTENT" ]]; then
    PARTS+=("🔒 Active rules:")
    PARTS+=("$CONTENT")
  fi
fi

# 2. Co-update threshold alerts (entries >= 3)
CASES="$PROJECT_ROOT/.md/co-update/cases.md"
if [[ -f "$CASES" ]]; then
  # Extract "<tag> : N건" lines anywhere and flag those with N >= 3
  ALERTS=$(grep -E ': [0-9]+건' "$CASES" 2>/dev/null \
    | awk -F: '{ n=$2; gsub(/건.*/, "", n); gsub(/ /, "", n); if (n+0 >= 3) print "- " $0 }' \
    | head -5)
  if [[ -n "$ALERTS" ]]; then
    PARTS+=("")
    PARTS+=("📊 Co-update 임계값 도달 (pattern-extractor 권장):")
    PARTS+=("$ALERTS")
  fi
fi

# 3. Danger files (first bullet list block)
DANGER="$PROJECT_ROOT/.md/rules/danger-files.md"
if [[ -f "$DANGER" ]]; then
  DANGER_LIST=$(grep -E '^- ' "$DANGER" | head -8)
  if [[ -n "$DANGER_LIST" ]]; then
    PARTS+=("")
    PARTS+=("🔴 수정 금지 (승인 필수):")
    PARTS+=("$DANGER_LIST")
  fi
fi

# Nothing to inject?
if [[ ${#PARTS[@]} -eq 0 ]]; then
  exit 0
fi

# Join parts with newlines
CONTEXT=$(printf '%s\n' "${PARTS[@]}")

# Emit hookSpecificOutput JSON
node -e '
  const ctx = process.argv[1];
  console.log(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: ctx
    }
  }));
' "$CONTEXT"

exit 0
