#!/bin/bash

# --- Git Dashboard ---
# Purpose: Git operations menu for OpenWrt builds
# Author: Derek W.

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
        echo "❌ [$label] failed (exit $status)"
        pause_screen
    fi

    return $status
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a Git repository."
    pause_screen
    exit 1
fi

get_git_header() {
    local repo branch modified staged untracked parts

    repo=$(git rev-parse --show-toplevel 2>/dev/null)
    branch=$(git branch --show-current 2>/dev/null || echo "detached")

    modified=$(git status --porcelain 2>/dev/null | grep -c '^.M' || true)
    staged=$(git status --porcelain 2>/dev/null | grep -c '^[MADRC]' || true)
    untracked=$(git status --porcelain 2>/dev/null | grep -c '^??' || true)

    parts=()
    [ "$staged" -gt 0 ]    && parts+=("${staged} staged")
    [ "$modified" -gt 0 ]  && parts+=("${modified} modified")
    [ "$untracked" -gt 0 ] && parts+=("${untracked} untracked")

    echo "📂 Repo:   $repo"
    echo "🌿 Branch: $branch"
    if [ ${#parts[@]} -eq 0 ]; then
        echo "📝 Status: ✓ clean"
    else
        echo "📝 Status: $(IFS=', '; echo "${parts[*]}")"
    fi
}

while true; do
    clear
    echo "----------- Git Dashboard -----------"
    get_git_header
    echo "-------------------------------------"
    echo "a) Status"
    echo "b) Pull Latest (--ff-only)"
    echo "c) Commit All"
    echo "d) Reset Hard (dangerous)"
    echo "e) Log (last 10 commits)"
    echo "q) Back"
    echo "-------------------------------------"
    read -r -p "Git Select: " gopt

    case $gopt in
        a)
            run_cmd "Git Status" git status
            [ $? -eq 0 ] && pause_screen
            ;;
        b)
            # Save HEAD before pull so we can show what changed
            local_head=$(git rev-parse HEAD 2>/dev/null)
            run_cmd "Git Pull" git pull --ff-only
            pull_status=$?
            if [ $pull_status -eq 0 ]; then
                new_head=$(git rev-parse HEAD 2>/dev/null)
                if [ "$local_head" != "$new_head" ]; then
                    echo ""
                    echo "--- New commits ---"
                    git log "${local_head}..HEAD" --oneline --no-walk=unsorted 2>/dev/null || \
                        git log "${local_head}..HEAD" --oneline 2>/dev/null
                else
                    echo "Already up to date."
                fi
                pause_screen
            fi
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
                    if [ $? -eq 0 ]; then
                        echo ""
                        if confirm_action "Push to remote?"; then
                            run_cmd "Git Push" git push
                            [ $? -eq 0 ] && echo "✅ Pushed successfully."
                        fi
                        pause_screen
                    fi
                fi
            fi
            ;;
        d)
            if confirm_action "This will discard ALL uncommitted changes. Continue"; then
                run_cmd "Git Hard Reset" git reset --hard HEAD
                [ $? -eq 0 ] && pause_screen
            fi
            ;;
        e)
            echo "--- Recent Commits (last 10) ---"
            git log --oneline --format="%C(yellow)%h%Creset %C(cyan)%ad%Creset  %s  %C(dim)(%an)%Creset" \
                --date=short -10 2>/dev/null || git log --oneline -10
            pause_screen
            ;;
        q) exit 0 ;;
        *)
            echo "Invalid."
            sleep 1
            ;;
    esac
done
