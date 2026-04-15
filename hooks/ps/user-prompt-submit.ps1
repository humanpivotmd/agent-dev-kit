# UserPromptSubmit hook — PowerShell version.
# Injects short rules/state summary as additionalContext.
#
# Cross-project fallback: if $projectRoot has no .md/rules/active.md,
# read ~/.claude/adk-projects.json and pattern-match the prompt to detect
# which project the user is working on, even when Claude Code runs from
# a non-project CWD.

$ErrorActionPreference = "Continue"
. "$PSScriptRoot/lib/metrics.ps1"

Adk-Log -Event "user_prompt_submit"

$projectRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }

# Read stdin (Claude Code passes {"prompt": "..."} JSON)
$stdinJson = ""
if (-not [Console]::IsInputRedirected -eq $false) {
  try { $stdinJson = [Console]::In.ReadToEnd() } catch {}
}

$promptText = ""
if ($stdinJson) {
  try {
    $parsed = $stdinJson | ConvertFrom-Json
    if ($parsed.prompt) { $promptText = [string]$parsed.prompt }
  } catch {}
}

# Cross-project detection
$detectedViaPattern = ""
$activeCheck = Join-Path $projectRoot ".md/rules/active.md"
if (-not (Test-Path $activeCheck) -and $promptText) {
  $configPath = Join-Path $env:USERPROFILE ".claude/adk-projects.json"
  if (Test-Path $configPath) {
    try {
      $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
      foreach ($p in $cfg.projects) {
        foreach ($pat in $p.patterns) {
          if ($pat -and $promptText.Contains($pat)) {
            $candidate = $p.path
            if ($candidate -and (Test-Path (Join-Path $candidate ".md/rules/active.md"))) {
              $projectRoot = $candidate
              $detectedViaPattern = $candidate
            }
            break
          }
        }
        if ($detectedViaPattern) { break }
      }
    } catch {}
  }
}

$parts = @()

if ($detectedViaPattern) {
  $parts += "📍 Cross-project rules loaded from: $detectedViaPattern"
  $parts += "(CWD is outside project — pattern-matched from prompt)"
  $parts += ""
}

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
