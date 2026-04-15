#!/usr/bin/env bash
# Hard block for dangerous bash commands.
# Matched via `if:` pattern in hooks.json — rm -rf, force push, --no-verify.

# shellcheck source=./lib/metrics.sh
source "$(dirname "$0")/lib/metrics.sh"

# Read matched command from stdin if available (best effort)
INPUT=$(cat 2>/dev/null || true)
CMD=$(printf '%s' "$INPUT" | node -e "
try {
  const i = JSON.parse(require('fs').readFileSync(0, 'utf8'));
  process.stdout.write(i.tool_input?.command || '');
} catch { process.stdout.write(''); }
" 2>/dev/null || true)

adk_log danger_blocked command="${CMD:0:80}"

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "ADK hard-blocks: rm -rf, git push --force, and --no-verify. Explain intent to user and run a safer alternative."
  }
}
EOF

exit 0
