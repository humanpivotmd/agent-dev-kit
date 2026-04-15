#!/usr/bin/env bash
# UserPromptSubmit hook — inject short status summary as additionalContext
# so Claude gets essential rules/state without reading full CLAUDE.md.
#
# Sources (all optional — hook degrades gracefully):
#   1. ${PROJECT_ROOT}/.md/rules/active.md        — 10-line always-on rules
#   2. ${PROJECT_ROOT}/.md/co-update/cases.md     — category threshold alerts
#   3. ${PROJECT_ROOT}/.md/rules/danger-files.md  — 🔴 files list (first section)
#
# Cross-project fallback:
#   If $PROJECT_ROOT has no .md/rules/active.md, read ~/.claude/adk-projects.json
#   and scan the user prompt for pattern matches. On match, override PROJECT_ROOT
#   to the matched project's path so rules are still injected even when Claude Code
#   runs from a non-project CWD (e.g. user's home directory).

set -uo pipefail
# shellcheck source=./lib/metrics.sh
source "$(dirname "$0")/lib/metrics.sh" 2>/dev/null || true

adk_log user_prompt_submit 2>/dev/null || true

# CWD is the project root when Claude Code runs hooks
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# Read stdin (Claude Code passes {"prompt": "..."} JSON)
STDIN_JSON=""
if ! [ -t 0 ]; then
  STDIN_JSON=$(cat)
fi

PROMPT_TEXT=""
if [[ -n "$STDIN_JSON" ]]; then
  PROMPT_TEXT=$(node -e '
    try {
      const input = JSON.parse(process.argv[1] || "{}");
      if (input && typeof input.prompt === "string") process.stdout.write(input.prompt);
    } catch {}
  ' "$STDIN_JSON" 2>/dev/null || true)
fi

# Cross-project detection: if current root has no rules, try to match prompt
DETECTED_VIA_PATTERN=""
if [[ ! -f "$PROJECT_ROOT/.md/rules/active.md" && -n "$PROMPT_TEXT" ]]; then
  CONFIG="${HOME}/.claude/adk-projects.json"
  if [[ -f "$CONFIG" ]]; then
    DETECTED=$(node -e '
      const fs = require("fs");
      try {
        const cfg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
        const prompt = process.argv[2] || "";
        for (const p of (cfg.projects || [])) {
          for (const pat of (p.patterns || [])) {
            if (pat && prompt.indexOf(pat) !== -1) {
              process.stdout.write(p.path || "");
              process.exit(0);
            }
          }
        }
      } catch {}
    ' "$CONFIG" "$PROMPT_TEXT" 2>/dev/null || true)
    if [[ -n "$DETECTED" && -f "$DETECTED/.md/rules/active.md" ]]; then
      PROJECT_ROOT="$DETECTED"
      DETECTED_VIA_PATTERN="$DETECTED"
    fi
  fi
fi

PARTS=()

# Cross-project indicator
if [[ -n "$DETECTED_VIA_PATTERN" ]]; then
  PARTS+=("📍 Cross-project rules loaded from: $DETECTED_VIA_PATTERN")
  PARTS+=("(CWD is outside project — pattern-matched from prompt)")
  PARTS+=("")
fi

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
