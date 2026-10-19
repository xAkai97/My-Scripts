# Safely deletes a specified user and purges their home directory across different Linux distributions.
#!/bin/sh
# @variable USERNAME "Enter username to delete:"

if [ -f /etc/alpine-release ]; then
    deluser -D "$USERNAME" 2>/dev/null
else
    userdel -r "$USERNAME" 2>/dev/null || userdel "$USERNAME" 2>/dev/null
fi

echo "User $USERNAME deleted."