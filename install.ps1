# DevTrace CLI - Windows Install Script (PowerShell)
# For Windows (PowerShell) or WSL
#
# Usage:
#   .\install.ps1           # Install in venv (default)
#   .\install.ps1 -Global   # Install globally via pip

param(
    [switch]$Global
)

if ($Global) {
    Write-Host "DevTrace CLI Installer (global)" -ForegroundColor Cyan
} else {
    Write-Host "DevTrace CLI Installer (venv)" -ForegroundColor Cyan
}
Write-Host "========================="
Write-Host ""

# =========================
# CHECK PYTHON
# =========================

Write-Host "[1/5] Checking Python..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "Python found: $pythonVersion"
} catch {
    Write-Host "Python not found. Please install from https://www.python.org/downloads/" -ForegroundColor Red
    Write-Host "Make sure to check 'Add Python to PATH' during installation"
    exit 1
}

# For global mode, check pip
if ($Global) {
    Write-Host "[2/5] Checking pip..." -ForegroundColor Yellow
    try {
        pip --version | Out-Null
    } catch {
        Write-Host "Installing pip..." -ForegroundColor Yellow
        python -m ensurepip --upgrade
    }
} else {
    Write-Host "[2/5] Preparing venv..." -ForegroundColor Yellow
}

# =========================
# INSTALL DEVTRACE
# =========================

Write-Host "[3/5] Installing devtrace..." -ForegroundColor Yellow

$devtraceHome = "$env:USERPROFILE\.devtrace"

if ($Global) {
    pip install git+https://github.com/endogh/DevTrace-cli.git
} else {
    $venvDir = "$devtraceHome\venv"

    Write-Host "Creating virtual environment at $venvDir..."
    python -m venv "$venvDir"

    Write-Host "Installing devtrace in venv..."
    & "$venvDir\Scripts\pip.exe" install git+https://github.com/endogh/DevTrace-cli.git

    # Add venv Scripts to user PATH
    $venvBin = "$venvDir\Scripts"
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

    if ($currentPath -notlike "*devtrace*venv*") {
        $newPath = "$venvBin;$currentPath"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path = "$venvBin;$env:Path"
        Write-Host "Added venv to user PATH" -ForegroundColor Green
    }
}

# =========================
# CREATE DIRECTORIES
# =========================

Write-Host "[4/5] Setting up directories..." -ForegroundColor Yellow
if (!(Test-Path $devtraceHome)) {
    New-Item -ItemType Directory -Path $devtraceHome | Out-Null
}

# =========================
# DOWNLOAD SHELL HOOK
# =========================

Write-Host "[5/5] Installing PowerShell hook..." -ForegroundColor Yellow
$hookUrl = "https://raw.githubusercontent.com/endogh/DevTrace-cli/main/devtrace-hook.ps1"
$hookFile = "$devtraceHome\devtrace-hook.ps1"

try {
    Invoke-WebRequest -Uri $hookUrl -OutFile $hookFile
} catch {
    Write-Host "Could not download hook from GitHub" -ForegroundColor Yellow
    Write-Host "Please manually copy devtrace-hook.ps1 to $devtraceHome"
}

# =========================
# CONFIGURE POWERSHELL PROFILE
# =========================

Write-Host "Configuring PowerShell profile..." -ForegroundColor Yellow
$profilePath = $PROFILE
if (!(Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($profileContent -notmatch "devtrace-hook") {
    Add-Content -Path $profilePath -Value ""
    Add-Content -Path $profilePath -Value "# DevTrace CLI"
    Add-Content -Path $profilePath -Value ". `"$hookFile`""
    Write-Host "Added to $profilePath"
} else {
    Write-Host "Already configured in $profilePath"
}

# =========================
# DONE
# =========================

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
if ($Global) {
    Write-Host "Installed globally via pip."
} else {
    Write-Host "Installed in venv at $devtraceHome\venv\"
}
Write-Host ""
Write-Host "Usage:"
Write-Host "  cd ~/projects/your-app"
Write-Host "  devtrace start fix-bug"
Write-Host "  devtrace done"
Write-Host ""
Write-Host "Reload your profile:"
Write-Host "  . `$PROFILE"
