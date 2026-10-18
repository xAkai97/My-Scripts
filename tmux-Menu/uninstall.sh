#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$HOME/.scripts}"
SOCKET_NAME="${TMUX_AGENT_SOCKET:-agent_socket}"
SOCKET=(-L "$SOCKET_NAME")
TMUX_BIN=$(command -v tmux || echo "/usr/bin/tmux")

declare -a SETTINGS_CANDIDATES=(
    "$HOME/.vscode-server/data/Machine/settings.json"
    "$HOME/.var/app/com.visualstudio.code/config/Code/User/settings.json"
    "$HOME/.config/Code/User/settings.json"
    "$HOME/Library/Application Support/Code/User/settings.json"
    "$HOME/.vscode/settings.json"
)

if [ -x "$TMUX_BIN" ] && "$TMUX_BIN" "${SOCKET[@]}" list-sessions &>/dev/null; then
    echo "Terminating active sessions on socket: $SOCKET_NAME..."
    "$TMUX_BIN" "${SOCKET[@]}" kill-server 2>/dev/null || true
fi

rm -rf "/tmp/tmux-agent-logs" "/tmp/ag-tmux-telegraph"

for settings_file in "${SETTINGS_CANDIDATES[@]}"; do
    if [ -f "$settings_file" ]; then
        echo "Cleaning settings in: $settings_file"
        python3 - << PYTHON_EOF
import json, os, re

path = os.path.expanduser('$settings_file')

def strip_json_comments(text):
    pattern = r'(//.*?$)|(/\*.*?\*/)'
    return re.sub(pattern, '', text, flags=re.MULTILINE | re.DOTALL)

try:
    with open(path, 'r', encoding='utf-8') as f:
        clean = strip_json_comments(f.read())
        data = json.loads(clean) if clean.strip() else {}
except Exception:
    data = {}

for os_key in ["linux", "osx"]:
    data.pop(f"terminal.external.{os_key}Exec", None)
    data.pop(f"terminal.integrated.automationProfile.{os_key}", None)
    
    cur_default = data.get(f"terminal.integrated.defaultProfile.{os_key}")
    if cur_default in ["tmux-wrapper-human", "ag-tmux-wrapper-human"]:
        data.pop(f"terminal.integrated.defaultProfile.{os_key}", None)

    env_key = f"terminal.integrated.env.{os_key}"
    if env_key in data and isinstance(data[env_key], dict):
        data[env_key].pop("HUMAN", None)
        if not data[env_key]:
            data.pop(env_key, None)

    prof_key = f"terminal.integrated.profiles.{os_key}"
    if prof_key in data and isinstance(data[prof_key], dict):
        for p in ["tmux-wrapper-agent", "tmux-wrapper-human", "ag-tmux-wrapper-agent", "ag-tmux-wrapper-human"]:
            data[prof_key].pop(p, None)
        if not data[prof_key]:
            data.pop(prof_key, None)

data.pop("terminal.integrated.persistentSessionReviveProcess", None)
data.pop("terminal.integrated.rescaleOverlappingGlyphs", None)
data.pop("terminal.integrated.shellIntegration.enabled", None)
data.pop("terminal.integrated.inheritEnv", None)

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=4)
PYTHON_EOF
    fi
done

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ]; then
        sed -i '/tmux-menu\.sh/d' "$rc" 2>/dev/null || true
    fi
done

rm -f "$SCRIPT_DIR/tmux-wrapper" "$SCRIPT_DIR/ag-tmux" "$SCRIPT_DIR/tmux-menu.sh"

echo -e "\033[1;32m[SUCCESS]\033[0m Complete uninstall completed."