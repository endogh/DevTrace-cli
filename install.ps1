# DevTrace CLI - Windows Install Script (PowerShell)
# For Windows (PowerShell) or WSL
#
# Usage:
#   .\install.ps1            # Install into active/project venv (fallback: ~/.devtrace/venv)
#   .\install.ps1 -Yes       # Skip confirmation prompt
#   .\install.ps1 -Global    # Install globally via pip

param(
    [switch]$Global,
    [switch]$Yes
)

Write-Host "DevTrace CLI Installer" -ForegroundColor Cyan
Write-Host "========================="
Write-Host ""

# =========================
# DETECT TARGET
# =========================

$devtraceHome = "$env:USERPROFILE\.devtrace"

function Get-VenvPip {
    param([string]$VenvDir)
    if (Test-Path "$VenvDir\Scripts\pip.exe") { return "$VenvDir\Scripts\pip.exe" }
    if (Test-Path "$VenvDir\bin\pip") { return "$VenvDir\bin\pip" }
    return ""
}

$TargetMode = ""
$TargetDir = ""
$TargetPip = ""

if ($Global) {
    $TargetMode = "global"
} elseif ($env:VIRTUAL_ENV -and (Get-VenvPip $env:VIRTUAL_ENV)) {
    $TargetMode = "venv_active"
    $TargetDir = $env:VIRTUAL_ENV
    $TargetPip = Get-VenvPip $env:VIRTUAL_ENV
} elseif (Get-VenvPip "$PWD\.venv") {
    $TargetMode = "venv_project"
    $TargetDir = "$PWD\.venv"
    $TargetPip = Get-VenvPip "$PWD\.venv"
} else {
    $TargetMode = "venv_fallback"
    $TargetDir = "$devtraceHome\venv"
}

# =========================
# CHECK PYTHON
# =========================

try {
    $pythonVersion = python --version 2>&1
    Write-Host "Python found: $pythonVersion" -ForegroundColor Yellow
} catch {
    Write-Host "Python not found. Please install from https://www.python.org/downloads/" -ForegroundColor Red
    Write-Host "Make sure to check 'Add Python to PATH' during installation"
    exit 1
}

# =========================
# SUMMARY + CONFIRM
# =========================

$TargetLabel = switch ($TargetMode) {
    "global"        { "global (pip)" }
    "venv_active"   { "venv aktif: $TargetDir" }
    "venv_project"  { "venv proyek: $TargetDir" }
    "venv_fallback" { "fallback: $devtraceHome\venv (akan dibuat)" }
}

Write-Host ""
Write-Host "Rencana instalasi:"
Write-Host "  Target install  : $TargetLabel"
Write-Host "  Yang di-install :"
Write-Host "    - devtrace (git+https://github.com/endogh/DevTrace-cli.git)"
Write-Host "    - dependensi: click, rich, colorama, python-slugify,"
Write-Host "                  Pygments, markdown-it-py, requests"
if ($TargetMode -eq "venv_fallback") {
    Write-Host "    - venv BARU di $devtraceHome\venv"
}
Write-Host "  Shell hook      : devtrace-hook.ps1 -> $devtraceHome\ + edit PowerShell profile"
Write-Host ""

if (-not $Yes) {
    try {
        $answer = Read-Host "[?] Lanjutkan instalasi? [y/N]"
    } catch {
        Write-Host "[!] Tidak ada input interaktif. Jalankan dengan -Yes untuk skip konfirmasi." -ForegroundColor Red
        exit 1
    }
    if ($answer -notmatch "^(y|yes)$") {
        Write-Host "[!] Instalasi dibatalkan."
        exit 1
    }
}

# =========================
# [1/4] INSTALL DEVTRACE
# =========================

Write-Host ""
Write-Host "[1/4] Installing devtrace..." -ForegroundColor Yellow

$repoUrl = "git+https://github.com/endogh/DevTrace-cli.git"

switch ($TargetMode) {
    "global" {
        pip install --upgrade $repoUrl
    }
    "venv_active" {
        Write-Host "Installing into $TargetDir ..."
        & $TargetPip install --upgrade $repoUrl
    }
    "venv_project" {
        Write-Host "Installing into $TargetDir ..."
        & $TargetPip install --upgrade $repoUrl
    }
    "venv_fallback" {
        Write-Host "Creating virtual environment at $devtraceHome\venv..."
        python -m venv "$devtraceHome\venv"

        $TargetPip = Get-VenvPip "$devtraceHome\venv"
        Write-Host "Installing devtrace in venv..."
        & $TargetPip install --upgrade $repoUrl

        # Add fallback venv Scripts to user PATH
        $venvBin = "$devtraceHome\venv\Scripts"
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

        if ($currentPath -notlike "*devtrace*venv*") {
            $newPath = "$venvBin;$currentPath"
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            $env:Path = "$venvBin;$env:Path"
            Write-Host "Added venv to user PATH" -ForegroundColor Green
        }
    }
}

# =========================
# [2/4] CREATE DIRECTORIES
# =========================

Write-Host ""
Write-Host "[2/4] Setting up directories..." -ForegroundColor Yellow
if (!(Test-Path $devtraceHome)) {
    New-Item -ItemType Directory -Path $devtraceHome | Out-Null
}

# =========================
# [3/4] DOWNLOAD SHELL HOOK
# =========================

Write-Host ""
Write-Host "[3/4] Installing PowerShell hook..." -ForegroundColor Yellow
$hookUrl = "https://raw.githubusercontent.com/endogh/DevTrace-cli/main/devtrace-hook.ps1"
$hookFile = "$devtraceHome\devtrace-hook.ps1"

try {
    Invoke-WebRequest -Uri $hookUrl -OutFile $hookFile
} catch {
    Write-Host "Could not download hook from GitHub" -ForegroundColor Yellow
    Write-Host "Please manually copy devtrace-hook.ps1 to $devtraceHome"
}

# =========================
# [4/4] CONFIGURE POWERSHELL PROFILE
# =========================

Write-Host ""
Write-Host "[4/4] Configuring PowerShell profile..." -ForegroundColor Yellow
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
switch ($TargetMode) {
    "global"        { Write-Host "Installed globally via pip." }
    "venv_active"   { Write-Host "Installed into active venv: $TargetDir" }
    "venv_project"  { Write-Host "Installed into project venv: $TargetDir" }
    "venv_fallback" { Write-Host "Installed in venv at $devtraceHome\venv\" }
}
Write-Host ""
Write-Host "Usage:"
Write-Host "  cd ~/projects/your-app"
Write-Host "  devtrace start fix-bug"
Write-Host "  devtrace done"
Write-Host ""
Write-Host "Reload your profile:"
Write-Host "  . `$PROFILE"
Write-Host ""

# =========================
# VERIFY
# =========================

$devtraceCmd = Get-Command devtrace -ErrorAction SilentlyContinue
if ($devtraceCmd) {
    Write-Host "devtrace tersedia di: $($devtraceCmd.Source)"
    if ($TargetMode -in @("venv_active", "venv_project")) {
        $expected = "$TargetDir\Scripts\devtrace.exe"
        if ($devtraceCmd.Source -ne $expected) {
            Write-Host "[!] Warning: 'devtrace' di PATH = $($devtraceCmd.Source)" -ForegroundColor Yellow
            Write-Host "    Bukan dari $TargetDir. Periksa urutan PATH." -ForegroundColor Yellow
        }
    }
}
