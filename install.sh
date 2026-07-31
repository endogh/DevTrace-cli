#!/bin/bash
# DevTrace CLI - Universal Install Script
# Works on: Linux (Arch/Ubuntu/Fedora), macOS, Windows (Git Bash/WSL)
#
# Usage:
#   install.sh          # Install in venv (default)
#   install.sh -g       # Install globally (pipx on Arch, pip elsewhere)

set -e

# =========================
# PARSE ARGUMENTS
# =========================

GLOBAL=false

while [ $# -gt 0 ]; do
    case "$1" in
        -g|--global)
            GLOBAL=true
            shift
            ;;
        -h|--help)
            echo "Usage: install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -g, --global    Install globally (uses pipx on Arch, pip elsewhere)"
            echo "  -h, --help      Show this help"
            echo ""
            echo "Default: Install in a virtual environment at ~/.devtrace/venv/"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage info"
            exit 1
            ;;
    esac
done

if [ "$GLOBAL" = true ]; then
    echo "DevTrace CLI Installer (global)"
else
    echo "DevTrace CLI Installer (venv)"
fi
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
DISTRO="unknown"
if [ "$OS" = "linux" ]; then
    DISTRO=$(detect_distro)
fi
echo "Detected OS: $OS ($DISTRO)"

# =========================
# INSTALL DEPENDENCIES
# =========================

echo ""
echo "[1/5] Checking dependencies..."

install_python() {
    case $OS in
        linux)
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

# Determine python command
PYTHON_CMD="python3"
command -v python3 &> /dev/null || PYTHON_CMD="python"

# For global mode, ensure pipx is available (Arch) or pip (others)
if [ "$GLOBAL" = true ]; then
    case $DISTRO in
        arch|cachyos|manjaro)
            # Arch recommends pipx for global CLI tools
            if ! command -v pipx &> /dev/null; then
                echo "Installing pipx..."
                sudo pacman -S --noconfirm python-pipx
            fi
            # Ensure pipx PATH is in profile
            if ! grep -q "pipx" "$HOME/.bashrc" 2>/dev/null && ! grep -q "pipx" "$HOME/.zshrc" 2>/dev/null; then
                eval "$PYTHON_CMD -m pipx ensurepath" 2>/dev/null || true
            fi
            ;;
        *)
            # Other distros: check pip
            if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
                echo "Installing pip..."
                case $DISTRO in
                    ubuntu|debian)
                        sudo apt install -y python3-pip
                        ;;
                    fedora|rhel|centos)
                        sudo dnf install -y python3-pip
                        ;;
                    macos)
                        brew install pipx || true
                        ;;
                esac
            fi
            ;;
    esac
fi

# Check xclip for Linux (for clipboard support)
if [ "$OS" = "linux" ]; then
    if ! command -v xclip &> /dev/null && ! command -v xsel &> /dev/null; then
        echo "Installing xclip for clipboard support..."
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

if [ "$GLOBAL" = true ]; then
    case $DISTRO in
        arch|cachyos|manjaro)
            echo "Installing via pipx..."
            pipx install git+https://github.com/endogh/DevTrace-cli.git
            ;;
        *)
            PIP_CMD="pip3"
            command -v pip3 &> /dev/null || PIP_CMD="pip"
            $PIP_CMD install --upgrade --user git+https://github.com/endogh/DevTrace-cli.git 2>/dev/null || {
                echo "pip install failed (externally-managed environment?)."
                echo "Try running without -g to install in a venv instead,"
                echo "or install pipx and use: pipx install git+https://github.com/endogh/DevTrace-cli.git"
                exit 1
            }
            ;;
    esac
else
    DEVTRACE_HOME="$HOME/.devtrace"
    VENV_DIR="$DEVTRACE_HOME/venv"
    mkdir -p "$DEVTRACE_HOME"

    echo "Creating virtual environment at $VENV_DIR..."
    $PYTHON_CMD -m venv "$VENV_DIR"

    VENV_PIP="$VENV_DIR/bin/pip"
    if [ ! -x "$VENV_PIP" ]; then
        VENV_PIP="$VENV_DIR/Scripts/pip.exe"
    fi

    echo "Installing devtrace in venv..."
    "$VENV_PIP" install --upgrade git+https://github.com/endogh/DevTrace-cli.git
fi

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

    echo "Added shell hook to $SHELL_CONFIG"
else
    echo "Shell hook already configured in $SHELL_CONFIG"
fi

# For venv mode, add venv bin to PATH
if [ "$GLOBAL" = false ]; then
    VENV_PATH_ENTRY="$HOME/.devtrace/venv/bin"

    if [ "$SHELL_NAME" = "fish" ]; then
        if ! grep -q "devtrace/venv/bin" "$SHELL_CONFIG" 2>/dev/null; then
            echo "set -gx PATH $VENV_PATH_ENTRY \$PATH" >> "$SHELL_CONFIG"
            echo "Added venv to PATH in $SHELL_CONFIG"
        fi
    else
        if ! grep -q "devtrace/venv/bin" "$SHELL_CONFIG" 2>/dev/null; then
            echo "export PATH=\"$VENV_PATH_ENTRY:\$PATH\"" >> "$SHELL_CONFIG"
            echo "Added venv to PATH in $SHELL_CONFIG"
        fi
    fi
fi

# =========================
# DONE
# =========================

echo ""
echo "Installation complete!"
echo ""
if [ "$GLOBAL" = true ]; then
    echo "Installed globally (pipx on Arch, pip elsewhere)."
else
    echo "Installed in venv at ~/.devtrace/venv/"
fi
echo ""
echo "Usage:"
echo "  cd ~/projects/your-app"
echo "  devtrace start fix-bug"
echo "  devtrace done"
echo ""
echo "Reload your shell:"
echo "  source $SHELL_CONFIG"
echo ""
echo "Or restart your terminal."
