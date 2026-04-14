#!/usr/bin/env bash
# PostToolUse hook — runs after Write/Edit.
# Fast per-file lint + typecheck on the touched file. Feeds errors back
# into Claude's context instead of forcing a separate /test run.

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(printf '%s' "$INPUT" | node -e "
try {
  const i = JSON.parse(require('fs').readFileSync(0, 'utf8'));
  process.stdout.write(i.tool_input?.file_path || '');
} catch { process.stdout.write(''); }
")

[[ -z "$FILE_PATH" ]] && exit 0

# Only check TS/JS/TSX/JSX
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) ;;
  *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}"

# --- Page component size limit (200 lines, page.tsx only) -----------
# Enforces Code Conventions → "신규 파일: 200줄 이하 필수"
# Boy-scout rule: existing oversize files are grandfathered via
# ADK_ALLOW_OVERSIZE=1, but the edit must only touch existing sections.
# Matches any app/**/page.tsx (Next.js App Router).
PAGE_SIZE_OUT=""
case "$FILE_PATH" in
  *app/*page.tsx|*app/*page.ts|*app/*page.jsx|*app/*page.js)
    if [[ -f "$FILE_PATH" ]]; then
      LINES=$(wc -l < "$FILE_PATH" | tr -d ' ')
      if (( LINES > 200 )); then
        if [[ "${ADK_ALLOW_OVERSIZE:-0}" == "1" ]]; then
          # Grandfathered: emit a soft warning in additionalContext but do
          # not block. Implementer should still apply the boy-scout rule
          # (extract one function/section per edit).
          PAGE_SIZE_OUT="⚠️  Grandfathered oversize page: ${FILE_PATH} (${LINES} lines). ADK_ALLOW_OVERSIZE=1 set. Boy-scout rule: extract at least the function/section you just touched into src/app/<route>/components/ in the NEXT batch. Do not add new code without extracting existing code."
          # Use exit 0 with no blocking JSON below — see the combined check
        else
          PAGE_SIZE_OUT="Page component exceeds 200 lines (${LINES}). Options: (1) extract feature-specific UI into src/app/<route>/components/ as the NEXT batch, OR (2) set ADK_ALLOW_OVERSIZE=1 to edit this grandfathered file under the boy-scout rule. See CLAUDE.md → Code Conventions → 파일 크기."
        fi
      fi
    fi
    ;;
esac

# Grandfathered warnings should NOT block — clear them into a separate var
PAGE_SIZE_WARN=""
if [[ -n "$PAGE_SIZE_OUT" && "${ADK_ALLOW_OVERSIZE:-0}" == "1" ]]; then
  PAGE_SIZE_WARN="$PAGE_SIZE_OUT"
  PAGE_SIZE_OUT=""
fi

# Typecheck just this file (fast, --noEmit)
TSC_OUT=""
if command -v npx >/dev/null 2>&1 && [[ -f "tsconfig.json" ]]; then
  TSC_OUT=$(npx --no-install tsc --noEmit --pretty false 2>&1 | grep -F "$FILE_PATH" || true)
fi

# Lint just this file if eslint is available
LINT_OUT=""
if command -v npx >/dev/null 2>&1 && [[ -f ".eslintrc.json" || -f "eslint.config.js" || -f ".eslintrc.js" ]]; then
  LINT_OUT=$(npx --no-install eslint --format compact "$FILE_PATH" 2>&1 || true)
fi

if [[ -n "$TSC_OUT" || -n "$LINT_OUT" || -n "$PAGE_SIZE_OUT" ]]; then
  REASON=$(printf 'Post-write checks failed for %s' "$FILE_PATH")
  CONTEXT=$(printf 'Page size:\n%s\n\nTypecheck:\n%s\n\nLint:\n%s\n' "$PAGE_SIZE_OUT" "$TSC_OUT" "$LINT_OUT")
  # Use node for safe JSON escaping
  node -e "
    const reason = process.argv[1];
    const context = process.argv[2];
    console.log(JSON.stringify({
      decision: 'block',
      reason,
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext: context
      }
    }));
  " "$REASON" "$CONTEXT"
  exit 0
fi

# Non-blocking grandfathered warning — inject context, allow the edit.
if [[ -n "$PAGE_SIZE_WARN" ]]; then
  node -e "
    const warn = process.argv[1];
    console.log(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext: warn
      }
    }));
  " "$PAGE_SIZE_WARN"
  exit 0
fi

exit 0
