#!/usr/bin/env bash
set -euo pipefail

BOLD="\033[1m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

NON_INTERACTIVE=false
if [[ "${1:-}" == "-y" || "${1:-}" == "--defaults" ]]; then
    NON_INTERACTIVE=true
fi

clear
echo -e "${CYAN}====================================================${RESET}"
echo -e "${BOLD}         tmux-menu & VS Code Wrapper Setup          ${RESET}"
echo -e "${CYAN}====================================================${RESET}\n"

# 1. Target scripts directory
DEFAULT_SCRIPT_DIR="$HOME/.scripts"
if [ "$NON_INTERACTIVE" = true ]; then
    SCRIPT_DIR="$DEFAULT_SCRIPT_DIR"
else
    read -rp "$(echo -e "${BOLD}Install scripts directory [default: ${DEFAULT_SCRIPT_DIR}]: ${RESET}")" USER_SCRIPT_DIR
    SCRIPT_DIR="${USER_SCRIPT_DIR:-$DEFAULT_SCRIPT_DIR}"
fi
mkdir -p "$SCRIPT_DIR"
echo -e "${GREEN}✓ Scripts target: ${SCRIPT_DIR}${RESET}\n"

# 2. Settings target detection
IS_WSL=false
if grep -qi "microsoft" /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
    IS_WSL=true
fi

declare -a DETECTED_PATHS=()
[ -f "$HOME/.vscode-server/data/Machine/settings.json" ] && DETECTED_PATHS+=("$HOME/.vscode-server/data/Machine/settings.json")
[ -f "$HOME/.config/Code/User/settings.json" ] && DETECTED_PATHS+=("$HOME/.config/Code/User/settings.json")
[ -f "$HOME/.var/app/com.visualstudio.code/config/Code/User/settings.json" ] && DETECTED_PATHS+=("$HOME/.var/app/com.visualstudio.code/config/Code/User/settings.json")
[ -f "$HOME/Library/Application Support/Code/User/settings.json" ] && DETECTED_PATHS+=("$HOME/Library/Application Support/Code/User/settings.json")
[ -f "$HOME/.vscode/settings.json" ] && DETECTED_PATHS+=("$HOME/.vscode/settings.json")

if [ ${#DETECTED_PATHS[@]} -eq 0 ]; then
    if [ "$IS_WSL" = true ]; then
        DETECTED_PATHS+=("$HOME/.vscode-server/data/Machine/settings.json")
    else
        DETECTED_PATHS+=("$HOME/.config/Code/User/settings.json")
    fi
fi

echo -e "${BOLD}Select VS Code settings target:${RESET}"
for i in "${!DETECTED_PATHS[@]}"; do
    printf "  %d) %s\n" "$((i+1))" "${DETECTED_PATHS[$i]}"
done
printf "  c) Custom Path\n"

if [ "$NON_INTERACTIVE" = true ]; then
    TARGET_SETTINGS="${DETECTED_PATHS[0]}"
else
    read -rp "$(echo -e "${BOLD}Choose an option [default: 1]: ${RESET}")" CHOICE
    CHOICE="${CHOICE:-1}"

    if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#DETECTED_PATHS[@]}" ]; then
        TARGET_SETTINGS="${DETECTED_PATHS[$((CHOICE-1))]}"
    elif [[ "$CHOICE" == "c" || "$CHOICE" == "C" ]]; then
        read -rp "Enter full path to settings.json: " CUSTOM_PATH
        TARGET_SETTINGS="$CUSTOM_PATH"
    else
        TARGET_SETTINGS="${DETECTED_PATHS[0]}"
    fi
fi

SETTINGS_DIR=$(dirname "$TARGET_SETTINGS")
mkdir -p "$SETTINGS_DIR"
[ ! -f "$TARGET_SETTINGS" ] && echo "{}" > "$TARGET_SETTINGS"
echo -e "${GREEN}✓ VS Code Target: ${TARGET_SETTINGS}${RESET}\n"

# 3. Deploy binaries
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -f "$SOURCE_DIR/tmux-wrapper" "$SCRIPT_DIR/tmux-wrapper"
cp -f "$SOURCE_DIR/tmux-menu.sh" "$SCRIPT_DIR/tmux-menu.sh"
chmod +x "$SCRIPT_DIR/tmux-wrapper" "$SCRIPT_DIR/tmux-menu.sh"
echo -e "${GREEN}✓ Installed binaries to ${SCRIPT_DIR}${RESET}\n"

# 4. Add Shell Alias
CONFIGURE_ALIAS=true
if [ "$NON_INTERACTIVE" = false ]; then
    read -rp "$(echo -e "${BOLD}Add 'tmenu' alias to ~/.bashrc / ~/.zshrc? (Y/n): ${RESET}")" ALIAS_ANS
    if [[ "$ALIAS_ANS" =~ ^[Nn]$ ]]; then
        CONFIGURE_ALIAS=false
    fi
fi

if [ "$CONFIGURE_ALIAS" = true ]; then
    ALIAS_CMD="alias tmenu='$SCRIPT_DIR/tmux-menu.sh'"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ] && ! grep -Fxq "$ALIAS_CMD" "$rc" 2>/dev/null; then
            echo "$ALIAS_CMD" >> "$rc"
            echo -e "${GREEN}✓ Registered 'tmenu' alias in $(basename "$rc")${RESET}"
        fi
    done
fi
echo ""

# 5. Merge VS Code Profiles
echo -e "${BOLD}Configuring VS Code profiles...${RESET}"
python3 - << PYTHON_EOF
import json, os, re, platform

settings_file = os.path.expanduser('$TARGET_SETTINGS')
script_dir = os.path.expanduser('$SCRIPT_DIR')

def strip_json_comments(text):
    pattern = r'(//.*?$)|(/\*.*?\*/)'
    return re.sub(pattern, '', text, flags=re.MULTILINE | re.DOTALL)

try:
    with open(settings_file, 'r', encoding='utf-8') as f:
        clean_text = strip_json_comments(f.read())
        data = json.loads(clean_text) if clean_text.strip() else {}
except Exception:
    data = {}

system_name = platform.system().lower()
os_key = "osx" if system_name == "darwin" else "linux"

new_settings = {
    f"terminal.external.{os_key}Exec": f"{script_dir}/tmux-wrapper",
    "terminal.integrated.persistentSessionReviveProcess": "never",
    "terminal.integrated.rescaleOverlappingGlyphs": False,
    "terminal.integrated.shellIntegration.enabled": False,
    "terminal.integrated.inheritEnv": False,
    f"terminal.integrated.defaultProfile.{os_key}": "tmux-wrapper-human",
    f"terminal.integrated.env.{os_key}": {
        "HUMAN": "1"
    },
    f"terminal.integrated.profiles.{os_key}": {
        "tmux-wrapper-agent": {
            "path": f"{script_dir}/tmux-wrapper",
            "icon": "terminal-linux",
            "env": {
                "FORCE_TMUX": "true",
                "AI_AGENT": "1"
            }
        },
        "tmux-wrapper-human": {
            "path": f"{script_dir}/tmux-wrapper",
            "icon": "terminal-linux",
            "env": {
                "FORCE_TMUX": "true",
                "HUMAN": "1"
            }
        }
    },
    f"terminal.integrated.automationProfile.{os_key}": {
        "path": f"{script_dir}/tmux-wrapper",
        "icon": "terminal-linux",
        "env": {
            "FORCE_TMUX": "true",
            "AI_AGENT": "1"
        }
    }
}

for k, v in new_settings.items():
    if isinstance(v, dict) and k in data and isinstance(data[k], dict):
        data[k].update(v)
    else:
        data[k] = v

with open(settings_file, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=4)
PYTHON_EOF

echo -e "\n${GREEN}====================================================${RESET}"
echo -e "${GREEN}${BOLD}✓ Setup Complete!${RESET}"
echo -e "${GREEN}====================================================${RESET}"
echo -e "Next steps:"
echo -e "  1. Reload shell:       ${YELLOW}source ~/.bashrc${RESET}"
echo -e "  2. Launch menu:        ${YELLOW}tmenu${RESET}"
echo -e "  3. Uninstall anytime:  ${YELLOW}./uninstall.sh${RESET}"