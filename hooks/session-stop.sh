#!/usr/bin/env bash
# Stop hook — logs a session_stop event.

set -euo pipefail
# shellcheck source=./lib/metrics.sh
source "$(dirname "$0")/lib/metrics.sh"

adk_log session_stop

exit 0
