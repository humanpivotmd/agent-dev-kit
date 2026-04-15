#!/usr/bin/env bash
# SessionStart hook — logs a session_start event.

set -euo pipefail
# shellcheck source=./lib/metrics.sh
source "$(dirname "$0")/lib/metrics.sh"

adk_log session_start

exit 0
