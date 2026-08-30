#!/usr/bin/env bash
# Base packages: system layer, terminal, fonts, Fish, Docker, Git config
#
# Scope note: this file installs only what must come from the system package
# manager. Developer tooling (neovim, eza, lazygit, starship, chezmoi, gh, bat,
# fd, fzf, ripgrep, jq, zoxide) is managed by mise — see packages/mise.sh and
# dotfiles/dot_config/mise/config.toml. That is what removed the pile of
# GitHub-release tarball fetches this file used to carry (eza, lazygit, neovim
# into /opt), the third-party apt repo for gh, and the `batcat`/`fdfind`
# symlink shims Debian's package naming forced on us.
#
# What stays here is what a bare-metal work laptop genuinely needs from apt: the
# terminal emulator, the fonts, the login shell, and Docker Engine.
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

# ── Core system packages ──────────────────────────────────────────────────────
# Deliberately short. Everything here is either a mise dependency (git, curl),
# an archive tool needed by installers (zip/unzip), a GUI component that has no
# business in a tool-version manager (alacritty), or a system utility with no
# version pressure worth managing (htop/btop).
log_step "Installing core system packages via apt"

apt_install \
    alacritty \
    git \
    gawk \
    zip \
    unzip \
    htop \
    btop

log_success "Core system packages installed"

# ── Fish shell (PPA for Fish 4.x — Ubuntu's repo ships 3.x) ────────────────────
# Fish stays on the system package manager, not mise: it is the login shell, so
# it has to be a real path listed in /etc/shells for `usermod -s`. Pointing a
# login shell at a mise shim is a bad failure mode.
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

# nvm.fish is deliberately absent — Node is managed by mise. Run
# ./migrate-legacy.sh if you are coming from a setup that had it.
install_fisher_plugin "PatrickF1/fzf.fish"          # fzf keybindings for Fish
install_fisher_plugin "edc/bass"                    # Bass: run bash in Fish (needed for SDKMan)
install_fisher_plugin "meaningful-ooo/sponge"       # Clean Fish history of failed commands

# ── Set Fish as default shell ─────────────────────────────────────────────────
log_step "Setting Fish as default shell"

FISH_PATH="$(command -v fish)"
CURRENT_LOGIN_SHELL="$(getent passwd "$USER" | cut -d: -f7)"

if [[ "$CURRENT_LOGIN_SHELL" == "$FISH_PATH" ]]; then
    log_skip "Fish is already the login shell for $USER"
else
    if ! grep -qF "$FISH_PATH" /etc/shells; then
        echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
        log_success "$FISH_PATH added to /etc/shells"
    fi
    sudo usermod -s "$FISH_PATH" "$USER"
    log_success "Login shell for $USER set to $FISH_PATH (takes effect on next login)"
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
