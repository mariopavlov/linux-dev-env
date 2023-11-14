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

# Install Vue
install_vue() {
    echo "Installing NVM (Node Version Manager)..."

    if ! curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash; then
        echo "Error: Failed to install NVM."
        return 1
    fi

    # Load NVM into the current session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

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
install_fonts

# Install Zsh
install_zsh $distro
# Install OhMyZsh
install_oh_my_zsh

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

# Install Powerlevel10k theme
# Should be last as it terminated the script, I may need to find a way to improve the setup in future
install_powerlevel10k


# Add additional setup steps here
