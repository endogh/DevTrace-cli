#!/bin/bash
# DevTrace CLI - Universal Install Script
# Works on: Linux (Arch/Ubuntu/Fedora), macOS, Windows (Git Bash/WSL)
#
# Usage:
#   install.sh            # Install into active/project venv (fallback: ~/.devtrace/venv)
#   install.sh -y         # Skip confirmation prompt
#   install.sh -g         # Install globally (pipx on Arch, pip elsewhere)

set -e

# =========================
# PARSE ARGUMENTS
# =========================

GLOBAL=false
ASSUME_YES=false

while [ $# -gt 0 ]; do
    case "$1" in
        -g|--global)
            GLOBAL=true
            shift
            ;;
        -y|--yes)
            ASSUME_YES=true
            shift
            ;;
        -h|--help)
            echo "Usage: install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -g, --global    Install globally (uses pipx on Arch, pip elsewhere)"
            echo "  -y, --yes       Skip confirmation prompt"
            echo "  -h, --help      Show this help"
            echo ""
            echo "Default: Install into the active venv, then project .venv,"
            echo "         else fallback to ~/.devtrace/venv/"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage info"
            exit 1
            ;;
    esac
done

echo "DevTrace CLI Installer"
echo "========================="
echo ""

# =========================
# DETECT SYSTEM
# =========================

detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        MINGW*|MSYS*|CYGWIN*) echo "windows";;
        *)          echo "unknown";;
    esac
}

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
# DETECT DEPENDENCIES (no install yet)
# =========================

NEED_PYTHON=false
if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
    NEED_PYTHON=true
else
    echo "Python found: $(python3 --version 2>/dev/null || python --version)"
fi

PYTHON_CMD="python3"
command -v python3 &> /dev/null || PYTHON_CMD="python"

NEED_PIPX=false
NEED_PIP=false
if [ "$GLOBAL" = true ]; then
    case $DISTRO in
        arch|cachyos|manjaro)
            if ! command -v pipx &> /dev/null; then
                NEED_PIPX=true
            fi
            ;;
        *)
            if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
                NEED_PIP=true
            fi
            ;;
    esac
fi

NEED_XCLIP=false
if [ "$OS" = "linux" ]; then
    if ! command -v xclip &> /dev/null && ! command -v xsel &> /dev/null; then
        NEED_XCLIP=true
    fi
fi

# =========================
# DETECT SHELL CONFIG
# =========================

SHELL_NAME=$(basename "${SHELL:-bash}")
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

# =========================
# DETERMINE TARGET
# =========================

venv_pip() {
    if [ -x "$1/bin/pip" ]; then
        echo "$1/bin/pip"
    elif [ -x "$1/Scripts/pip.exe" ]; then
        echo "$1/Scripts/pip.exe"
    else
        echo ""
    fi
}

TARGET_MODE="global"
TARGET_DIR=""
TARGET_PIP=""
TARGET_LABEL=""

if [ "$GLOBAL" = true ]; then
    TARGET_MODE="global"
    TARGET_LABEL="global (pipx/pip sistem)"
else
    if [ -n "$VIRTUAL_ENV" ] && [ -n "$(venv_pip "$VIRTUAL_ENV")" ]; then
        TARGET_MODE="venv_active"
        TARGET_DIR="$VIRTUAL_ENV"
        TARGET_PIP="$(venv_pip "$VIRTUAL_ENV")"
        TARGET_LABEL="venv aktif: $VIRTUAL_ENV"
    elif [ -n "$(venv_pip "$PWD/.venv")" ]; then
        TARGET_MODE="venv_project"
        TARGET_DIR="$PWD/.venv"
        TARGET_PIP="$(venv_pip "$PWD/.venv")"
        TARGET_LABEL="venv proyek: $PWD/.venv"
    else
        TARGET_MODE="venv_fallback"
        TARGET_DIR="$HOME/.devtrace/venv"
        TARGET_PIP=""
        TARGET_LABEL="fallback: ~/.devtrace/venv (akan dibuat)"
    fi
fi

# =========================
# SUMMARY + CONFIRM
# =========================

echo ""
echo "Rencana instalasi:"
echo "  Target install  : $TARGET_LABEL"
echo "  Yang di-install :"
echo "    - devtrace (git+https://github.com/endogh/DevTrace-cli.git)"
echo "    - dependensi: click, rich, colorama, python-slugify,"
echo "                  Pygments, markdown-it-py, requests"
if [ "$NEED_PYTHON" = true ]; then
    echo "    - python3 + pip (paket sistem: $DISTRO)"
fi
if [ "$NEED_PIPX" = true ]; then
    echo "    - pipx (paket sistem)"
fi
if [ "$NEED_PIP" = true ]; then
    echo "    - pip (paket sistem)"
fi
if [ "$NEED_XCLIP" = true ]; then
    echo "    - xclip (paket sistem, untuk clipboard)"
fi
if [ "$TARGET_MODE" = "venv_fallback" ]; then
    echo "    - venv BARU di $TARGET_DIR"
fi
echo "  Shell hook      : $HOOK_FILE -> ~/.devtrace/ + edit $SHELL_CONFIG"
echo ""

confirm() {
    [ "$ASSUME_YES" = true ] && return 0
    local answer=""
    if [ -e /dev/tty ]; then
        read -r -p "[?] Lanjutkan instalasi? [y/N] " answer 2>/dev/null < /dev/tty || answer=""
    elif [ -t 0 ]; then
        read -r -p "[?] Lanjutkan instalasi? [y/N] " answer 2>/dev/null || answer=""
    else
        echo "[!] Tidak ada TTY. Jalankan dengan -y untuk skip konfirmasi." >&2
        return 1
    fi
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) echo "[!] Instalasi dibatalkan."; return 1 ;;
    esac
}

if ! confirm; then
    exit 1
fi

# =========================
# [1/5] INSTALL SYSTEM DEPENDENCIES (jika perlu)
# =========================

echo ""
echo "[1/5] Installing sistem dependencies..."

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

if [ "$NEED_PYTHON" = true ]; then
    install_python
fi

if [ "$GLOBAL" = true ]; then
    case $DISTRO in
        arch|cachyos|manjaro)
            if [ "$NEED_PIPX" = true ]; then
                echo "Installing pipx..."
                sudo pacman -S --noconfirm python-pipx
            fi
            if ! grep -q "pipx" "$HOME/.bashrc" 2>/dev/null && ! grep -q "pipx" "$HOME/.zshrc" 2>/dev/null; then
                eval "$PYTHON_CMD -m pipx ensurepath" 2>/dev/null || true
            fi
            ;;
        *)
            if [ "$NEED_PIP" = true ]; then
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

if [ "$NEED_XCLIP" = true ]; then
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

# =========================
# [2/5] INSTALL DEVTRACE
# =========================

echo ""
echo "[2/5] Installing devtrace..."

REPO_URL="git+https://github.com/endogh/DevTrace-cli.git"

case $TARGET_MODE in
    global)
        case $DISTRO in
            arch|cachyos|manjaro)
                if pipx list 2>/dev/null | grep -q "devtrace"; then
                    echo "devtrace sudah terpasang via pipx, meng-upgrade..."
                    pipx install --force --pip-args=--force-reinstall "$REPO_URL"
                else
                    echo "Installing via pipx..."
                    pipx install "$REPO_URL"
                fi
                ;;
            *)
                PIP_CMD="pip3"
                command -v pip3 &> /dev/null || PIP_CMD="pip"
                $PIP_CMD install --upgrade --user "$REPO_URL" 2>/dev/null || {
                    echo "pip install gagal (kemungkinan: environment externally-managed / PEP 668)."
                    echo ""
                    echo "Solusi (pilih salah satu):"
                    echo "  1. Install via pipx:     pipx install --force git+https://github.com/endogh/DevTrace-cli.git"
                    echo "  2. Pakai venv:           jalankan install.sh tanpa -g di dalam venv proyek"
                    echo "  3. Paksa pip:            pip install --upgrade --user --break-system-packages git+https://github.com/endogh/DevTrace-cli.git"
                    exit 1
                }
                ;;
        esac
        ;;
    venv_active|venv_project)
        echo "Installing into $TARGET_DIR ..."
        "$TARGET_PIP" install --upgrade "$REPO_URL"
        ;;
    venv_fallback)
        mkdir -p "$HOME/.devtrace"
        echo "Creating virtual environment at $TARGET_DIR..."
        $PYTHON_CMD -m venv "$TARGET_DIR"
        TARGET_PIP="$(venv_pip "$TARGET_DIR")"
        echo "Installing devtrace in venv..."
        "$TARGET_PIP" install --upgrade "$REPO_URL"
        ;;
esac

# =========================
# [3/5] SETUP DIRECTORIES
# =========================

echo ""
echo "[3/5] Setting up directories..."
mkdir -p ~/.devtrace

# =========================
# [4/5] INSTALL SHELL HOOK
# =========================

echo ""
echo "[4/5] Installing shell hook..."

HOOK_URL="https://raw.githubusercontent.com/endogh/DevTrace-cli/main/$HOOK_FILE"
curl -sSL "$HOOK_URL" -o ~/.devtrace/$HOOK_FILE 2>/dev/null || {
    echo "Could not download hook from GitHub"
    echo "Please manually copy devtrace-hook.sh to ~/.devtrace/"
}

# =========================
# [5/5] CONFIGURE SHELL
# =========================

echo ""
echo "[5/5] Configuring shell..."

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

# Tambah PATH fallback (~/.devtrace/venv/bin) hanya untuk mode fallback
if [ "$TARGET_MODE" = "venv_fallback" ]; then
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
case $TARGET_MODE in
    global)
        echo "Installed globally (pipx on Arch, pip elsewhere)."
        ;;
    venv_active|venv_project)
        echo "Installed into venv: $TARGET_DIR"
        echo "Pastikan venv ini aktif saat memakai devtrace."
        ;;
    venv_fallback)
        echo "Installed in venv at ~/.devtrace/venv/"
        ;;
esac
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

# =========================
# VERIFY PATH
# =========================

echo ""
DEVTRACE_BIN="$(command -v devtrace 2>/dev/null || true)"
if [ -n "$DEVTRACE_BIN" ]; then
    case $TARGET_MODE in
        venv_active|venv_project)
            EXPECTED="$TARGET_DIR/bin/devtrace"
            if [ -x "$TARGET_DIR/Scripts/devtrace.exe" ]; then
                EXPECTED="$TARGET_DIR/Scripts/devtrace.exe"
            fi
            if [ "$DEVTRACE_BIN" != "$EXPECTED" ]; then
                echo "[!] Warning: 'devtrace' di PATH saat ini = $DEVTRACE_BIN"
                echo "    Bukan dari $TARGET_DIR."
                echo "    Aktifkan venv ini (source $TARGET_DIR/bin/activate) atau periksa urutan PATH."
            fi
            ;;
        venv_fallback)
            if [ "$DEVTRACE_BIN" != "$HOME/.devtrace/venv/bin/devtrace" ]; then
                echo "[!] Warning: 'devtrace' di PATH saat ini = $DEVTRACE_BIN"
                echo "    Bukan ~/.devtrace/venv/bin/devtrace. Periksa urutan PATH."
            fi
            ;;
    esac
fi
