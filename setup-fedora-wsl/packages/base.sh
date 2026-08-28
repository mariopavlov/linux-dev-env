#!/usr/bin/env bash
# Base packages (WSL variant): system layer, Fish shell, Fisher, Git config
#
# Scope note: this file installs only what must come from the system package
# manager. Developer tooling (neovim, eza, lazygit, starship, chezmoi, gh, bat,
# fd, fzf, ripgrep, jq, zoxide) is managed by mise — see packages/mise.sh and
# dotfiles/dot_config/mise/config.toml. That is what keeps this file nearly
# identical to its Ubuntu counterpart, and it removes the COPR dependencies
# (atim/starship, atim/lazygit) this file used to need.
#
# No terminal emulator (Ghostty/Alacritty), no fonts, no Docker Engine — those
# live on the Windows host under WSL: use Windows Terminal, the fonts already
# installed there, and Docker Desktop's WSL integration.
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

# ── DNF plugins (needed for config-manager, used by mise.sh) ──────────────────
log_step "DNF plugins"
sudo dnf install -y dnf5-plugin-copr 2>/dev/null || \
    sudo dnf install -y dnf-plugins-core 2>/dev/null || true

# ── Core system packages ──────────────────────────────────────────────────────
# Deliberately short. Everything here is either a mise dependency (git, curl),
# an archive tool needed by installers (zip/unzip), a system utility with no
# version pressure worth managing (htop/btop), or required for `chsh`/`usermod`
# (util-linux-user).
log_step "Installing core system packages via dnf"

dnf_install \
    git \
    curl \
    gawk \
    zip \
    unzip \
    htop \
    btop \
    util-linux-user

log_success "Core system packages installed"

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
# WSL launches the user's login shell from /etc/passwd, so usermod is enough —
# no /etc/wsl.conf change needed.
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
    log_success "Login shell for $USER set to $FISH_PATH"
fi

# Verify what /etc/passwd actually says, and explain the two ways this can
# still appear not to work after the change.
verify_login_shell() {
    local recorded
    recorded="$(getent passwd "$USER" | cut -d: -f7)"

    if [[ "$recorded" != "$FISH_PATH" ]]; then
        log_error "Login shell is still $recorded — usermod did not take effect"
        return
    fi

    log_success "/etc/passwd records $recorded for $USER"

    if [[ "${SHELL:-}" != "$FISH_PATH" ]]; then
        log_warn "This session is still running \$SHELL=${SHELL:-unset}. That is expected."
        log_info "  If Fish is STILL not your shell after reopening the distro, it is one of:"
        log_info "    1. WSL kept the old session — run 'wsl --shutdown' from Windows, then reopen"
        log_info "    2. Your Windows Terminal profile has a hardcoded command line — check its"
        log_info "       'commandLine' setting and make sure it is 'wsl.exe -d ${WSL_DISTRO_NAME:-<distro>}'"
        log_info "       with no trailing shell argument such as 'bash' or '-- bash -l'"
    fi
}
verify_login_shell

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
