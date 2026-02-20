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

setup_git_config() {
    echo "Setting up Git configuration..."

    # Read and set the Git username
    read -p "Enter your Git username: " git_username
    git config --global user.name "$git_username"

    # Read and set the Git email
    read -p "Enter your Git email: " git_email
    git config --global user.email "$git_email"

    # Additional configurations can be added here
    # For example, setting up default branch name, editor, etc.

    echo "Git configuration set successfully."
    echo "Username: $git_username"
    echo "Email: $git_email"

    # Optionally, display the current global Git configuration
    echo "Current global Git configuration:"
    git config --global --list
}

# Install VIM
install_vim() {
    local distro=$1
    echo "Installing VIM on $distro..."

    if [ "$distro" == "ubuntu" ]; then
        sudo apt install vim -y
    elif [ "$distro" == "fedora" ]; then
        sudo dnf install vim -y
    else
        echo "Unsupported distribution for VIM installation: $distro"
        return 1
    fi

    echo "VIM installation complete."
}

# Install Neovim
install_nvim() {
    local distro=$1
    echo "Installing VIM on $distro..."

    if [ "$distro" == "ubuntu" ]; then
        sudo apt install neovim -y
    elif [ "$distro" == "fedora" ]; then
        sudo dnf install neovim -y
    else
        echo "Unsupported distribution for Neovim installation: $distro"
        return 1
    fi

    echo "Neovim installation complete."
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
setup_git_config

install_vim $distro
install_nvim $distro


