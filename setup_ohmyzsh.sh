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


# Install OhMyZsh
install_oh_my_zsh() {
    echo "Installing Oh My Zsh..."
    if ! sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
        echo "Error: Failed to install Oh My Zsh."
        return 1
    fi

    echo "Configuring Oh My Zsh plugins (docker, git)..."

    # Backup the original .zshrc file
    cp ~/.zshrc ~/.zshrc.backup

    # Add docker and git plugins
    sed -i 's/^plugins=(/plugins=(docker git /' ~/.zshrc

    if [ $? -ne 0 ]; then
        echo "Error: Failed to configure Oh My Zsh plugins."
        return 1
    fi

    echo "Oh My Zsh installation and configuration complete."
}

install_fonts() {
    echo "Installing Powerline fonts..."

    # Define the font source directory and target directory
    font_source_dir="fonts"
    font_target_dir="$HOME/.local/share/fonts"

    # Create target directory if it doesn't exist
    mkdir -p "$font_target_dir"

    # List of font directories to install
    font_dirs=("FiraMono" "GoMono" "Hack" "Meslo Dotted" "Meslo Slashed" "SourceCodePro")

    # Copy fonts from each source subdirectory to the target directory
    for font_dir in "${font_dirs[@]}"; do
        echo "Copying $font_dir..."
        cp "$font_source_dir/$font_dir"/*.ttf "$font_target_dir"
        cp "$font_source_dir/$font_dir"/*.otf "$font_target_dir"

        if [ $? -ne 0 ]; then
            echo "Error: Failed to copy $font_dir fonts."
            return 1
        fi
    done

    # Update font cache
    fc-cache -f -v

    echo "Font installation complete."
}

# Powerlevel10k theme for ZSH
install_powerlevel10k() {
    echo "Installing Powerlevel10k theme for Oh My Zsh..."

    # Clone the Powerlevel10k repository into the Oh My Zsh custom themes directory
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone Powerlevel10k repository."
        return 1
    fi

    # Set Powerlevel10k as the default theme in .zshrc
    sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

    if [ $? -ne 0 ]; then
        echo "Error: Failed to set Powerlevel10k as the default theme."
        return 1
    fi

    echo "Powerlevel10k theme installation complete."
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
install_fonts

# Install Zsh
install_zsh $distro

# # Should be last as it terminated the script, I may need to find a way to improve the setup in future
# Install OhMyZsh
install_oh_my_zsh
# Install Powerlevel10k theme
install_powerlevel10k
