# PreToolUse hook — PowerShell version.
# Parity with hooks/pre-tool-use.sh:
#   1. Blocks modification of 🔴 high-risk files unless $env:ADK_ALLOW_HIGH_RISK = '1'
#   2. Enforces the 3-files-per-batch rule via a session counter

$ErrorActionPreference = "Continue"
. "$PSScriptRoot/lib/metrics.ps1"

# Read tool_input from stdin
$input_json = [Console]::In.ReadToEnd()
$FilePath = ""
try {
    $parsed = $input_json | ConvertFrom-Json -ErrorAction Stop
    if ($parsed.tool_input -and $parsed.tool_input.file_path) {
        $FilePath = $parsed.tool_input.file_path
    }
} catch { }

# --- 1. High-risk file block --------------------------------------
$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { "." }
$HighRiskFile = Join-Path $projectDir ".md/설계문서/수정위험도.md"
if ((Test-Path $HighRiskFile) -and $FilePath) {
    $baseName = Split-Path -Leaf $FilePath
    $content = Get-Content $HighRiskFile -Raw -ErrorAction SilentlyContinue
    if ($content -and ($content -match [regex]::Escape($baseName)) -and ($content -match "🔴")) {
        if ($env:ADK_ALLOW_HIGH_RISK -ne "1") {
            Adk-Log -Event "risk_file_blocked" -Data @{ file_path = $FilePath }
            $out = @{
                hookSpecificOutput = @{
                    hookEventName = "PreToolUse"
                    permissionDecision = "ask"
                    permissionDecisionReason = "🔴 High-risk file: $FilePath. Set ADK_ALLOW_HIGH_RISK=1 to bypass after reviewing 수정위험도.md."
                }
            }
            $out | ConvertTo-Json -Compress -Depth 5
            exit 0
        }
    }
}

# --- 2. 3-files-per-batch counter ---------------------------------
$tmpDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
$sessionId = if ($env:CLAUDE_SESSION_ID) { $env:CLAUDE_SESSION_ID } else { "default" }
$CounterDir = Join-Path $tmpDir "adk-$sessionId"
if (-not (Test-Path $CounterDir)) {
    New-Item -ItemType Directory -Force -Path $CounterDir -ErrorAction SilentlyContinue | Out-Null
}
$CounterFile = Join-Path $CounterDir "batch-count"
$SeenFile = Join-Path $CounterDir "seen-files"

if (-not (Test-Path $CounterFile)) { "0" | Set-Content $CounterFile }
if (-not (Test-Path $SeenFile)) { "" | Set-Content $SeenFile }

$current = [int](Get-Content $CounterFile -ErrorAction SilentlyContinue)
$seen = Get-Content $SeenFile -ErrorAction SilentlyContinue

if ($FilePath -and ($seen -notcontains $FilePath)) {
    Add-Content $SeenFile $FilePath
    $current++
    "$current" | Set-Content $CounterFile
}

if ($current -gt 3) {
    Adk-Log -Event "batch_blocked" -Data @{ file_path = $FilePath; count = $current }
    $out = @{
        hookSpecificOutput = @{
            hookEventName = "PreToolUse"
            permissionDecision = "ask"
            permissionDecisionReason = "Batch limit: already modified $current files in this batch (max 3). Stop and report to user, then reset by touching $CounterDir/reset."
        }
    }
    $out | ConvertTo-Json -Compress -Depth 5
    exit 0
}

# Reset on explicit signal
if (Test-Path (Join-Path $CounterDir "reset")) {
    "0" | Set-Content $CounterFile
    "" | Set-Content $SeenFile
    Remove-Item (Join-Path $CounterDir "reset") -ErrorAction SilentlyContinue
}

exit 0
