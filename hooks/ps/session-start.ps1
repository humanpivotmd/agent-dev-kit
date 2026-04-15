# SessionStart hook — PowerShell version. Logs a session_start event.

$ErrorActionPreference = "Continue"
. "$PSScriptRoot/lib/metrics.ps1"

Adk-Log -Event "session_start"

exit 0
