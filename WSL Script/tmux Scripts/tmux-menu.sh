#!/bin/bash

SOCKET_OPT="-L agent_socket"
TMUX_BIN="/usr/bin/tmux"

# Ensure the socket actually has sessions running before continuing
function check_sessions() {
    if ! "$TMUX_BIN" $SOCKET_OPT list-sessions &>/dev/null; then
        echo -e "\033[1;31mNo active tmux agent sessions found on 'agent_socket'.\033[0m"
        return 1
    fi
    return 0
}

while true; do
    clear
    echo -e "\033[1;35m=========================================\033[0m"
    echo -e "\033[1;36m    Isolating tmux Agent Tmux Session Menu    \033[0m"
    echo -e "\033[1;35m=========================================\033[0m"
    echo -e "1) List active tmux Agent sessions"
    echo -e "2) Attach to an tmux Agent session"
    echo -e "3) Detach a client from an tmux Agent session"
    echo -e "4) Kill an tmux Agent session"
    echo -e "q) Exit menu"
    echo -e "\033[1;35m-----------------------------------------\033[0m"
    read -rp "Choose an option: " choice

    case $choice in
        1)
            echo -e "\n\033[1;32m--- Active tmux Agent Sessions ---\033[0m"
            if check_sessions; then
                "$TMUX_BIN" $SOCKET_OPT list-sessions
            fi
            echo ""
            read -rp "Press Enter to return to menu..."
            ;;
            
        2)
            echo -e "\n\033[1;32m--- Attach to Session ---\033[0m"
            if check_sessions; then
                # Get list of sessions into an array
                mapfile -t sessions < <("$TMUX_BIN" $SOCKET_OPT list-sessions -F '#{session_name}')
                
                for i in "${!sessions[@]}"; do
                    echo "$((i+1))) ${sessions[$i]}"
                done
                echo "b) Back to main menu"
                
                read -rp "Select a session number to attach: " s_choice
                if [[ "$s_choice" =~ ^[0-9]+$ ]] && [ "$s_choice" -le "${#sessions[@]}" ] && [ "$s_choice" -gt 0 ]; then
                    target="${sessions[$((s_choice-1))]}"
                    echo "Attaching to $target..."
                    "$TMUX_BIN" $SOCKET_OPT attach-session -t "$target"
                elif [[ "$s_choice" == "b" ]]; then
                    continue
                else
                    echo "Invalid selection."
                    sleep 1
                fi
            else
                sleep 1.5
            fi
            ;;

        3)
            echo -e "\n\033[1;32m--- Detach Client ---\033[0m"
            if check_sessions; then
                # Lists active clients attached to the tmux agent socket
                mapfile -t clients < <("$TMUX_BIN" $SOCKET_OPT list-clients -F '#{client_name} (Attached to #{session_name})')
                
                if [ ${#clients[@]} -eq 0 ]; then
                    echo "No active clients currently attached to any tmux agent session."
                else
                    for i in "${!clients[@]}"; do
                        echo "$((i+1))) ${clients[$i]}"
                    done
                    read -rp "Select client number to force-detach: " c_choice
                    if [[ "$c_choice" =~ ^[0-9]+$ ]] && [ "$c_choice" -le "${#clients[@]}" ] && [ "$c_choice" -gt 0 ]; then
                        # Extract exact client name (first block before space)
                        target_client=$(echo "${clients[$((c_choice-1))]}" | awk '{print $1}')
                        "$TMUX_BIN" $SOCKET_OPT detach-client -t "$target_client"
                        echo "Client detached."
                    else
                        echo "Invalid selection."
                    fi
                fi
            fi
            sleep 1.5
            ;;

        4)
            echo -e "\n\033[1;31m--- Kill Session ---\033[0m"
            if check_sessions; then
                mapfile -t sessions < <("$TMUX_BIN" $SOCKET_OPT list-sessions -F '#{session_name}')
                for i in "${!sessions[@]}"; do
                    echo "$((i+1))) ${sessions[$i]}"
                done
                read -rp "Select a session number to KILL: " k_choice
                if [[ "$k_choice" =~ ^[0-9]+$ ]] && [ "$k_choice" -le "${#sessions[@]}" ] && [ "$k_choice" -gt 0 ]; then
                    target="${sessions[$((k_choice-1))]}"
                    read -rp "Are you sure you want to terminate $target? (y/N): " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        "$TMUX_BIN" $SOCKET_OPT kill-session -t "$target"
                        echo "Session killed."
                    fi
                fi
            fi
            sleep 1
            ;;

        q|Q)
            echo "Exiting menu."
            exit 0
            ;;
        *)
            echo "Invalid option, try again."
            sleep 1
            ;;
    esac
done