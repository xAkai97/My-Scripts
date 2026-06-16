#!/bin/bash

# --- OpenWrt Build Menu ---
# Purpose: Streamline OpenWrt builds on WSL
# Author: Derek W.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- OpenWrt Root Finder ---
# This allows you to run 'openwrt' from any subfolder.
find_wrt_root() {
    local current="$PWD"

    while [ "$current" != "/" ]; do
        if [ -f "$current/scripts/feeds" ]; then
            cd "$current" || return 1
            return 0
        fi
        current=$(dirname "$current")
    done

    return 1
}

if ! find_wrt_root; then
    echo "❌ Error: Could not find OpenWrt root (missing scripts/feeds)."
    exit 1
fi

# --- Helper: Get Build Info ---
get_target() {
    if [ -f ".config" ]; then
        # Parse first exact key match from .config.
        local target
        local subtarget

        target=$(grep -m1 '^CONFIG_TARGET_BOARD="' .config | cut -d'"' -f2)
        subtarget=$(grep -m1 '^CONFIG_TARGET_SUBTARGET="' .config | cut -d'"' -f2)

        target=${target:-unknown}
        echo "${target}/${subtarget:-unknown}"
    else
        echo "No .config found"
    fi
}

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

run_debug_build_with_log() {
    echo "Logging debug build to build_error.log..."
    make -j1 V=s > build_error.log 2>&1
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Debug build failed. See build_error.log for details."
        pause_screen
        return $status
    fi

    echo "Debug build completed. Log saved to build_error.log."
    pause_screen
    return 0
}

run_custom_build() {
    local max_jobs
    local jobs

    max_jobs=$(nproc)
    echo "Custom Build"
    echo "a) Use all available cores (-j$max_jobs)"
    echo "c) Choose a core count (1-$max_jobs)"
    read -r -p "Build mode [a/c]: " build_mode

    case "$build_mode" in
        a|A)
            jobs="$max_jobs"
            ;;
        c|C)
            read -r -p "Enter jobs (1-$max_jobs): " jobs
            if ! [[ "$jobs" =~ ^[0-9]+$ ]] || [ "$jobs" -lt 1 ] || [ "$jobs" -gt "$max_jobs" ]; then
                echo "Invalid jobs value. Must be a number between 1 and $max_jobs."
                pause_screen
                return 1
            fi
            ;;
        *)
            echo "Invalid build mode selection."
            pause_screen
            return 1
            ;;
    esac

    run_cmd "Custom Build (-j$jobs)" make -j"$jobs" V=s
}

run_automated_pipeline() {
    echo "--- Automated Pipeline (1 -> 3 -> d -> 3) ---"

    run_cmd "Update Feeds" ./scripts/feeds update -a || {
        echo "Pipeline stopped: step failed -> Update Feeds"
        return 1
    }
    run_cmd "Install Feeds" ./scripts/feeds install -a || {
        echo "Pipeline stopped: step failed -> Install Feeds"
        return 1
    }
    run_cmd "Defconfig (Pass 1)" make defconfig || {
        echo "Pipeline stopped: step failed -> Defconfig (Pass 1)"
        return 1
    }
    run_cmd "Download Sources" make download -j"$(nproc)" || {
        echo "Pipeline stopped: step failed -> Download Sources"
        return 1
    }
    run_cmd "Defconfig (Pass 2)" make defconfig || {
        echo "Pipeline stopped: step failed -> Defconfig (Pass 2)"
        return 1
    }

    echo "Pipeline steps complete."
    echo "Choose build mode:"
    echo "4) Custom Build (use nproc or choose 1-$(nproc))"
    echo "5) Debug Build (-j1, log -> build_error.log)"
    echo "s) Skip Build"
    read -r -p "Build Select [4/5/s]: " build_opt

    case "$build_opt" in
        4)
            if confirm_action "Run Custom Build now"; then
                run_custom_build
            fi
            ;;
        5)
            if confirm_action "Run Debug Build now"; then
                run_debug_build_with_log
            fi
            ;;
        s|S)
            echo "Build skipped."
            pause_screen
            ;;
        *)
            echo "Invalid build selection."
            pause_screen
            ;;
    esac
}

# --- Menus ---
while true; do
    clear
    echo "------------------------------------------------"
    echo "🛠️  OPENWRT DASHBOARD | Target: $(get_target)"
    echo "📂 Root: $PWD"
    echo "------------------------------------------------"
    echo "0) Auto Pipeline (1 -> 3 -> d -> 3 -> choose 4/5)"
    echo "------------------------------------------------"
    echo "1) Update & Install Feeds"
    echo "2) Menuconfig (UI)"
    echo "3) Defconfig (Check Dependencies)"
    echo "4) Custom Build (nproc or 1-$(nproc))"
    echo "5) Debug Build (-j1, save log)"
    echo "6) Clean (make clean)"
    echo "7) Nuke (dirclean)"
    echo "8) Find Compiled Images"
    echo "9) Fix WSL Permissions"
    echo "d) Download Sources (make download -j$(nproc))"
    echo "------------------------------------------------"
    echo "g) Git Menu"
    echo "------------------------------------------------"
    echo "q) Quit"
    echo "------------------------------------------------"
    read -r -p "Select: " opt

    case $opt in
        0) run_automated_pipeline ;;
        1)
            run_cmd "Update Feeds" ./scripts/feeds update -a
            [ $? -eq 0 ] && run_cmd "Install Feeds" ./scripts/feeds install -a
            ;;
        2) run_cmd "Menuconfig" make menuconfig ;;
        3) run_cmd "Defconfig" make defconfig ;;
        4) run_custom_build ;;
        5) run_debug_build_with_log ;;
        6) run_cmd "Clean" make clean ;;
        7) run_cmd "Dirclean" make dirclean ;;
        8)
            echo "Recent Images:"
            find bin/targets/ -type f \( -name "*.bin" -o -name "*.img" \) -mmin -120
            pause_screen
            ;;
        9)
            if confirm_action "Fix ownership/permissions on build output dirs (bin build_dir staging_dir tmp)?"; then
                dirs=()
                for dir in bin build_dir staging_dir tmp; do
                    [ -e "$dir" ] && dirs+=("$dir")
                done

                if [ ${#dirs[@]} -eq 0 ]; then
                    echo "No build output directories found to fix."
                    pause_screen
                else
                    run_cmd "Fix Ownership" sudo chown -R "$USER:$USER" "${dirs[@]}"
                    [ $? -eq 0 ] && run_cmd "Fix Permissions" chmod -R u+rw "${dirs[@]}"
                fi
            fi
            ;;
        d) run_cmd "Download Sources" make download -j"$(nproc)" ;;
        g)
            if [ -x "$SCRIPT_DIR/git_menu.sh" ]; then
                "$SCRIPT_DIR/git_menu.sh"
            elif [ -f "$SCRIPT_DIR/git_menu.sh" ]; then
                bash "$SCRIPT_DIR/git_menu.sh"
            else
                echo "Git menu script not found: $SCRIPT_DIR/git_menu.sh"
                pause_screen
            fi
            ;;
        q) exit 0 ;;
        *) echo "Invalid." ; sleep 1 ;;
    esac
done
