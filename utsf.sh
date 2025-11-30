#!/bin/bash

# Function to print fancy separator
print_separator() {
    echo -e "\e[38;5;39m╔═══════════════════════════════════════════════════════════════╗\e[0m"
}

# Function to print centered text with custom color
print_centered() {
    local text="$1"
    local color="$2"
    local width=63
    local padding=$(( (width - ${#text}) / 2 ))
    echo -e "\e[38;5;39m║\e[0m$color$(printf '%*s' $padding)$text$(printf '%*s' $padding)\e[38;5;39m║\e[0m"
}

# Display stylish header
clear
print_separator
print_centered "🚀 SourceForge File Uploader 🚀" "\e[1;38;5;51m"
print_centered "Created by Mahesh Technicals (Modified by Aranya)" "\e[1;38;5;213m"
print_separator
echo

# Function to check if jq is installed
check_dependencies() {
    echo -e "\e[1;38;5;220m📦 Checking Dependencies...\e[0m"
    if ! command -v jq &> /dev/null; then
        echo -e "\e[1;38;5;208m⚠️  jq is not installed. Installing jq...\e[0m"
        sudo apt-get update
        sudo apt-get install -y jq
    else
        echo -e "\e[1;38;5;77m✅ jq is already installed.\e[0m"
    fi
    echo
}

# handle interrupt
handle_interrupt() {
    echo -e "\n\e[1;38;5;196m❌ Script interrupted! Closing SSH session...\e[0m"
    end_ssh_session
    exit 1
}

# Start SSH ControlMaster session
start_ssh_session() {
    echo -e "\e[1;38;5;75m🔄 Initializing SSH session...\e[0m"
    SOCKET=$(mktemp -u)
    ssh -o ControlMaster=yes -o ControlPath="$SOCKET" -fN "$SOURCEFORGE_USERNAME@frs.sourceforge.net"
}

# End SSH ControlMaster session
end_ssh_session() {
    echo -e "\e[1;38;5;75m🔒 Closing SSH session...\e[0m"
    ssh -o ControlPath="$SOCKET" -O exit "$SOURCEFORGE_USERNAME@frs.sourceforge.net"
}

# Trap CTRL+C
trap handle_interrupt SIGINT

# Check dependencies
check_dependencies

# Load credentials
if [ ! -f private.json ]; then
    echo -e "\e[1;38;5;196m❌ Error: private.json not found!\e[0m"
    exit 1
fi

# Read JSON fields
SOURCEFORGE_USERNAME=$(jq -r '.username' private.json)
PROJECT_NAME=$(jq -r '.project' private.json)
SUBFOLDER=$(jq -r '.path' private.json)

# Validate fields
if [ -z "$SOURCEFORGE_USERNAME" ] || [ -z "$PROJECT_NAME" ] || [ -z "$SUBFOLDER" ]; then
    echo -e "\e[1;38;5;196m❌ Error: Missing required fields in private.json (username/project/path)!\e[0m"
    exit 1
fi

# Define exact upload path
UPLOAD_PATH="$SOURCEFORGE_USERNAME@frs.sourceforge.net:/home/frs/project/$PROJECT_NAME/$SUBFOLDER"

# Start SSH
start_ssh_session

# Detect files
FILES=($(find . -maxdepth 1 -type f \( -name "*.img" -o -name "*.zip" \)))

# Stylish file list
print_separator
print_centered "Available Files for Upload" "\e[1;38;5;220m"
print_separator

if [ ${#FILES[@]} -eq 0 ]; then
    echo -e "\e[1;38;5;196m⚠️  No .img or .zip files found!\e[0m"
fi

echo -e "\e[1;38;5;77m[1]\e[0m Upload All"
echo -e "\e[1;38;5;77m[2]\e[0m Custom file"

if [ ${#FILES[@]} -gt 0 ]; then
    for i in "${!FILES[@]}"; do
        echo -e "\e[1;38;5;77m[$(($i+3))]\e[0m ${FILES[$i]#./}"
    done
fi

print_separator
echo

# Upload function
upload_file() {
    local file=$1
    echo -e "\e[1;38;5;75m📤 Uploading: $file\e[0m"
    echo -e "\e[1;38;5;244m➜ Destination: $UPLOAD_PATH\e[0m"

    scp -o ControlPath="$SOCKET" "$file" "$UPLOAD_PATH"

    if [ $? -eq 0 ]; then
        echo -e "\e[1;38;5;77m✅ Upload successful\e[0m"
    else
        echo -e "\e[1;38;5;196m❌ Upload failed\e[0m"
    fi
}

# Menu selection
echo -e "\e[1;38;5;220m📝 Select files (e.g., 1 3 4):\e[0m"
read -p "➜ " -a selected

for number in "${selected[@]}"; do
    if [ "$number" -eq 1 ]; then
        for file in "${FILES[@]}"; do
            upload_file "$file"
        done
    elif [ "$number" -eq 2 ]; then
        echo "Enter file path:"
        read custom_file
        upload_file "$custom_file"
    elif [ "$number" -gt 2 ] && [ "$number" -le $(( ${#FILES[@]} + 2 )) ]; then
        upload_file "${FILES[$((number-3))]}"
    fi
done

# End SSH
end_ssh_session

print_separator
print_centered "✨ Upload Complete ✨" "\e[1;38;5;51m"
print_separator
