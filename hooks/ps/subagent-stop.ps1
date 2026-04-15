# SubagentStop hook — PowerShell version.
# Resets the 3-file batch counter when @implementer finishes.

$ErrorActionPreference = "Continue"
. "$PSScriptRoot/lib/metrics.ps1"

$input_json = [Console]::In.ReadToEnd()
Adk-Log -Event "subagent_stop"

# Reset batch counter
$tmpDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
$sessionId = if ($env:CLAUDE_SESSION_ID) { $env:CLAUDE_SESSION_ID } else { "default" }
$CounterDir = Join-Path $tmpDir "adk-$sessionId"

if (Test-Path $CounterDir) {
    "0" | Set-Content (Join-Path $CounterDir "batch-count") -ErrorAction SilentlyContinue
    "" | Set-Content (Join-Path $CounterDir "seen-files") -ErrorAction SilentlyContinue
}

$out = @{
    hookSpecificOutput = @{
        hookEventName = "SubagentStop"
        additionalContext = "@implementer finished. Next step: @verifier (which will dispatch @code-reviewer, @test-runner, @security-scanner in parallel). Batch counter reset."
    }
}
$out | ConvertTo-Json -Compress -Depth 5

exit 0
