# UserPromptSubmit hook — PowerShell version.
# Injects short rules/state summary as additionalContext.

$ErrorActionPreference = "Continue"
. "$PSScriptRoot/lib/metrics.ps1"

Adk-Log -Event "user_prompt_submit"

$projectRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }

$parts = @()

# 1. Active rules
$activeFile = Join-Path $projectRoot ".md/rules/active.md"
if (Test-Path $activeFile) {
  $lines = Get-Content $activeFile |
    Where-Object { $_ -notmatch '^(#|>|\s*$)' } |
    Select-Object -First 15
  if ($lines) {
    $parts += "🔒 Active rules:"
    $parts += ($lines -join "`n")
  }
}

# 2. Co-update threshold alerts
$casesFile = Join-Path $projectRoot ".md/co-update/cases.md"
if (Test-Path $casesFile) {
  $alerts = Get-Content $casesFile |
    Where-Object { $_ -match ':\s*(\d+)건' } |
    ForEach-Object {
      if ($_ -match ':\s*(\d+)건') {
        $n = [int]$matches[1]
        if ($n -ge 3) { "- $_" }
      }
    } |
    Select-Object -First 5
  if ($alerts) {
    $parts += ""
    $parts += "📊 Co-update 임계값 도달 (pattern-extractor 권장):"
    $parts += ($alerts -join "`n")
  }
}

# 3. Danger files
$dangerFile = Join-Path $projectRoot ".md/rules/danger-files.md"
if (Test-Path $dangerFile) {
  $lines = Get-Content $dangerFile |
    Where-Object { $_ -match '^- ' } |
    Select-Object -First 8
  if ($lines) {
    $parts += ""
    $parts += "🔴 수정 금지 (승인 필수):"
    $parts += ($lines -join "`n")
  }
}

if ($parts.Count -eq 0) { exit 0 }

$context = $parts -join "`n"
$output = @{
  hookSpecificOutput = @{
    hookEventName    = "UserPromptSubmit"
    additionalContext = $context
  }
} | ConvertTo-Json -Depth 4 -Compress

Write-Output $output
exit 0
