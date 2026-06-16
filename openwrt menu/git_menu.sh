#!/bin/bash

pause_screen() {
    read -r -p "Press Enter to continue..." _
}

confirm_action() {
    local prompt="$1"
    local answer
    read -r -p "$prompt [y/N]: " answer
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

run_cmd() {
    local label="$1"
    shift

    echo "--- $label ---"
    "$@"
    local status=$?

    if [ $status -ne 0 ]; then
        echo "Command failed with exit code $status: $*"
        pause_screen
    fi

    return $status
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a Git repository."
    pause_screen
    exit 1
fi

while true; do
    clear
    echo "---------------- Git Dashboard ----------------"
    echo "a) Status"
    echo "b) Pull Latest (--ff-only)"
    echo "c) Commit All"
    echo "d) Reset Hard (dangerous)"
    echo "q) Back"
    echo "-----------------------------------------------"
    read -r -p "Git Select: " gopt

    case $gopt in
        a)
            run_cmd "Git Status" git status
            [ $? -eq 0 ] && pause_screen
            ;;
        b)
            run_cmd "Git Pull" git pull --ff-only
            [ $? -eq 0 ] && pause_screen
            ;;
        c)
            read -r -p "Message: " msg
            if [ -z "$msg" ]; then
                echo "Commit message cannot be empty."
                pause_screen
            else
                run_cmd "Git Add" git add .
                if [ $? -eq 0 ]; then
                    run_cmd "Git Commit" git commit -m "$msg"
                    [ $? -eq 0 ] && pause_screen
                fi
            fi
            ;;
        d)
            if confirm_action "This will discard ALL uncommitted changes. Continue"; then
                run_cmd "Git Hard Reset" git reset --hard HEAD
                [ $? -eq 0 ] && pause_screen
            fi
            ;;
        q) exit 0 ;;
        *)
            echo "Invalid."
            sleep 1
            ;;
    esac
done
