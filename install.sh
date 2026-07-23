#!/bin/bash
# DevTrace CLI - Universal Install Script
# Works on: Linux (Arch/Ubuntu/Fedora), macOS, Windows (Git Bash/WSL)

set -e

echo "🧠 DevTrace CLI Installer"
echo "========================="
echo ""

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        MINGW*|MSYS*|CYGWIN*) echo "windows";;
        *)          echo "unknown";;
    esac
}

# Detect Linux distro
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif command -v lsb_release &> /dev/null; then
        lsb_release -is | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
echo "Detected OS: $OS"

# =========================
# INSTALL DEPENDENCIES
# =========================

echo ""
echo "[1/5] Checking dependencies..."

install_python() {
    case $OS in
        linux)
            DISTRO=$(detect_distro)
            echo "Installing Python on $DISTRO..."
            case $DISTRO in
                arch|cachyos|manjaro)
                    sudo pacman -S --noconfirm python python-pip
                    ;;
                ubuntu|debian)
                    sudo apt update && sudo apt install -y python3 python3-pip
                    ;;
                fedora|rhel|centos)
                    sudo dnf install -y python3 python3-pip
                    ;;
                *)
                    echo "Please install Python 3 manually"
                    exit 1
                    ;;
            esac
            ;;
        macos)
            if command -v brew &> /dev/null; then
                brew install python3
            else
                echo "Installing Homebrew first..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                brew install python3
            fi
            ;;
        windows)
            echo "Please install Python from https://www.python.org/downloads/"
            echo "Make sure to check 'Add Python to PATH' during installation"
            exit 1
            ;;
    esac
}

# Check Python
if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
    install_python
else
    echo "Python found: $(python3 --version 2>/dev/null || python --version)"
fi

# Check pip
if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
    echo "Installing pip..."
    case $OS in
        linux)
            DISTRO=$(detect_distro)
            case $DISTRO in
                arch|cachyos|manjaro)
                    sudo pacman -S --noconfirm python-pip
                    ;;
                ubuntu|debian)
                    sudo apt install -y python3-pip
                    ;;
                fedora|rhel|centos)
                    sudo dnf install -y python3-pip
                    ;;
            esac
            ;;
        macos)
            brew install pipx || true
            ;;
    esac
fi

# Check xclip for Linux (for clipboard support)
if [ "$OS" = "linux" ]; then
    if ! command -v xclip &> /dev/null && ! command -v xsel &> /dev/null; then
        echo "Installing xclip for clipboard support..."
        DISTRO=$(detect_distro)
        case $DISTRO in
            arch|cachyos|manjaro)
                sudo pacman -S --noconfirm xclip
                ;;
            ubuntu|debian)
                sudo apt install -y xclip
                ;;
            fedora|rhel|centos)
                sudo dnf install -y xclip
                ;;
        esac
    fi
fi

# =========================
# INSTALL DEVTRACE
# =========================

echo ""
echo "[2/5] Installing devtrace..."

# Determine pip command
PIP_CMD="pip3"
command -v pip3 &> /dev/null || PIP_CMD="pip"

$PIP_CMD install git+https://github.com/endogh/DevTrace-cli.git

# =========================
# CREATE DIRECTORIES
# =========================

echo ""
echo "[3/5] Setting up directories..."
mkdir -p ~/.devtrace

# =========================
# INSTALL SHELL HOOK
# =========================

echo ""
echo "[4/5] Installing shell hook..."

# Detect shell
SHELL_NAME=$(basename "$SHELL")
case $SHELL_NAME in
    zsh)
        SHELL_CONFIG="$HOME/.zshrc"
        HOOK_FILE="devtrace-hook.sh"
        ;;
    bash)
        if [ "$OS" = "macos" ]; then
            SHELL_CONFIG="$HOME/.bash_profile"
        else
            SHELL_CONFIG="$HOME/.bashrc"
        fi
        HOOK_FILE="devtrace-hook.sh"
        ;;
    fish)
        SHELL_CONFIG="$HOME/.config/fish/config.fish"
        HOOK_FILE="devtrace-hook.fish"
        ;;
    *)
        SHELL_CONFIG="$HOME/.bashrc"
        HOOK_FILE="devtrace-hook.sh"
        ;;
esac

# Download hook
HOOK_URL="https://raw.githubusercontent.com/endogh/DevTrace-cli/main/$HOOK_FILE"
curl -sSL "$HOOK_URL" -o ~/.devtrace/$HOOK_FILE 2>/dev/null || {
    echo "Could not download hook from GitHub"
    echo "Please manually copy devtrace-hook.sh to ~/.devtrace/"
}

# =========================
# CONFIGURE SHELL
# =========================

echo ""
echo "[5/5] Configuring shell..."

# Check if already configured
if ! grep -q "devtrace-hook" "$SHELL_CONFIG" 2>/dev/null; then
    echo "" >> "$SHELL_CONFIG"
    echo "# DevTrace CLI" >> "$SHELL_CONFIG"
    
    if [ "$SHELL_NAME" = "fish" ]; then
        echo "source ~/.devtrace/devtrace-hook.fish" >> "$SHELL_CONFIG"
    else
        echo "source ~/.devtrace/$HOOK_FILE" >> "$SHELL_CONFIG"
    fi
    
    echo "Added to $SHELL_CONFIG"
else
    echo "Already configured in $SHELL_CONFIG"
fi

# =========================
# DONE
# =========================

echo ""
echo "✅ Installation complete!"
echo ""
echo "Usage:"
echo "  cd ~/projects/your-app"
echo "  devtrace start fix-bug"
echo "  devtrace done"
echo ""
echo "Reload your shell:"
if [ "$SHELL_NAME" = "fish" ]; then
    echo "  source $SHELL_CONFIG"
else
    echo "  source $SHELL_CONFIG"
fi
echo ""
echo "Or restart your terminal."
