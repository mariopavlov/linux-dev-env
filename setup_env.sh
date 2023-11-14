#!/bin/bash

# Global variable for distribution
distro=""

# Function to update the system
update_system() {
    local distro=$1
    echo "Updating $distro..."

    if [ "$distro" == "ubuntu" ]; then
        sudo apt update && sudo apt upgrade -y
    elif [ "$distro" == "fedora" ]; then
        sudo dnf update -y
    else
        echo "Unsupported distribution: $distro"
        return 1
    fi

    echo "$distro update complete."
}

# Install Curl
install_curl() {
    local distro=$1
    echo "Installing Curl on $distro..."

    if [ "$distro" == "ubuntu" ]; then
        sudo apt install curl -y
    elif [ "$distro" == "fedora" ]; then
        sudo dnf install curl -y
    else
        echo "Unsupported distribution for Curl installation: $distro"
        return 1
    fi

    echo "Curl installation complete."
}

# Install Git
install_git() {
    local distro=$1
    echo "Installing Git on $distro..."

    if [ "$distro" == "ubuntu" ]; then
        sudo apt install git -y
    elif [ "$distro" == "fedora" ]; then
        sudo dnf install git -y
    else
        echo "Unsupported distribution for Git installation: $distro"
        return 1
    fi

    echo "Git installation complete."
}

# Install Vue
install_vue() {
    echo "Installing NVM (Node Version Manager)..."

    if ! curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash; then
        echo "Error: Failed to install NVM."
        return 1
    fi

    # Load NVM into the current session for Zsh
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    # If using Zsh, also source the zshrc file
    [ -s "$HOME/.zshrc" ] && \. "$HOME/.zshrc"

    # Ask for Node.js version
    echo "Which version of Node.js would you like to install?"
    echo "0) Latest"
    echo "1) 18.10.0"
    read -p "Enter your choice (1 for 18.10.0, 0 for Latest): " node_choice

    if [ "$node_choice" == "0" ]; then
        nvm install node || { echo "Error: Failed to install the latest version of Node.js."; return 1; }
        nvm use node
    elif [ "$node_choice" == "1" ]; then
        nvm install 18.10.0 || { echo "Error: Failed to install Node.js version 18.10.0."; return 1; }
        nvm use 18.10.0
    else
        echo "Invalid choice. Installing the latest version of Node.js."
        nvm install node || { echo "Error: Failed to install the latest version of Node.js."; return 1; }
        nvm use node
    fi

    # Ask for Vue CLI version
    echo "Which version of Vue CLI would you like to install?"
    echo "0) Latest"
    echo "1) 5.0.8"
    read -p "Enter your choice (1 for 5.0.8, 0 for Latest): " vue_cli_choice

    if [ "$vue_cli_choice" == "0" ]; then
        npm install -g @vue/cli || { echo "Error: Failed to install the latest version of Vue CLI."; return 1; }
    elif [ "$vue_cli_choice" == "1" ]; then
        npm install -g @vue/cli@5.0.8 || { echo "Error: Failed to install Vue CLI version 5.0.8."; return 1; }
    else
        echo "Invalid choice. Installing the latest version of Vue CLI."
        npm install -g @vue/cli || { echo "Error: Failed to install the latest version of Vue CLI."; return 1; }
    fi

    echo "Vue.js environment setup complete."
}

# Determine the distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro=$ID
else
    echo "Cannot determine the distribution."
    exit 1
fi

# Update the system
update_system $distro
install_curl $distro
install_git $distro


while true; do
    echo "Select the feature to install:"
    echo "0) Exit"
    echo "1) JDK"
    echo "2) Vue.js"
    echo "3) Python"
    read -p "Enter your choice [1-4]: " choice

    case $choice in
        0) break ;;
        1) install_jdk ;;
        2) install_vue ;;
        3) install_python ;;
        *) echo "Invalid option $choice." ;;
    esac
done

# Add additional setup steps here
