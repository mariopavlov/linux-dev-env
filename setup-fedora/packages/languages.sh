#!/usr/bin/env bash
# Programming languages: C/C++, Go, Rust, SDKMan, nvm.fish, uv, Anaconda
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_dnf

# ── C / C++ toolchain ─────────────────────────────────────────────────────────
log_step "C / C++ toolchain"

dnf_install \
    gcc \
    gcc-c++ \
    clang \
    make \
    ninja-build \
    cmake \
    gdb \
    lldb \
    ccache \
    pkgconf-pkg-config

log_success "C/C++ toolchain installed (gcc, clang, cmake, ninja, make, gdb, lldb, ccache)"

# ── Go ────────────────────────────────────────────────────────────────────────
log_step "Go"

if pkg_installed golang; then
    log_skip "Go ($(go version 2>/dev/null | awk '{print $3}'))"
else
    dnf_install golang
    log_success "Go installed: $(go version | awk '{print $3}')"
fi

# ── Rust (rustup) ─────────────────────────────────────────────────────────────
log_step "Rust via rustup"

if is_installed rustup; then
    log_info "rustup already installed ($(rustup --version 2>/dev/null | head -1)) — updating"
    rustup update stable --no-self-update
else
    # Install rustup via the official installer (Fedora's rustup package works too)
    dnf_install rustup
    rustup-init -y --no-modify-path
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"
    rustup default stable
    log_success "Rust installed: $(rustc --version)"
fi

# Essential components (idempotent)
rustup component add rust-analyzer clippy rustfmt 2>/dev/null || true
log_success "Rust components: rust-analyzer, clippy, rustfmt"

# ── uv (Python packaging & venv management) ───────────────────────────────────
log_step "uv (Python)"

if is_installed uv; then
    log_skip "uv ($(uv --version))"
else
    # uv is not yet in Fedora repos; install via the official installer
    curl -LsSf https://astral.sh/uv/install.sh | sh
    log_success "uv installed: $(~/.cargo/bin/uv --version 2>/dev/null || ~/.local/bin/uv --version)"
fi

# ── SDKMan (Java) ─────────────────────────────────────────────────────────────
# SDKMan is bash-based; usable from Fish via the `bass` plugin (installed in base.sh)
# Fish config.fish adds the bass integration — see dotfiles/.config/fish/config.fish
log_step "SDKMan (Java)"

# SDKMan's installer requires both zip and unzip
if ! is_installed zip || ! is_installed unzip; then
    log_info "Installing zip/unzip (required by SDKMan)"
    dnf_install zip unzip
fi

SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"

if [[ -d "$SDKMAN_DIR" && -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    log_skip "SDKMan ($SDKMAN_DIR)"
else
    log_info "Installing SDKMan to $SDKMAN_DIR"
    export SDKMAN_DIR
    curl -s "https://get.sdkman.io" | bash
    log_success "SDKMan installed"
fi

log_info "To install a JDK, open a new shell and run: sdk install java"

# ── nvm.fish (Node version manager) ──────────────────────────────────────────
# nvm.fish is a pure-Fish reimplementation of nvm installed via Fisher (see base.sh)
log_step "Node (nvm.fish)"

if fish -c "type -q nvm" 2>/dev/null; then
    if ! fish -c "nvm list" 2>/dev/null | grep -q "lts/"; then
        log_info "Installing Node LTS via nvm.fish"
        fish -c "nvm install lts"
        log_success "Node LTS installed: $(fish -c 'node --version' 2>/dev/null)"
    else
        log_skip "Node LTS ($(fish -c 'nvm list' 2>/dev/null | grep lts | awk '{print $1}'))"
    fi

    fish -c "set --universal nvm_default_version lts"
    log_success "nvm default set to lts"
else
    log_warn "nvm.fish not found in Fish — run --base first to install Fisher plugins"
fi

# ── Anaconda (optional — large ~1 GB) ────────────────────────────────────────
log_step "Anaconda (optional)"

if is_installed conda; then
    log_skip "Anaconda"
elif [[ "${SKIP_ANACONDA:-}" == "1" ]]; then
    log_warn "Anaconda skipped (SKIP_ANACONDA=1)"
elif confirm "Install Anaconda? (~1 GB download, takes a while)"; then
    ANACONDA_INSTALLER="$(mktemp /tmp/anaconda-XXXXXX.sh)"
    log_info "Downloading latest Anaconda installer for Linux x86_64"
    curl -Lo "$ANACONDA_INSTALLER" \
        "https://repo.anaconda.com/archive/Anaconda3-2024.10-1-Linux-x86_64.sh"
    bash "$ANACONDA_INSTALLER" -b -p "$HOME/anaconda3"
    rm -f "$ANACONDA_INSTALLER"
    "$HOME/anaconda3/bin/conda" init fish 2>/dev/null || true
    log_success "Anaconda installed to ~/anaconda3"
    log_info "Run 'conda config --set auto_activate_base false' to prevent auto-activation"
else
    log_warn "Anaconda skipped. Download later from https://www.anaconda.com/download"
fi

log_success "languages.sh complete"
