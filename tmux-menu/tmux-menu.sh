#!/usr/bin/env bash

SOCKET_NAME="${TMUX_AGENT_SOCKET:-agent_socket}"
SOCKET=(-L "$SOCKET_NAME")
TMUX_BIN=$(command -v tmux || echo "/usr/bin/tmux")

if ! command -v "$TMUX_BIN" &>/dev/null; then
    echo "tmux is not installed or not in PATH."
    exit 1
fi

check_sessions() {
    if ! "$TMUX_BIN" "${SOCKET[@]}" list-sessions &>/dev/null; then
        echo -e "\033[1;31mNo active sessions found on socket '$SOCKET_NAME'.\033[0m"
        return 1
    fi
    return 0
}

while true; do
    clear
    cat << EOF
===================================================
      Tmux Agent Session Manager ($SOCKET_NAME)
===================================================
1) List active agent sessions
2) Attach to a session
3) Detach a client
4) Kill an agent session
5) Switch socket
q) Exit
---------------------------------------------------
EOF
    read -rp "Select option: " choice

    case "$choice" in
        1)
            echo -e "\n\033[1;32m--- Active Agent Sessions ---\033[0m"
            check_sessions && "$TMUX_BIN" "${SOCKET[@]}" list-sessions
            echo ""
            read -rp "Press Enter to return..."
            ;;
        2)
            echo -e "\n\033[1;32m--- Attach to Session ---\033[0m"
            if check_sessions; then
                mapfile -t sessions < <("$TMUX_BIN" "${SOCKET[@]}" list-sessions -F '#{session_name}')
                for i in "${!sessions[@]}"; do
                    printf "%2d) %s\n" "$((i+1))" "${sessions[$i]}"
                done
                read -rp "Select number (or 'b' to cancel): " sel
                if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#sessions[@]}" ]; then
                    target="${sessions[$((sel-1))]}"
                    "$TMUX_BIN" "${SOCKET[@]}" attach-session -t "$target"
                fi
            else
                sleep 1.2
            fi
            ;;
        3)
            echo -e "\n\033[1;32m--- Detach Client ---\033[0m"
            if check_sessions; then
                mapfile -t clients < <("$TMUX_BIN" "${SOCKET[@]}" list-clients -F '#{client_name} (#{session_name})')
                if [ ${#clients[@]} -eq 0 ]; then
                    echo "No attached clients found."
                else
                    for i in "${!clients[@]}"; do
                        printf "%2d) %s\n" "$((i+1))" "${clients[$i]}"
                    done
                    read -rp "Select client to detach (or 'b' to cancel): " sel
                    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#clients[@]}" ]; then
                        target_client=$(echo "${clients[$((sel-1))]}" | awk '{print $1}')
                        "$TMUX_BIN" "${SOCKET[@]}" detach-client -t "$target_client"
                        echo "Client detached."
                    fi
                fi
            fi
            sleep 1.2
            ;;
        4)
            echo -e "\n\033[1;31m--- Kill Agent Session ---\033[0m"
            if check_sessions; then
                mapfile -t sessions < <("$TMUX_BIN" "${SOCKET[@]}" list-sessions -F '#{session_name}')
                for i in "${!sessions[@]}"; do
                    printf "%2d) %s\n" "$((i+1))" "${sessions[$i]}"
                done
                read -rp "Select session to KILL (or 'b' to cancel): " sel
                if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#sessions[@]}" ]; then
                    target="${sessions[$((sel-1))]}"
                    read -rp "Terminate '$target'? (y/N): " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        "$TMUX_BIN" "${SOCKET[@]}" kill-session -t "$target"
                        echo "Session killed."
                    fi
                fi
            fi
            sleep 1
            ;;
        5)
            read -rp "Enter new tmux socket name [current: $SOCKET_NAME]: " NEW_SOCK
            if [ -n "$NEW_SOCK" ]; then
                SOCKET_NAME="$NEW_SOCK"
                SOCKET=(-L "$SOCKET_NAME")
            fi
            ;;
        q|Q)
            exit 0
            ;;
        *)
            echo "Invalid selection."
            sleep 0.5
            ;;
    esac
done