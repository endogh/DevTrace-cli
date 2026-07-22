# DevTrace PowerShell Hook
# Add to $PROFILE:
#   . ~/.devtrace/devtrace-hook.ps1

# Function to show devtrace banner
function Show-DevTraceBanner {
    if (Test-Path ".devtrace") {
        $session = Get-Content .devtrace/current.txt -ErrorAction SilentlyContinue
        if ($session) {
            $count = (Get-ChildItem .devtrace/*.md -ErrorAction SilentlyContinue).Count
            if ($count -gt 1) {
                Write-Host "[DEVTRACE] Active: $session ($count sessions available)" -ForegroundColor Cyan
            } else {
                Write-Host "[DEVTRACE] Active: $session" -ForegroundColor Cyan
            }
        }
    }
}

# Function to capture errors
function Invoke-DevTraceError {
    if ($LASTEXITCODE -ne 0) {
        $lastCmd = (Get-History -Count 1).CommandLine
        if ($lastCmd) {
            devtrace error "Exit code: $LASTEXITCODE" --context "Command: $lastCmd" 2>$null
        }
    }
}

# Override prompt to show devtrace banner
function Prompt {
    Invoke-DevTraceError
    Show-DevTraceBanner
    return "PS> "
}

# Helper functions
function devtrace-status {
    if (Test-Path ".devtrace") {
        $session = Get-Content .devtrace/current.txt -ErrorAction SilentlyContinue
        if ($session) {
            Write-Host "[DEVTRACE] Active: $session" -ForegroundColor Cyan
        } else {
            Write-Host "[DEVTRACE] No active session"
        }
    } else {
        Write-Host "[DEVTRACE] Not a devtrace project (no .devtrace/ directory)"
    }
}

function devtrace-sessions {
    if (Test-Path ".devtrace") {
        Write-Host "[DEVTRACE] Sessions:"
        Get-ChildItem .devtrace/*.md -ErrorAction SilentlyContinue | ForEach-Object {
            $name = $_.BaseName
            $marker = ""
            $current = Get-Content .devtrace/current.txt -ErrorAction SilentlyContinue
            if ($name -eq $current) {
                $marker = " [ACTIVE]"
            }
            Write-Host "  - $name$marker"
        }
    } else {
        Write-Host "[DEVTRACE] Not a devtrace project"
    }
}

Write-Host "[DEVTRACE] PowerShell hook loaded" -ForegroundColor Cyan
