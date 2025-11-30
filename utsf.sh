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
print_centered "Created by Mahesh Technicals" "\e[1;38;5;213m"
print_centered "Version 1.4" "\e[1;38;5;159m"
print_separator
echo

# Function to check if jq is installed with stylish output
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

# Function to handle script interruption (CTRL+C)
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

# Trap the SIGINT (CTRL+C) signal
trap handle_interrupt SIGINT

# Check dependencies
check_dependencies

# Load credentials and project name from private.json
if [ ! -f private.json ]; then
    echo -e "\e[1;38;5;196m❌ Error: private.json not found!\e[0m"
    exit 1
fi

# Read credentials and project name from private.json
SOURCEFORGE_USERNAME=$(jq -r '.username' private.json)
PROJECT_NAME=$(jq -r '.project' private.json)

# Ensure all required fields are present
if [ -z "$SOURCEFORGE_USERNAME" ] || [ -z "$PROJECT_NAME" ]; then
    echo -e "\e[1;38;5;196m❌ Error: Missing required fields in private.json!\e[0m"
    exit 1
fi

# Define the upload path on SourceForge
UPLOAD_PATH="$SOURCEFORGE_USERNAME@frs.sourceforge.net:/home/frs/project/$PROJECT_NAME"

# Start SSH session
start_ssh_session

# Find .img and .zip files in the current directory
FILES=($(find . -maxdepth 1 -type f \( -name "*.img" -o -name "*.zip" \)))

# Display stylish file selection menu
print_separator
print_centered "Available Files for Upload" "\e[1;38;5;220m"
print_separator

if [ ${#FILES[@]} -eq 0 ]; then
    echo -e "\e[1;38;5;196m⚠️  No .img or .zip files found in current directory!\e[0m"
    echo -e "\e[1;38;5;244m💡 Tip: Place your .img or .zip files in this directory to see them listed here\e[0m"
    echo
fi

echo -e "\e[1;38;5;77m[1]\e[0m \e[38;5;51m📦 Upload All .img and .zip files\e[0m"
if [ ${#FILES[@]} -eq 0 ]; then
    echo -e "\e[1;38;5;244m   ├── Currently no files available\e[0m"
fi

echo -e "\e[1;38;5;77m[2]\e[0m \e[38;5;51m📁 Upload a file via custom path\e[0m"
echo -e "\e[1;38;5;244m   ├── Upload any file from your system\e[0m"

if [ ${#FILES[@]} -gt 0 ]; then
    for i in "${!FILES[@]}"; do
        echo -e "\e[1;38;5;77m[$(($i+3))]\e[0m \e[38;5;51m📄 ${FILES[$i]#./}\e[0m"
    done
fi

print_separator
echo

# Function to upload a file with progress indicator
upload_file() {
    local file=$1
    echo -e "\e[1;38;5;75m📤 Uploading: $file\e[0m"
    echo -e "\e[1;38;5;244m➜ Destination: $UPLOAD_PATH\e[0m"

    # Use scp with the SSH control socket
    scp -o ControlPath="$SOCKET" "$file" "$UPLOAD_PATH"

    # Check if the upload was successful
    if [ $? -eq 0 ]; then
        echo -e "\e[1;38;5;77m✅ Successfully uploaded $file\e[0m"
    else
        echo -e "\e[1;38;5;196m❌ Failed to upload $file\e[0m"
    fi
    echo
}

# Prompt for file selection
echo -e "\e[1;38;5;220m📝 Enter the numbers of the files to upload (e.g., 2 4 5):\e[0m"
read -p "➜ " -a selected_numbers

# Upload the selected files
for number in "${selected_numbers[@]}"; do
    if [ "$number" -eq 1 ]; then
        if [ ${#FILES[@]} -eq 0 ]; then
            echo -e "\e[1;38;5;196m❌ No files available to upload all\e[0m"
        else
            echo -e "\e[1;38;5;75m🔄 Processing all files...\e[0m"
            for file in "${FILES[@]}"; do
                upload_file "$file"
            done
        fi
    elif [ "$number" -eq 2 ]; then
        echo -e "\e[1;38;5;75m📂 Enter the full path of the file to upload:\e[0m"
        read -e -p "➜ " custom_file
        if [ -f "$custom_file" ]; then
            upload_file "$custom_file"
        else
            echo -e "\e[1;38;5;196m❌ Invalid file path: $custom_file\e[0m"
        fi
    elif [ "$number" -gt 2 ] && [ "$number" -le $(( ${#FILES[@]} + 2 )) ]; then
        upload_file "${FILES[$((number-3))]}"
    else
        echo -e "\e[1;38;5;196m❌ Invalid selection: $number\e[0m"
    fi
done

# End the SSH session
end_ssh_session

# Display stylish completion message
print_separator
print_centered "✨ Upload Process Completed ✨" "\e[1;38;5;51m"
print_centered "Thank you for using Mahesh Technicals' Tools" "\e[1;38;5;213m"
print_separator
