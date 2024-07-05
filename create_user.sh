# Function to read and parse the input file
read_input_file() {
  local filename="$1"
  while IFS=';' read -r user groups; do
    users+=("$(echo "$user" | xargs)")
    group_list+=("$(echo "$groups" | tr -d '[:space:]')")
  done < "$filename"
}

# Function to create a user with its personal group
create_user_with_group() {
  local username="$1"
  if id "$username" &>/dev/null; then
    echo "User $username already exists." | tee -a "$log_file"
  else
    groupadd "$username"
    useradd -m -g "$username" -s /bin/bash "$username"
    echo "Created user $username with personal group $username." | tee -a "$log_file"
  fi
}

# Function to set a password for the user
set_user_password() {
  local username="$1"
  local password=$(openssl rand -base64 12)
  echo "$username:$password" | chpasswd
  echo "$username,$password" >> "$password_file"
  echo "Password for $username set and stored." | tee -a "$log_file"
}


# Function to add user to additional groups
add_user_to_groups() {
  local username="$1"
  IFS=',' read -r -a groups <<< "$2"
  for group in "${groups[@]}"; do
    if ! getent group "$group" &>/dev/null; then
      groupadd "$group"
      echo "Group $group created." | tee -a "$log_file"
    fi
    usermod -aG "$group" "$username"
    echo "Added $username to group $group." | tee -a "$log_file"
  done
}


# Check for input file argument
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <input_file>"
  exit 1
fi

# Initialize variables
input_file="$1"
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.txt"
declare -a users
declare -a group_list

# Create log and password files if they do not exist
mkdir -p /var/log /var/secure
touch "$log_file"
touch "$password_file"
chmod 600 "$password_file"

# Read input file
read_input_file "$input_file"

# Process each user
for ((i = 0; i < ${#users[@]}; i++)); do
  username="${users[i]}"
  user_groups="${group_list[i]}"

  if [[ "$username" == "" ]]; then
    continue  # Skip empty usernames
  fi

  create_user_with_group "$username"
  set_user_password "$username"
  add_user_to_groups "$username" "$user_groups"
done

echo "User creation and group assignment completed." | tee -a "$log_file"

