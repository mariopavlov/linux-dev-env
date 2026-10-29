#!/usr/bin/env bash
# Base packages: Homebrew, Ghostty, fonts, Fish, 1Password, Docker, Git config
#
# Scope note: this file installs only what must come from Homebrew. Developer
# tooling (neovim, eza, lazygit, starship, chezmoi, gh, bat, fd, fzf, ripgrep,
# jq, zoxide) is managed by mise — see packages/mise.sh and
# dotfiles/dot_config/mise/config.toml — exactly as on the Linux directories.
#
# What stays here is what the Mac genuinely needs from Homebrew: the terminal,
# the font, the login shell, 1Password (the SSH agent config.fish points at)
# and a Docker engine.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_macos
assert_xcode_clt

# ── Homebrew ──────────────────────────────────────────────────────────────────
log_step "Homebrew"

if load_brew_env; then
    log_skip "Homebrew ($(brew --version | head -1))"
else
    log_info "Installing Homebrew via the official installer (asks for your password)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    load_brew_env
    log_success "Homebrew installed: $(brew --version | head -1)"
fi

# ── Core system packages ──────────────────────────────────────────────────────
# Deliberately short, mirroring the Linux lists. git and curl come with the
# Command Line Tools; htop/btop are system utilities with no version pressure
# worth managing in mise.
log_step "Installing core system packages via Homebrew"

brew_install htop btop

log_success "Core system packages installed"

# ── Ghostty terminal ──────────────────────────────────────────────────────────
# Configured by dotfiles/dot_config/ghostty/config, which Chezmoi writes to
# ~/.config/ghostty/config — Ghostty reads that path on macOS too.
log_step "Ghostty terminal"
cask_install ghostty "Ghostty.app"

# ── JetBrainsMono Nerd Font (from repo) ───────────────────────────────────────
# The Ghostty config asks for "JetBrainsMono Nerd Font Mono". Installed from the
# repo copy, as on Linux, so every machine renders the same glyph set.
log_step "JetBrainsMono Nerd Font"

FONT_SRC="$SCRIPT_DIR/../fonts/JetBrainsMono"
FONT_DST="$HOME/Library/Fonts"

if [[ -f "$FONT_DST/JetBrainsMonoNerdFontMono-Regular.ttf" ]]; then
    log_skip "JetBrainsMono Nerd Font"
else
    if [[ ! -d "$FONT_SRC" ]]; then
        log_error "Font source not found at $FONT_SRC"
        exit 1
    fi
    mkdir -p "$FONT_DST"
    cp "$FONT_SRC"/*.ttf "$FONT_DST/"
    log_success "JetBrainsMono Nerd Font installed from repo"
fi

# ── 1Password + CLI ───────────────────────────────────────────────────────────
# The app provides the SSH agent; the CLI provides `op run` for the secret
# injection the rest of this setup recommends.
log_step "1Password"
cask_install 1password "1Password.app"

if is_installed op; then
    log_skip "1Password CLI ($(op --version))"
else
    brew install --cask --quiet 1password-cli
    log_success "1Password CLI installed"
fi

# config.fish sets SSH_AUTH_SOCK to ~/.1password/agent.sock, the Linux socket
# path. On macOS the agent listens inside the app's group container instead;
# 1Password's own docs recommend this symlink so one path works everywhere.
log_step "1Password SSH agent socket"

OP_AGENT_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
OP_AGENT_LINK="$HOME/.1password/agent.sock"

if [[ -L "$OP_AGENT_LINK" && "$(readlink "$OP_AGENT_LINK")" == "$OP_AGENT_SOCK" ]]; then
    log_skip "~/.1password/agent.sock"
elif [[ -e "$OP_AGENT_LINK" && ! -L "$OP_AGENT_LINK" ]]; then
    log_warn "~/.1password/agent.sock exists and is not a symlink — leaving it alone"
else
    mkdir -p "$(dirname "$OP_AGENT_LINK")"
    ln -sfn "$OP_AGENT_SOCK" "$OP_AGENT_LINK"
    log_success "~/.1password/agent.sock → 1Password's macOS agent socket"
fi
log_info "Enable the agent in 1Password → Settings → Developer → 'Use the SSH agent'"

# ── Fish shell ────────────────────────────────────────────────────────────────
# Fish stays on the system package manager, not mise: it is the login shell, so
# it has to be a real path listed in /etc/shells for `chsh`. Pointing a login
# shell at a mise shim is a bad failure mode.
log_step "Fish shell"

if is_installed fish; then
    log_skip "Fish ($(fish --version 2>/dev/null))"
else
    brew_install fish
    log_success "Fish installed: $(fish --version)"
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

install_fisher_plugin "PatrickF1/fzf.fish"          # fzf keybindings for Fish
install_fisher_plugin "edc/bass"                    # Bass: run bash in Fish (needed for SDKMan)
install_fisher_plugin "meaningful-ooo/sponge"       # Clean Fish history of failed commands

# ── Set Fish as default shell ─────────────────────────────────────────────────
# Ghostty launches the login shell, so this is what makes it open Fish.
log_step "Setting Fish as default shell"

FISH_PATH="$(command -v fish)"
CURRENT_LOGIN_SHELL="$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}')"

if [[ "$CURRENT_LOGIN_SHELL" == "$FISH_PATH" ]]; then
    log_skip "Fish is already the login shell for $USER"
else
    if ! grep -qxF "$FISH_PATH" /etc/shells; then
        echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
        log_success "$FISH_PATH added to /etc/shells"
    fi
    sudo chsh -s "$FISH_PATH" "$USER"
    log_success "Login shell for $USER set to $FISH_PATH (new terminal windows open Fish)"
fi

# ── Docker Desktop ────────────────────────────────────────────────────────────
# macOS has no Docker Engine of its own; Docker Desktop runs one in a Linux VM
# and ships the docker CLI with compose and buildx, linked into Homebrew's bin.
# Free for personal use; work use at a company over 250 people or $10M revenue
# needs a paid Docker subscription.
log_step "Docker Desktop"
cask_install docker-desktop "Docker.app"
log_info "Open Docker.app once to accept its terms and start the engine"

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
# gh comes from mise, so it may not exist yet when --base runs standalone.
if is_installed gh; then
    if ! gh auth status &>/dev/null; then
        log_warn "GitHub CLI installed but not authenticated — run: gh auth login"
    else
        log_skip "GitHub CLI already authenticated"
    fi
else
    log_info "GitHub CLI comes from mise — run --mise, then 'gh auth login'"
fi

log_success "base.sh complete"
