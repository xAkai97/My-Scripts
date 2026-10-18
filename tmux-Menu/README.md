# tmux-menu & VS Code Session Interceptor

A lightweight, adaptive session router and terminal manager for developers using VS Code, WSL, Linux, or macOS alongside autonomous AI coding agents (such as Cline, Roo Code, Claude Code, or Antigravity).

`tmux-menu` prevents automated background jobs and human terminal interactions from interfering with each other by isolating commands into dedicated, workspace-aware `tmux` sockets.

---

## The Problem

When AI coding agents run terminal tasks in VS Code:
- Automated commands can interrupt active commands you are typing in the integrated terminal.
- Terminal windows closed or reloaded by VS Code destroy running background processes.
- Reviewing what an agent actually executed requires scrolling through cluttered terminal buffers.

---

## How It Works

`tmux-menu` acts as a proxy wrapper configured as your VS Code default and automation profiles:

```
                  VS Code Terminal Request
                             │
                     [ tmux-wrapper ]
                             │
             ┌───────────────┴───────────────┐
             ▼                               ▼
       Human Session                   AI Agent Call
   (Normal tmux instance)           (Isolated agent socket)
             │                               │
    • Workspace-scoped              • Socket: agent_socket
    • Full interactive TTY          • Persistent detached daemon
    • Persists across reloads       • Real-time logging to /tmp
                                    • Inspectable via `tmenu`
```

1. **AI Agent Mode (`AI_AGENT=1`)**: When VS Code or an extension runs an automated command, `tmux-wrapper` intercepts it, attaches or creates a detached session on an isolated socket (`agent_socket`), and mirrors stdout/stderr to `/tmp/tmux-agent-logs/`.
2. **Human Interactive Mode**: When you open an integrated terminal, it starts or reattaches to an interactive session named after your workspace project folder.
3. **Menu Dashboard (`tmenu`)**: An interactive terminal UI to inspect, attach to, detach from, or terminate background agent sessions without having to memorize raw `tmux` socket flags.

---

## File Structure

```text
tmux-menu/
├── README.md           # Documentation & instructions
├── setup.sh            # Interactive/automated installer
├── uninstall.sh        # Complete teardown & setting purger
├── tmux-menu.sh        # Terminal UI session manager (`tmenu`)
└── tmux-wrapper        # Main execution proxy & routing wrapper
```

---

## Prerequisites

- **Multiplexer**: `tmux` (`sudo apt install tmux` or `brew install tmux`)
- **Shell**: `bash` (4.0+) or `zsh`
- **Interpreter**: `python3` (used during setup/uninstall to cleanly parse and update VS Code's JSON configuration)

---

## Installation

### 1. Interactive Setup (Recommended)

Run the setup wizard:
```bash
chmod +x setup.sh && ./setup.sh
```

The installer will:
1. Ask where to install scripts (defaults to `~/.scripts`).
2. Detect your environment (WSL, native Linux, Remote Container, or macOS).
3. Identify existing VS Code `settings.json` files and let you choose which profile to update.
4. Safely merge terminal profiles (`tmux-wrapper-human` and `tmux-wrapper-agent`) without deleting existing user settings.
5. Offer to add the `tmenu` alias to your `~/.bashrc` or `~/.zshrc`.

### 2. Non-Interactive / Headless Setup

For Dockerfiles, devcontainer provisioning, or unattended installs, run with the `-y` flag to accept all defaults:
```bash
chmod +x setup.sh && ./setup.sh -y
```

### 3. Activate the Changes

Reload your active shell or reopen your terminal:
```bash
source ~/.bashrc   # or source ~/.zshrc
```

---

## Usage

### 1. The Session Menu (`tmenu`)

Launch the manager dashboard from any shell:
```bash
tmenu
```

From this menu, you can:
- **List Active Sessions**: Inspect all agent tasks running on the isolated socket.
- **Attach to Session**: Jump directly into an agent's terminal pane to watch live progress or interact with interactive CLI prompts. Use `Ctrl+b d` to detach without interrupting the job.
- **Detach Client**: Disconnect hanging client sessions.
- **Kill Session**: Terminate a background job immediately.
- **Switch Socket**: Change target socket namespace on the fly.

### 2. Manual Wrapper Invocations

You can invoke `tmux-wrapper` directly from the command line:

```bash
# Attach or open your workspace's human tmux session:
~/.scripts/tmux-wrapper

# Execute a command in the background agent socket:
AI_AGENT=1 ~/.scripts/tmux-wrapper -c "npm run test"

# Bypass tmux entirely for direct execution (e.g., viewing logs):
AI_AGENT=1 ~/.scripts/tmux-wrapper -c "direct tail -f /tmp/tmux-agent-logs/*.log"
```

---

## Environment Variables

You can customize runtime behavior by adding these variables to your shell startup file or `.env`:

| Variable | Default | Description |
|---|---|---|
| `TMUX_AGENT_SOCKET` | `agent_socket` | Socket name used for isolated agent sessions. |
| `TMUX_AGENT_LOG_DIR` | `/tmp/tmux-agent-logs` | Target folder where agent execution logs are saved. |
| `WORKSPACE_ROOT` | `$PWD` | Fallback directory used if `ANTIGRAVITY_WORKSPACE_ROOT` is unset. |
| `SHELL` | `/bin/bash` | Default shell binary spawned inside new `tmux` panes. |

---

## Uninstallation

To remove all scripts, revert VS Code terminal profiles, and delete temporary logs:

```bash
chmod +x uninstall.sh && ./uninstall.sh
```

The uninstaller:
- Shuts down running sessions on the agent socket.
- Deletes log buffers in `/tmp/tmux-agent-logs/`.
- Removes the custom profiles and overrides from your VS Code `settings.json`.
- Removes the `tmenu` alias from `~/.bashrc` and `~/.zshrc`.
- Removes `tmux-wrapper` and `tmux-menu.sh` from the install folder.