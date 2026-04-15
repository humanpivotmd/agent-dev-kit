#!/usr/bin/env bash
# SubagentStop hook — runs when @implementer finishes.
# Resets the 3-file batch counter so the next batch starts fresh,
# and injects a reminder about the verifier step.

set -euo pipefail

# shellcheck source=./lib/metrics.sh
source "$(dirname "$0")/lib/metrics.sh"
# shellcheck source=./lib/checkpoint.sh
source "$(dirname "$0")/lib/checkpoint.sh"

INPUT=$(cat)
adk_log subagent_stop

# Save a checkpoint marker — "implementer finished" is a natural skill boundary
adk_checkpoint_save "implementer"

COUNTER_DIR="${TMPDIR:-/tmp}/adk-${CLAUDE_SESSION_ID:-default}"
if [[ -d "$COUNTER_DIR" ]]; then
  echo "0" > "$COUNTER_DIR/batch-count" 2>/dev/null || true
  : > "$COUNTER_DIR/seen-files" 2>/dev/null || true
fi

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStop",
    "additionalContext": "@implementer finished. Next step: @verifier (which will dispatch @code-reviewer, @test-runner, @security-scanner in parallel). Batch counter reset."
  }
}
EOF

exit 0
