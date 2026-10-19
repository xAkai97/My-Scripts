#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/openwrt_menu.sh"
GIT_SCRIPT="$SCRIPT_DIR/git_menu.sh"
DEFAULT_BIN_DIR="$HOME/.local/bin"
DEFAULT_SHELL_RC="$HOME/.bashrc"

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Installs OpenWrt menu scripts by making them executable.
Optionally creates a launcher symlink.

Options:
  --link                 Create launcher symlink at ~/.local/bin/menu
  --bin-dir <path>       Custom directory for launcher symlink (requires --link)
  --launcher <name>      Custom launcher filename (default: menu)
  --add-path             Append PATH export to shell rc file if needed (requires --link)
  --shell-rc <path>      Shell rc file to edit with --add-path (default: ~/.bashrc)
  -f, --force            Overwrite existing launcher file/symlink
  -h, --help             Show this help message

Examples:
  ./install.sh
  ./install.sh --link
  ./install.sh --link --add-path
  ./install.sh --link --bin-dir "$HOME/bin" --launcher menu -f
EOF
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

link_enabled=false
add_path=false
force=false
bin_dir="$DEFAULT_BIN_DIR"
launcher_name="menu"
shell_rc="$DEFAULT_SHELL_RC"

while [ $# -gt 0 ]; do
    case "$1" in
        --link)
            link_enabled=true
            ;;
        --bin-dir)
            shift
            [ $# -gt 0 ] || fail "Missing value for --bin-dir"
            bin_dir="$1"
            ;;
        --launcher)
            shift
            [ $# -gt 0 ] || fail "Missing value for --launcher"
            launcher_name="$1"
            ;;
        --add-path)
            add_path=true
            ;;
        --shell-rc)
            shift
            [ $# -gt 0 ] || fail "Missing value for --shell-rc"
            shell_rc="$1"
            ;;
        -f|--force)
            force=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            ;;
    esac
    shift
done

if [ "$add_path" = true ] && [ "$link_enabled" != true ]; then
    fail "--add-path requires --link"
fi

[ -f "$MAIN_SCRIPT" ] || fail "Missing $MAIN_SCRIPT"
[ -f "$GIT_SCRIPT" ] || fail "Missing $GIT_SCRIPT"

chmod +x "$MAIN_SCRIPT" "$GIT_SCRIPT"
echo "Made executable:"
echo "- $MAIN_SCRIPT"
echo "- $GIT_SCRIPT"

if [ "$link_enabled" = true ]; then
    mkdir -p "$bin_dir"
    launcher_path="$bin_dir/$launcher_name"

    if [ -e "$launcher_path" ] || [ -L "$launcher_path" ]; then
        if [ "$force" = true ]; then
            rm -f "$launcher_path"
        else
            fail "Launcher already exists: $launcher_path (use --force to overwrite)"
        fi
    fi

    ln -s "$MAIN_SCRIPT" "$launcher_path"
    echo "Created launcher symlink: $launcher_path -> $MAIN_SCRIPT"

    path_export="export PATH=\"$bin_dir:\$PATH\""

    case ":${PATH:-}:" in
        *":$bin_dir:"*)
            echo "$bin_dir is already in PATH."
            ;;
        *)
            echo "Note: $bin_dir is not in PATH for this shell session."
            if [ "$add_path" = true ]; then
                touch "$shell_rc"
                if grep -Fqx "$path_export" "$shell_rc"; then
                    echo "PATH line already present in $shell_rc"
                else
                    printf '\n# OpenWrt menu launcher\n%s\n' "$path_export" >> "$shell_rc"
                    echo "Added to $shell_rc: $path_export"
                fi
                echo "Reload now with: source $shell_rc"
            else
                echo "To persist PATH, add this to $shell_rc:"
                echo "  $path_export"
                echo "Then reload with: source $shell_rc"
            fi
            echo "Or apply immediately with: export PATH=\"$bin_dir:\$PATH\""
            ;;
    esac
fi

if [ "$link_enabled" = true ]; then
    echo "Install complete. Run: $launcher_name"
else
    echo "Install complete. Run: ./openwrt_menu.sh"
fi
