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
        local target subtarget
        target=$(grep -m1 '^CONFIG_TARGET_BOARD="' .config | cut -d'"' -f2)
        subtarget=$(grep -m1 '^CONFIG_TARGET_SUBTARGET="' .config | cut -d'"' -f2)
        target=${target:-unknown}
        echo "${target}/${subtarget:-unknown}"
    else
        echo "No .config found"
    fi
}

get_device_profile() {
    if [ -f ".config" ]; then
        local profile
        profile=$(grep -m1 '^CONFIG_TARGET_PROFILE="' .config | cut -d'"' -f2)
        echo "${profile:-unknown}"
    else
        echo "N/A"
    fi
}

get_config_age() {
    if [ -f ".config" ]; then
        local mod_time now diff_sec
        mod_time=$(stat -c %Y .config 2>/dev/null)
        now=$(date +%s)
        diff_sec=$(( now - mod_time ))
        if [ "$diff_sec" -lt 60 ]; then
            echo "just now"
        elif [ "$diff_sec" -lt 3600 ]; then
            echo "$(( diff_sec / 60 ))m ago"
        elif [ "$diff_sec" -lt 86400 ]; then
            echo "$(( diff_sec / 3600 ))h ago"
        else
            echo "$(( diff_sec / 86400 ))d ago"
        fi
    else
        echo "missing"
    fi
}

get_git_info() {
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local branch dirty_count
        branch=$(git branch --show-current 2>/dev/null || echo "detached")
        dirty_count=$(git status --porcelain 2>/dev/null | wc -l)
        if [ "$dirty_count" -gt 0 ]; then
            echo "🌿 $branch  ($dirty_count uncommitted)"
        else
            echo "🌿 $branch  ✓ clean"
        fi
    else
        echo "not a git repo"
    fi
}

# Print latest image info (full path, size, age) for a given target dir
show_latest_image() {
    if [ ! -d "bin/targets" ]; then
        echo "  No images yet (bin/targets/ missing)"
        return
    fi

    local latest
    latest=$(find bin/targets/ -type f \( -name "*.bin" -o -name "*.img" -o -name "*.ubi" -o -name "*.itb" \) \
        -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [ -z "$latest" ]; then
        echo "  No images found in bin/targets/"
        return
    fi

    local size mod_time now diff_sec age
    size=$(du -sh "$latest" 2>/dev/null | cut -f1)
    mod_time=$(stat -c %Y "$latest" 2>/dev/null)
    now=$(date +%s)
    diff_sec=$(( now - mod_time ))
    if [ "$diff_sec" -lt 60 ]; then
        age="just now"
    elif [ "$diff_sec" -lt 3600 ]; then
        age="$(( diff_sec / 60 ))m ago"
    elif [ "$diff_sec" -lt 86400 ]; then
        age="$(( diff_sec / 3600 ))h ago"
    else
        age="$(( diff_sec / 86400 ))d ago"
    fi

    echo "  $latest"
    echo "  Size: $size  |  Built: $age"
}

# Print all images with full paths, sizes, and mod times
list_all_images() {
    if [ ! -d "bin/targets" ]; then
        echo "Directory bin/targets/ does not exist. Please run a build first."
        return
    fi

    echo "📂 Search path: $PWD/bin/targets/"
    echo ""

    local count=0
    while IFS= read -r -d '' file; do
        local size mod_date
        size=$(du -sh "$file" 2>/dev/null | cut -f1)
        mod_date=$(stat -c '%y' "$file" 2>/dev/null | cut -d'.' -f1)
        printf "  📦 %s\n" "$file"
        printf "     Size: %-8s  Modified: %s\n" "$size" "$mod_date"
        (( count++ )) || true
    done < <(find bin/targets/ -type f \( -name "*.bin" -o -name "*.img" -o -name "*.ubi" -o -name "*.itb" \) \
        -printf '%T@ %p\0' 2>/dev/null | sort -z -n | cut -z -d' ' -f2-)

    echo ""
    if [ "$count" -eq 0 ]; then
        echo "  No compiled images found."
    else
        echo "  ✅ Found $count image(s)."
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
        echo "❌ [$label] failed (exit $status)"
        pause_screen
    fi

    return $status
}

fmt_duration() {
    local secs="$1"
    local h=$(( secs / 3600 ))
    local m=$(( (secs % 3600) / 60 ))
    local s=$(( secs % 60 ))
    if [ "$h" -gt 0 ]; then
        printf "%dh %dm %ds" "$h" "$m" "$s"
    elif [ "$m" -gt 0 ]; then
        printf "%dm %ds" "$m" "$s"
    else
        printf "%ds" "$s"
    fi
}

run_debug_build_with_log() {
    local log_path="$PWD/build_error.log"
    echo "Logging debug build to $log_path ..."

    local t_start t_end elapsed
    t_start=$(date +%s)
    make -j1 V=s > "$log_path" 2>&1
    local status=$?
    t_end=$(date +%s)
    elapsed=$(( t_end - t_start ))

    echo "⏱️  Build time: $(fmt_duration "$elapsed")"

    if [ $status -ne 0 ]; then
        echo "❌ Debug build failed."
        echo "📋 Debug log: $log_path"
        pause_screen
        return $status
    fi

    echo "✅ Debug build completed."
    echo "📋 Debug log: $log_path"
    echo ""
    echo "--- Built Images ---"
    list_all_images
    pause_screen
    return 0
}

run_custom_build() {
    local max_jobs jobs

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

    local t_start t_end elapsed
    t_start=$(date +%s)
    run_cmd "Custom Build (-j$jobs)" make -j"$jobs" V=s
    local status=$?
    t_end=$(date +%s)
    elapsed=$(( t_end - t_start ))

    echo "⏱️  Build time: $(fmt_duration "$elapsed")"

    if [ $status -eq 0 ]; then
        echo ""
        echo "--- Built Images ---"
        list_all_images
        pause_screen
    fi
    return $status
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
    echo "📂 Root:    $PWD"
    echo "🖥️  Device:  $(get_device_profile)"
    echo "🔧 Config:  $( [ -f .config ] && echo ".config present ($(get_config_age))" || echo "No .config found" )"
    echo "🌿 Branch:  $(get_git_info)"
    echo "📦 Latest:"
    show_latest_image
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
            [ $? -eq 0 ] && pause_screen
            ;;
        2) run_cmd "Menuconfig" make menuconfig ;;
        3)
            run_cmd "Defconfig" make defconfig
            [ $? -eq 0 ] && pause_screen
            ;;
        4) run_custom_build ;;
        5) run_debug_build_with_log ;;
        6)
            run_cmd "Clean" make clean
            [ $? -eq 0 ] && pause_screen
            ;;
        7)
            run_cmd "Dirclean" make dirclean
            [ $? -eq 0 ] && pause_screen
            ;;
        8)
            echo "--- Compiled Images ---"
            list_all_images
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
        d)
            run_cmd "Download Sources" make download -j"$(nproc)"
            [ $? -eq 0 ] && pause_screen
            ;;
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
