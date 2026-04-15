# Hard block for dangerous bash commands — PowerShell version.
# Matched via `if:` pattern in hooks.json — rm -rf, force push, --no-verify.

$ErrorActionPreference = "Continue"
. "$PSScriptRoot/lib/metrics.ps1"

# Read matched command from stdin
$input_json = [Console]::In.ReadToEnd()
$cmd = ""
try {
    $parsed = $input_json | ConvertFrom-Json -ErrorAction Stop
    if ($parsed.tool_input -and $parsed.tool_input.command) {
        $cmd = $parsed.tool_input.command
    }
} catch { }

$preview = if ($cmd.Length -gt 80) { $cmd.Substring(0, 80) } else { $cmd }
Adk-Log -Event "danger_blocked" -Data @{ command = $preview }

$out = @{
    hookSpecificOutput = @{
        hookEventName = "PreToolUse"
        permissionDecision = "deny"
        permissionDecisionReason = "ADK hard-blocks: rm -rf, git push --force, and --no-verify. Explain intent to user and run a safer alternative."
    }
}
$out | ConvertTo-Json -Compress -Depth 5

exit 0
