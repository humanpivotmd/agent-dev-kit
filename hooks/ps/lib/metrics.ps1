# ADK metrics logger — PowerShell version.
# Parity with hooks/lib/metrics.sh — emits identical JSONL to the same file.
#
# Usage in other hooks:
#   . "$PSScriptRoot/lib/metrics.ps1"
#   Adk-Log -Event "oversize_blocked" -Data @{ file_path = $FilePath; lines = 234 }

# Default location (overridable)
if (-not $env:ADK_METRICS_FILE) {
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
    $env:ADK_METRICS_FILE = Join-Path $homeDir ".claude/adk-metrics.jsonl"
}

function Adk-Log {
    param(
        [Parameter(Mandatory)][string]$Event,
        [hashtable]$Data = @{}
    )

    try {
        $dir = Split-Path -Parent $env:ADK_METRICS_FILE
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Force -Path $dir -ErrorAction SilentlyContinue | Out-Null
        }

        $obj = [ordered]@{
            ts         = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            event      = $Event
            session_id = $env:CLAUDE_SESSION_ID
            cwd        = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
        }
        foreach ($k in $Data.Keys) {
            $obj[$k] = $Data[$k]
        }

        $json = $obj | ConvertTo-Json -Compress -Depth 5
        Add-Content -Path $env:ADK_METRICS_FILE -Value $json -Encoding utf8 -ErrorAction SilentlyContinue
    } catch {
        # Silent failure — never break the hook that called this
    }
}
