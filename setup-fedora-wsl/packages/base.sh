#!/usr/bin/env bash
# Base packages (WSL variant): shell tools, Git config, Fisher
#
# No terminal emulator (Ghostty/Alacritty), no fonts, no Docker Engine —
# those live on the Windows host under WSL: use Windows Terminal, the
# fonts already installed there, and Docker Desktop's WSL integration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_dnf

# ── DNF performance tweaks ─────────────────────────────────────────────────────
log_step "Configuring DNF"

if ! grep -q '^max_parallel_downloads' /etc/dnf/dnf.conf; then
    echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf
    echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf
    log_success "DNF parallel downloads and fastest mirror enabled"
else
    log_skip "DNF already configured"
fi

# ── DNF plugins (needed for copr and config-manager commands) ─────────────────
log_step "DNF plugins"
# Fedora 41+ uses dnf5; the copr plugin ships separately
sudo dnf install -y dnf5-plugin-copr 2>/dev/null || \
    sudo dnf install -y dnf-plugins-core 2>/dev/null || true

# ── Core packages (available in standard Fedora repos) ────────────────────────
log_step "Installing core packages via dnf"

dnf_install \
    fish \
    zoxide \
    fzf \
    bat \
    ripgrep \
    fd-find \
    chezmoi \
    neovim \
    git \
    curl \
    gawk \
    jq \
    zip \
    unzip \
    htop \
    btop \
    util-linux-user

log_success "Core packages installed"

# ── starship (COPR atim/starship — not in standard Fedora repos) ──────────────
log_step "starship"

if is_installed starship; then
    log_skip "starship ($(starship --version | head -1))"
else
    copr_enable "atim/starship"
    dnf_install starship
    log_success "starship installed"
fi

# ── eza (GitHub releases binary — no COPR for F43) ───────────────────────────
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

# ── lazygit ───────────────────────────────────────────────────────────────────
log_step "lazygit"

if is_installed lazygit; then
    log_skip "lazygit ($(lazygit --version | head -1))"
elif sudo dnf install -y lazygit 2>/dev/null; then
    log_success "lazygit installed from Fedora repos"
else
    copr_enable "atim/lazygit"
    dnf_install lazygit
    log_success "lazygit installed from COPR"
fi

# ── GitHub CLI (official GitHub DNF repo) ─────────────────────────────────────
log_step "GitHub CLI"

if is_installed gh; then
    log_skip "GitHub CLI ($(gh --version | head -1))"
else
    sudo dnf config-manager addrepo \
        --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
    dnf_install gh
    log_success "GitHub CLI installed"
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

# ── Docker ────────────────────────────────────────────────────────────────────
# Not installed here — use Docker Desktop's WSL integration instead
# (Settings > Resources > WSL Integration > enable this distro). That gives
# you the docker CLI + daemon from the Windows-side Docker Desktop without
# needing systemd or a second daemon running inside this distro.
log_step "Docker"
log_info "Skipping Docker install — enable WSL integration for this distro in Docker Desktop"

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
