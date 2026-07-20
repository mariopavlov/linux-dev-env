#!/usr/bin/env bash
# Base packages: shell tools, terminals, fonts, Docker, Git config, Fisher
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_apt

# ── Prerequisites for third-party repos ───────────────────────────────────────
# software-properties-common → add-apt-repository (PPAs)
# ca-certificates/curl/gnupg  → downloading and verifying repo signing keys
log_step "Prerequisites"
apt_install \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    curl \
    wget \
    gnupg

# ── Core packages (available in standard Ubuntu repos) ────────────────────────
log_step "Installing core packages via apt"

apt_install \
    alacritty \
    zoxide \
    fzf \
    bat \
    ripgrep \
    fd-find \
    git \
    jq \
    zip \
    unzip \
    htop \
    btop

log_success "Core packages installed"

# ── bat / fd naming shims ─────────────────────────────────────────────────────
# On Debian/Ubuntu these ship as `batcat` and `fdfind` to avoid name clashes.
# Symlink the conventional names into ~/.local/bin so configs/aliases work.
log_step "bat / fd command shims"

mkdir -p "$HOME/.local/bin"
if is_installed batcat && [[ ! -e "$HOME/.local/bin/bat" ]]; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    log_success "~/.local/bin/bat → batcat"
else
    log_skip "bat shim"
fi
if is_installed fdfind && [[ ! -e "$HOME/.local/bin/fd" ]]; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    log_success "~/.local/bin/fd → fdfind"
else
    log_skip "fd shim"
fi

# ── Fish shell (PPA for Fish 4.x — Ubuntu's repo ships 3.x) ────────────────────
log_step "Fish shell"

if is_installed fish; then
    log_skip "Fish ($(fish --version 2>/dev/null))"
else
    if ppa_add "ppa:fish-shell/release-4" 2>/dev/null; then
        apt_install fish
        log_success "Fish installed from release-4 PPA"
    else
        log_warn "Fish 4 PPA unavailable — falling back to Ubuntu's Fish"
        apt_install fish
        log_success "Fish installed from Ubuntu repos"
    fi
fi

# ── starship (official installer — not in Ubuntu repos) ───────────────────────
log_step "starship"

if is_installed starship; then
    log_skip "starship ($(starship --version | head -1))"
else
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    log_success "starship installed"
fi

# ── eza (GitHub releases binary — not in Ubuntu repos) ────────────────────────
log_step "eza"

if is_installed eza; then
    log_skip "eza"
else
    _EZA_TMP="$(mktemp -d)"
    curl -Lo "$_EZA_TMP/eza.tar.gz" \
        "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz"
    tar -xzf "$_EZA_TMP/eza.tar.gz" -C "$_EZA_TMP"
    sudo install -m 755 "$_EZA_TMP/eza" /usr/local/bin/eza
    rm -rf "$_EZA_TMP"
    log_success "eza installed from GitHub releases"
fi

# ── lazygit (GitHub releases binary — not in Ubuntu repos) ────────────────────
log_step "lazygit"

if is_installed lazygit; then
    log_skip "lazygit ($(lazygit --version | head -1))"
else
    _LG_TMP="$(mktemp -d)"
    _LG_VER="$(curl -fsSL 'https://api.github.com/repos/jesseduffield/lazygit/releases/latest' \
        | grep -Po '"tag_name": *"v\K[^"]*')"
    curl -Lo "$_LG_TMP/lazygit.tar.gz" \
        "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${_LG_VER}_Linux_x86_64.tar.gz"
    tar -xzf "$_LG_TMP/lazygit.tar.gz" -C "$_LG_TMP" lazygit
    sudo install -m 755 "$_LG_TMP/lazygit" /usr/local/bin/lazygit
    rm -rf "$_LG_TMP"
    log_success "lazygit $_LG_VER installed from GitHub releases"
fi

# ── chezmoi (official installer — not in Ubuntu repos) ────────────────────────
log_step "chezmoi"

if is_installed chezmoi; then
    log_skip "chezmoi ($(chezmoi --version | head -1))"
else
    sudo sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
    log_success "chezmoi installed to /usr/local/bin"
fi

# ── Neovim (GitHub release tarball — Ubuntu's apt version is too old for LazyVim)
log_step "Neovim"

NVIM_DIR="/opt/nvim-linux-x86_64"
if is_installed nvim && [[ -x "$NVIM_DIR/bin/nvim" ]]; then
    log_skip "Neovim ($(nvim --version | head -1))"
else
    _NVIM_TMP="$(mktemp -d)"
    curl -Lo "$_NVIM_TMP/nvim.tar.gz" \
        "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
    sudo rm -rf "$NVIM_DIR"
    sudo tar -C /opt -xzf "$_NVIM_TMP/nvim.tar.gz"
    sudo ln -sf "$NVIM_DIR/bin/nvim" /usr/local/bin/nvim
    rm -rf "$_NVIM_TMP"
    log_success "Neovim installed: $(nvim --version | head -1)"
fi

# ── GitHub CLI (official GitHub apt repo) ─────────────────────────────────────
log_step "GitHub CLI"

if is_installed gh; then
    log_skip "GitHub CLI ($(gh --version | head -1))"
else
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    APT_UPDATED=false
    apt_install gh
    log_success "GitHub CLI installed"
fi

# ── JetBrainsMono Nerd Font (from repo) ───────────────────────────────────────
log_step "JetBrainsMono Nerd Font"

FONT_SRC="$SCRIPT_DIR/../fonts/JetBrainsMono"
FONT_DST="$HOME/.local/share/fonts/JetBrainsMonoNerd"

if [[ -d "$FONT_DST" ]] && ls "$FONT_DST"/*.ttf &>/dev/null; then
    log_skip "JetBrainsMono Nerd Font"
else
    if [[ ! -d "$FONT_SRC" ]]; then
        log_error "Font source not found at $FONT_SRC"
        exit 1
    fi
    mkdir -p "$FONT_DST"
    cp "$FONT_SRC"/*.ttf "$FONT_DST/"
    fc-cache -f "$FONT_DST" &>/dev/null
    log_success "JetBrainsMono Nerd Font installed from repo"
fi

# ── Fisher (Fish plugin manager) ──────────────────────────────────────────────
log_step "Installing Fisher"

if fish -c "type -q fisher" 2>/dev/null; then
    log_skip "Fisher"
else
    fish -c "
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish \
            | source && fisher install jorgebucaran/fisher
    "
    log_success "Fisher installed"
fi

# ── Fisher plugins ────────────────────────────────────────────────────────────
log_step "Installing Fisher plugins"

install_fisher_plugin() {
    local plugin="$1"
    local name="${plugin##*/}"
    if fish -c "fisher list | grep -qi '$plugin'" 2>/dev/null; then
        log_skip "Fisher plugin: $name"
    else
        fish -c "fisher install $plugin"
        log_success "Fisher plugin: $name"
    fi
}

install_fisher_plugin "jorgebucaran/nvm.fish"       # Node version manager (pure Fish)
install_fisher_plugin "PatrickF1/fzf.fish"          # fzf keybindings for Fish
install_fisher_plugin "edc/bass"                    # Bass: run bash in Fish (needed for SDKMan)
install_fisher_plugin "meaningful-ooo/sponge"       # Clean Fish history of failed commands

# ── Set Fish as default shell ─────────────────────────────────────────────────
log_step "Setting Fish as default shell"

FISH_PATH="$(command -v fish)"
if [[ "$SHELL" == "$FISH_PATH" ]]; then
    log_skip "Fish is already the default shell"
else
    if ! grep -qF "$FISH_PATH" /etc/shells; then
        echo "$FISH_PATH" | sudo tee -a /etc/shells
    fi
    sudo usermod -s "$FISH_PATH" "$USER"
    log_success "Default shell set to Fish (takes effect on next login)"
fi

# ── Docker CE (official Docker apt repo) ──────────────────────────────────────
log_step "Docker CE"

if is_installed docker && pkg_installed docker-ce; then
    log_skip "Docker ($(docker --version 2>/dev/null))"
else
    # Remove distro/legacy Docker packages that conflict with Docker CE
    for _pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        sudo apt-get remove -y "$_pkg" 2>/dev/null || true
    done

    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    . /etc/os-release
    _DOCKER_CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${_DOCKER_CODENAME} stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    APT_UPDATED=false
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    log_success "Docker CE installed"
fi

sudo systemctl enable --now docker
log_success "Docker service enabled"

if groups "$USER" | grep -qw docker; then
    log_skip "User $USER already in docker group"
else
    sudo usermod -aG docker "$USER"
    log_warn "Added $USER to docker group — log out and back in (or run 'newgrp docker')"
fi

# ── Git configuration ─────────────────────────────────────────────────────────
# Secrets are NOT stored in this repo.
# Pass via environment:  op run --env-file=~/.op-env -- bash install.sh --base
# Or set manually:       GIT_USER_NAME="..." GIT_USER_EMAIL="..." bash install.sh --base
log_step "Configuring Git"

EXISTING_NAME="$(git config --global user.name 2>/dev/null || true)"
EXISTING_EMAIL="$(git config --global user.email 2>/dev/null || true)"

if [[ -n "$EXISTING_NAME" && -n "$EXISTING_EMAIL" ]]; then
    log_skip "Git already configured ($EXISTING_NAME <$EXISTING_EMAIL>)"
else
    prompt_value GIT_USER_NAME  "Git user name"
    prompt_value GIT_USER_EMAIL "Git user email"
    git config --global user.name  "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    log_success "Git configured for $GIT_USER_NAME <$GIT_USER_EMAIL>"
fi

git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global push.autoSetupRemote true
git config --global core.editor nvim
git config --global diff.tool  vimdiff

# useful aliases
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.lg "log --oneline --graph --decorate --all"

# better diffs and logs
git config --global diff.colorMoved zebra
git config --global merge.conflictstyle diff3

# ── GitHub CLI auth reminder ──────────────────────────────────────────────────
if is_installed gh; then
    if ! gh auth status &>/dev/null; then
        log_warn "GitHub CLI installed but not authenticated — run: gh auth login"
    else
        log_skip "GitHub CLI already authenticated"
    fi
fi

log_success "base.sh complete"
