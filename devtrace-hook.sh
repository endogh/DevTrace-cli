#!/bin/bash
# DevTrace Shell Hook - Bash/Zsh
# Add to ~/.bashrc or ~/.zshrc:
#   source ~/.devtrace/devtrace-hook.sh

# Colors
DEVTRACE_CYAN='\033[36m'
DEVTRACE_RESET='\033[0m'

# Auto-detect project session on directory change
__devtrace_chpwd() {
    if [ -d ".devtrace" ]; then
        local session=$(cat .devtrace/current.txt 2>/dev/null)
        if [ -n "$session" ]; then
            local count=$(ls .devtrace/*.md 2>/dev/null | wc -l)
            if [ "$count" -gt 1 ]; then
                echo -e "${DEVTRACE_CYAN}[DEVTRACE] Active: $session ($count sessions available)${DEVTRACE_RESET}"
            else
                echo -e "${DEVTRACE_CYAN}[DEVTRACE] Active: $session${DEVTRACE_RESET}"
            fi
        fi
    fi
}

# Capture error from last command
__devtrace_capture_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        # Check if devtrace is available
        if command -v devtrace &> /dev/null; then
            local last_cmd=$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')
            devtrace error "Exit code: $exit_code" --context "Command: $last_cmd" 2>/dev/null
        fi
    fi
}

# Wrapper for cd command
devtrace-cd() {
    builtin cd "$@"
    __devtrace_chpwd
}

# Override cd
alias cd=devtrace-cd

# Set up hooks based on shell type
if [ -n "$ZSH_VERSION" ]; then
    # Zsh
    chpwd_functions+=(__devtrace_chpwd)
    precmd_functions+=(__devtrace_capture_error)
elif [ -n "$BASH_VERSION" ]; then
    # Bash
    __devtrace_bash_prompt() {
        __devtrace_capture_error
    }
    PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;} __devtrace_bash_prompt"
    trap '__devtrace_chpwd' DEBUG
fi

# Manual functions
devtrace-status() {
    if [ -d ".devtrace" ]; then
        local session=$(cat .devtrace/current.txt 2>/dev/null)
        if [ -n "$session" ]; then
            echo -e "${DEVTRACE_CYAN}[DEVTRACE] Active: $session${DEVTRACE_RESET}"
        else
            echo "[DEVTRACE] No active session"
        fi
    else
        echo "[DEVTRACE] Not a devtrace project (no .devtrace/ directory)"
    fi
}

devtrace-sessions() {
    if [ -d ".devtrace" ]; then
        echo "[DEVTRACE] Sessions:"
        ls .devtrace/*.md 2>/dev/null | while read file; do
            local name=$(basename "$file" .md)
            local marker=""
            if [ -f ".devtrace/current.txt" ]; then
                local current=$(cat .devtrace/current.txt)
                if [ "$name" = "$current" ]; then
                    marker=" [ACTIVE]"
                fi
            fi
            echo "  - $name$marker"
        done
    else
        echo "[DEVTRACE] Not a devtrace project"
    fi
}

echo -e "${DEVTRACE_CYAN}[DEVTRACE] Shell hook loaded${DEVTRACE_RESET}"
