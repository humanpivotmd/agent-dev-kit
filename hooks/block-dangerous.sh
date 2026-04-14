#!/usr/bin/env bash
# Hard block for dangerous bash commands.
# Matched via `if:` pattern in hooks.json — rm -rf, force push, --no-verify.

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
