# DevTrace CLI - Windows Install Script (PowerShell)
# For Windows (PowerShell) or WSL

Write-Host "🧠 DevTrace CLI Installer" -ForegroundColor Cyan
Write-Host "========================="
Write-Host ""

# Check Python
Write-Host "[1/5] Checking Python..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "Python found: $pythonVersion"
} catch {
    Write-Host "Python not found. Please install from https://www.python.org/downloads/" -ForegroundColor Red
    Write-Host "Make sure to check 'Add Python to PATH' during installation"
    exit 1
}

# Check pip
Write-Host "[2/5] Checking pip..." -ForegroundColor Yellow
try {
    pip --version | Out-Null
} catch {
    Write-Host "Installing pip..." -ForegroundColor Yellow
    python -m ensurepip --upgrade
}

# Install devtrace
Write-Host "[3/5] Installing devtrace..." -ForegroundColor Yellow
pip install git+https://github.com/endogh/DevTrace-cli.git

# Create directories
Write-Host "[4/5] Setting up directories..." -ForegroundColor Yellow
$devtraceDir = "$env:USERPROFILE\.devtrace"
if (!(Test-Path $devtraceDir)) {
    New-Item -ItemType Directory -Path $devtraceDir | Out-Null
}

# Download shell hook
Write-Host "[5/5] Installing PowerShell hook..." -ForegroundColor Yellow
$hookUrl = "https://raw.githubusercontent.com/endogh/DevTrace-cli/main/devtrace-hook.ps1"
$hookFile = "$devtraceDir\devtrace-hook.ps1"

try {
    Invoke-WebRequest -Uri $hookUrl -OutFile $hookFile
} catch {
    Write-Host "Could not download hook from GitHub" -ForegroundColor Yellow
    Write-Host "Please manually copy devtrace-hook.ps1 to $devtraceDir"
}

# Configure PowerShell profile
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

# Done
Write-Host ""
Write-Host "✅ Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Usage:"
Write-Host "  cd ~/projects/your-app"
Write-Host "  devtrace start fix-bug"
Write-Host "  devtrace done"
Write-Host ""
Write-Host "Reload your profile:"
Write-Host "  . `$PROFILE"
