#!/usr/bin/env bash
# Base packages: system layer, terminals, fonts, Fish, Docker, Git config
#
# Scope note: this file installs only what must come from the system package
# manager. Developer tooling (neovim, eza, lazygit, starship, chezmoi, gh, bat,
# fd, fzf, ripgrep, jq, zoxide) is managed by mise — see packages/mise.sh and
# dotfiles/dot_config/mise/config.toml. That removed the COPR dependencies this
# file used to need for starship and lazygit, and the hand-rolled eza tarball
# fetch that had no upgrade path at all.
#
# What stays here is what a bare-metal desktop genuinely needs from dnf: the
# terminal emulators, the fonts, the login shell, and Docker Engine.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_dnf

# ── DNF performance tweaks ─────────────────────────────────────────────────────
log_step "Configuring DNF"

if ! grep -q '^max_parallel_downloads' /etc/dnf/dnf.conf; then
    echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf >/dev/null
    echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf >/dev/null
    log_success "DNF parallel downloads and fastest mirror enabled"
else
    log_skip "DNF already configured"
fi

# ── DNF plugins (needed for copr and config-manager commands) ─────────────────
log_step "DNF plugins"
# Fedora 41+ uses dnf5; the copr plugin ships separately
sudo dnf install -y dnf5-plugin-copr 2>/dev/null || \
    sudo dnf install -y dnf-plugins-core 2>/dev/null || true

# ── Ghostty terminal (MUST come before fish) ───────────────────────────────────
# ghostty conflicts with ncurses-term (which fish depends on).
# Installing ghostty first with --allowerasing removes ncurses-term cleanly
# before fish is installed, avoiding collateral removal of fish later.
#
# Ghostty is not in default Fedora repos — pull from the scottames/ghostty COPR
# (the install path recommended by upstream).
log_step "Ghostty terminal"

if is_installed ghostty; then
    log_skip "Ghostty ($(ghostty --version 2>/dev/null | head -1))"
else
    copr_enable "scottames/ghostty"
    sudo dnf install -y --allowerasing ghostty
    log_success "Ghostty installed"
fi

# ── ncurses-term (fish/ghostty conflict workaround) ───────────────────────────
# fish has a hard dependency on ncurses-term, but ncurses-term and ghostty both
# ship /usr/share/terminfo/g/ghostty. Use rpm --replacefiles to install
# ncurses-term alongside ghostty (the file content is identical).
log_step "ncurses-term (fish/ghostty conflict workaround)"

if pkg_installed ncurses-term; then
    log_skip "ncurses-term"
else
    _NT_TMP="$(mktemp -d)"
    sudo dnf download ncurses-term --destdir "$_NT_TMP" -y
    sudo rpm -Uvh --replacefiles "$_NT_TMP"/ncurses-term-*.rpm
    rm -rf "$_NT_TMP"
    log_success "ncurses-term installed alongside ghostty"
fi

# ── Core system packages ──────────────────────────────────────────────────────
# Deliberately short. Everything here is either a mise dependency (git, curl),
# an archive tool needed by installers (zip/unzip), a GUI component that has no
# business in a tool-version manager (alacritty), a system utility with no
# version pressure worth managing (htop/btop), or required for `chsh`/`usermod`
# (util-linux-user).
log_step "Installing core system packages via dnf"

dnf_install \
    alacritty \
    git \
    curl \
    gawk \
    zip \
    unzip \
    htop \
    btop \
    util-linux-user

log_success "Core system packages installed"

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
    fc-cache -fv "$FONT_DST" &>/dev/null
    log_success "JetBrainsMono Nerd Font installed from repo"
fi

# ── Fish shell ────────────────────────────────────────────────────────────────
# Fish stays on the system package manager, not mise: it is the login shell, so
# it has to be a real path listed in /etc/shells for `usermod -s`. Pointing a
# login shell at a mise shim is a bad failure mode.
log_step "Fish shell"

if is_installed fish; then
    log_skip "Fish ($(fish --version 2>/dev/null))"
else
    dnf_install fish
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

# ── Docker CE (official Docker repo) ──────────────────────────────────────────
log_step "Docker CE"

if is_installed docker; then
    log_skip "Docker ($(docker --version 2>/dev/null))"
else
    sudo dnf config-manager addrepo \
        --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
    dnf_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
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
