#!/bin/bash

# Checking if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Checking if a file was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <filename>" >&2
    exit 1
fi

# Defining log and secure file paths
LOG_FILE="/var/log/user_management.log"
SECURE_FILE="/var/secure/user_passwords.csv"

# Creating  the secure directory 
mkdir -p /var/secure

# Creating the log and secure files
> "$LOG_FILE"
> "$SECURE_FILE"

# Set secure file permissions
chmod 600 "$SECURE_FILE"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Read the input file line by line
while IFS=';' read -r user groups; do
    # Trim whitespace
    user=$(echo "$user" | xargs)
    groups=$(echo "$groups" | xargs)
    
    if id "$user" &>/dev/null; then
        log_message "User $user already exists."
        continue
    fi

    # Create the user's personal group
    if ! getent group "$user" &>/dev/null; then
        groupadd "$user"
        log_message "Group $user created."
    fi

    # Create the user with the personal group and home directory
    useradd -m -g "$user" -s /bin/bash "$user"
    log_message "User $user created with home directory /home/$user."

    # Set up the additional groups
    if [ -n "$groups" ]; then
        IFS=',' read -r -a group_array <<< "$groups"
        for group in "${group_array[@]}"; do
            group=$(echo "$group" | xargs)
            if ! getent group "$group" &>/dev/null; then
                groupadd "$group"
                log_message "Group $group created."
            fi
            usermod -aG "$group" "$user"
            log_message "User $user added to group $group."
        done
    fi

    # Generate a random password
    password=$(openssl rand -base64 12)
    echo "$user:$password" | chpasswd
    log_message "Password set for user $user."

    # Store the username and password in the secure file
    echo "$user,$password" >> "$SECURE_FILE"

    # Set permissions for the home directory
    chmod 700 /home/"$user"
    chown "$user":"$user" /home/"$user"
    log_message "Permissions set for home directory of user $user."
done < "$1"

log_message "User creation completed."

echo "1. Users creation complete.
2. Logs available at $LOG_FILE.
3. Passwords are stored securely at $SECURE_FILE."
