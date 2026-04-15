# PostToolUse hook — PowerShell version.
# Parity with hooks/post-tool-use.sh:
#   - Per-file tsc + eslint
#   - page.tsx 200-line limit (ADK_ALLOW_OVERSIZE grandfathered)

$ErrorActionPreference = "Continue"
. "$PSScriptRoot/lib/metrics.ps1"

$input_json = [Console]::In.ReadToEnd()
$FilePath = ""
try {
    $parsed = $input_json | ConvertFrom-Json -ErrorAction Stop
    if ($parsed.tool_input -and $parsed.tool_input.file_path) {
        $FilePath = $parsed.tool_input.file_path
    }
} catch { }

if (-not $FilePath) { exit 0 }

# Only check TS/JS/TSX/JSX
$ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
if ($ext -notin ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs") { exit 0 }

$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
Push-Location $projectDir

$PageSizeOut = ""
$PageSizeWarn = ""

# Page size check (page.tsx only, 200 lines)
if ($FilePath -match "app[\\/].*page\.(tsx|ts|jsx|js)$") {
    if (Test-Path $FilePath) {
        $lines = (Get-Content $FilePath | Measure-Object -Line).Lines
        if ($lines -gt 200) {
            if ($env:ADK_ALLOW_OVERSIZE -eq "1") {
                $PageSizeWarn = "⚠️  Grandfathered oversize page: $FilePath ($lines lines). ADK_ALLOW_OVERSIZE=1 set. Boy-scout rule: extract at least the function/section you just touched into src/app/<route>/components/ in the NEXT batch. Do not add new code without extracting existing code."
            } else {
                $PageSizeOut = "Page component exceeds 200 lines ($lines). Options: (1) extract feature-specific UI into src/app/<route>/components/ as the NEXT batch, OR (2) set ADK_ALLOW_OVERSIZE=1 to edit this grandfathered file under the boy-scout rule. See CLAUDE.md → Code Conventions → 파일 크기."
            }
        }
    }
}

# Typecheck just this file
$TscOut = ""
if ((Test-Path "tsconfig.json") -and (Get-Command npx -ErrorAction SilentlyContinue)) {
    $raw = npx --no-install tsc --noEmit --pretty false 2>&1 | Out-String
    $TscOut = ($raw -split "`n" | Where-Object { $_ -match [regex]::Escape($FilePath) }) -join "`n"
}

# Lint just this file
$LintOut = ""
if ((Test-Path ".eslintrc.json") -or (Test-Path "eslint.config.js") -or (Test-Path ".eslintrc.js")) {
    if (Get-Command npx -ErrorAction SilentlyContinue) {
        $LintOut = (npx --no-install eslint --format compact $FilePath 2>&1 | Out-String).Trim()
    }
}

Pop-Location

if ($TscOut -or $LintOut -or $PageSizeOut) {
    if ($PageSizeOut) { Adk-Log -Event "oversize_blocked" -Data @{ file_path = $FilePath } }
    if ($TscOut -or $LintOut) { Adk-Log -Event "post_tool_failed" -Data @{ file_path = $FilePath } }

    $out = @{
        decision = "block"
        reason   = "Post-write checks failed for $FilePath"
        hookSpecificOutput = @{
            hookEventName = "PostToolUse"
            additionalContext = "Page size:`n$PageSizeOut`n`nTypecheck:`n$TscOut`n`nLint:`n$LintOut"
        }
    }
    $out | ConvertTo-Json -Compress -Depth 5
    exit 0
}

# Non-blocking grandfathered warning
if ($PageSizeWarn) {
    Adk-Log -Event "oversize_warned" -Data @{ file_path = $FilePath }
    $out = @{
        hookSpecificOutput = @{
            hookEventName = "PostToolUse"
            additionalContext = $PageSizeWarn
        }
    }
    $out | ConvertTo-Json -Compress -Depth 5
    exit 0
}

exit 0
