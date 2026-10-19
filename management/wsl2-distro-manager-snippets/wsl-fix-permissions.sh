# Repairs home directory ownership and permissions, and re-grants sudo or wheel group access to the user.
#!/bin/sh
# @variable USERNAME "Enter username to fix:"

if [ -d /home/"$USERNAME" ]; then
    chown -R "$USERNAME:$USERNAME" /home/"$USERNAME"
    chmod 755 /home/"$USERNAME"
    echo "Home directory ownership repaired for $USERNAME."
else
    echo "Home directory for $USERNAME does not exist."
fi

if [ -f /etc/alpine-release ]; then
    addgroup "$USERNAME" wheel 2>/dev/null || addgroup "$USERNAME" sudo 2>/dev/null
else
    usermod -aG sudo "$USERNAME" 2>/dev/null || usermod -aG wheel "$USERNAME" 2>/dev/null
fi

echo "Sudo/wheel privileges re-granted for $USERNAME."