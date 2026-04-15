# Stop hook — PowerShell version. Logs a session_stop event.

$ErrorActionPreference = "Continue"
. "$PSScriptRoot/lib/metrics.ps1"

Adk-Log -Event "session_stop"

exit 0
