# DevTrace Fish Shell Hook
# Add to ~/.config/fish/config.fish:
#   source ~/.devtrace/devtrace-hook.fish

function __devtrace_chpwd --on-variable PWD
    if test -d .devtrace
        set -l session (cat .devtrace/current.txt 2>/dev/null)
        if test -n "$session"
            set -l count (ls .devtrace/*.md 2>/dev/null | wc -l)
            if test $count -gt 1
                echo -e "\e[36m[DEVTRACE] Active: $session ($count sessions available)\e[0m"
            else
                echo -e "\e[36m[DEVTRACE] Active: $session\e[0m"
            end
        end
    end
end

function __devtrace_capture_error --on-event fish_postexec
    if test $status -ne 0
        if command -q devtrace
            set -l last_cmd (history | head -1)
            devtrace error "Exit code: $status" --context "Command: $last_cmd" 2>/dev/null
        end
    end
end

function devtrace-status
    if test -d .devtrace
        set -l session (cat .devtrace/current.txt 2>/dev/null)
        if test -n "$session"
            echo -e "\e[36m[DEVTRACE] Active: $session\e[0m"
        else
            echo "[DEVTRACE] No active session"
        end
    else
        echo "[DEVTRACE] Not a devtrace project"
    end
end

function devtrace-sessions
    if test -d .devtrace
        echo "[DEVTRACE] Sessions:"
        for file in .devtrace/*.md
            set -l name (basename $file .md)
            set -l marker ""
            if test -f .devtrace/current.txt
                set -l current (cat .devtrace/current.txt)
                if test "$name" = "$current"
                    set -l marker " [ACTIVE]"
                end
            end
            echo "  - $name$marker"
        end
    else
        echo "[DEVTRACE] Not a devtrace project"
    end
end

echo -e "\e[36m[DEVTRACE] Fish hook loaded\e[0m"
