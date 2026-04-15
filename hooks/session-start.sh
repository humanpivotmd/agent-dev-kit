#!/usr/bin/env bash
# SessionStart hook — logs a session_start event and surfaces the latest
# checkpoint hint from previous sessions.

set -euo pipefail
# shellcheck source=./lib/metrics.sh
source "$(dirname "$0")/lib/metrics.sh"
# shellcheck source=./lib/checkpoint.sh
source "$(dirname "$0")/lib/checkpoint.sh"

adk_log session_start

# Surface previous checkpoint as additionalContext (non-blocking)
HINT=$(adk_checkpoint_hint 2>/dev/null || true)

if [[ -n "$HINT" ]]; then
  node -e '
    const hint = process.argv[1];
    console.log(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: "ADK: " + hint + ". Run `node scripts/metrics-report.mjs` for full history."
      }
    }));
  ' "$HINT"
fi

exit 0
