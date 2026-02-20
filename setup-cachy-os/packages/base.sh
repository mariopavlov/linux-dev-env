#!/usr/bin/env bash
# Base packages: shell tools, terminals, fonts, Docker, Git config, Fisher
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_paru

# ── Core packages ─────────────────────────────────────────────────────────────
# fish, alacritty, fzf, eza, bat, ripgrep, fd likely already installed;
# paru --needed silently skips installed packages.
log_step "Installing core packages via paru"

paru_install \
    fish \
    starship \
    ghostty \
    ghostty-shell-integration \
    alacritty \
    zoxide \
    fzf \
    eza \
    bat \
    ripgrep \
    fd \
    zellij \
    docker \
    docker-compose \
    github-cli \
    chezmoi \
    neovim \
    ttf-jetbrains-mono-nerd \
    git \
    curl \
    wget \
    jq \
    zip \
    unzip \
    htop \
    btop

log_success "Core packages installed"

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

# ── Docker ────────────────────────────────────────────────────────────────────
log_step "Configuring Docker"

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

# ── GitHub CLI auth reminder ──────────────────────────────────────────────────
if is_installed gh; then
    if ! gh auth status &>/dev/null; then
        log_warn "GitHub CLI installed but not authenticated — run: gh auth login"
    else
        log_skip "GitHub CLI already authenticated"
    fi
fi

log_success "base.sh complete"
