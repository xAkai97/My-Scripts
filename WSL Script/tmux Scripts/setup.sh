#!/bin/bash

SCRIPT_DIR="$HOME/.scripts"
VSCODE_DIR="$HOME/.vscode"
SETTINGS_FILE="$VSCODE_DIR/settings.json"

# 1. Align files and apply execution permissions
if [ -f "$SCRIPT_DIR/ag-tmux.sh" ]; then
    mv "$SCRIPT_DIR/ag-tmux.sh" "$SCRIPT_DIR/ag-tmux"
fi

chmod +x "$SCRIPT_DIR/ag-tmux" 2>/dev/null
chmod +x "$SCRIPT_DIR/tmux-menu.sh" 2>/dev/null

# 2. Safely add the menu alias to .bashrc
if ! grep -q "tmux-menu.sh" "$HOME/.bashrc"; then
    echo "alias tmenu='$SCRIPT_DIR/tmux-menu.sh'" >> "$HOME/.bashrc"
fi

# 3. Handle the VS Code Settings using a Safe Python Merge
mkdir -p "$VSCODE_DIR"

# Create an empty JSON object if the file doesn't exist yet
if [ ! -f "$SETTINGS_FILE" ] || [ ! -s "$SETTINGS_FILE" ]; then
    echo "{}" > "$SETTINGS_FILE"
fi

echo "Merging agent interception routines into existing VS Code settings..."

python3 - << PYTHON_EOF
import json
import os

settings_path = os.path.expanduser('~/.vscode/settings.json')
script_dir = os.path.expanduser('~/.scripts')

# Load existing user settings
try:
    with open(settings_path, 'r') as f:
        # Strip simple lines with comments if they exist to prevent json decode errors
        lines = [line for line in f.readlines() if not line.strip().startswith('//')]
        data = json.loads(''.join(lines))
except Exception:
    data = {}

# Define the new agent configurations dynamically
new_settings = {
    "terminal.external.linuxExec": f"{script_dir}/ag-tmux",
    "terminal.integrated.persistentSessionReviveProcess": "never",
    "terminal.integrated.rescaleOverlappingGlyphs": False,
    "terminal.integrated.shellIntegration.enabled": False,
    "terminal.integrated.inheritEnv": False,
    "terminal.integrated.defaultProfile.linux": "ag-tmux-wrapper-human",
    "terminal.integrated.env.linux": {
        "HUMAN": "1"
    },
    "terminal.integrated.profiles.linux": {
        "ag-tmux-wrapper-agent": {
            "path": f"{script_dir}/ag-tmux",
            "icon": "terminal-linux",
            "env": {
                "FORCE_TMUX": "true",
                "AI_AGENT": "1"
            }
        },
        "ag-tmux-wrapper-human": {
            "path": f"{script_dir}/ag-tmux",
            "icon": "terminal-linux",
            "env": {
                "FORCE_TMUX": "true",
                "HUMAN_AGENT": "1"
            }
        }
    },
    "terminal.integrated.automationProfile.linux": {
        "path": f"{script_dir}/ag-tmux",
        "icon": "terminal-linux",
        "env": {
            "FORCE_TMUX": "true",
            "AI_AGENT": "1"
        }
    }
}

# Merge new settings into existing data (preserving old settings)
data.update(new_settings)

# Write back to settings.json beautifully indented
with open(settings_path, 'w') as f:
    json.dump(data, f, indent=4)

PYTHON_EOF

# 4. Refresh shell environment
source "$HOME/.bashrc"

echo -e "\033[1;32m[SUCCESS]\033[0m Agent settings safely merged without losing your existing preferences!"