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

# Function to install Zsh and set it as the default shell
install_zsh() {
    local distro=$1
    echo "Installing Zsh on $distro..."

    if [ "$distro" == "ubuntu" ]; then
        sudo apt install zsh -y
    elif [ "$distro" == "fedora" ]; then
        sudo dnf install zsh -y
    else
        echo "Unsupported distribution for Zsh installation: $distro"
        return 1
    fi

    echo "Zsh installation complete."

    # Set Zsh as the default shell
    echo "Setting Zsh as the default shell..."
    chsh -s $(which zsh)
    echo "Zsh is now the default shell."
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

# Install Zsh
install_zsh $distro

# Add additional setup steps here
