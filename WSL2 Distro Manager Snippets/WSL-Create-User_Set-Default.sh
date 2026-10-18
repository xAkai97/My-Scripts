# Creates a new Linux user with password, assigns sudo/wheel privileges, and sets them as the default user in /etc/wsl.conf.
#!/bin/sh
# @variable USERNAME "Enter username:"
# @variable PASSWORD "Enter password:"

if [ -f /etc/alpine-release ]; then
    adduser -D -s /bin/sh "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    addgroup "$USERNAME" wheel 2>/dev/null || addgroup "$USERNAME" sudo 2>/dev/null
else
    useradd -m -s /bin/bash "$USERNAME" 2>/dev/null || useradd -m -s /bin/sh "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    usermod -aG sudo "$USERNAME" 2>/dev/null || usermod -aG wheel "$USERNAME" 2>/dev/null
fi

printf "[user]\ndefault=%s\n" "$USERNAME" > /etc/wsl.conf
echo "Default user set to $USERNAME!"