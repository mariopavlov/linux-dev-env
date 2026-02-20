#!/usr/bin/env bash
# Programming languages: C/C++, Go, Rust, SDKMan, nvm.fish, uv, Anaconda
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_paru

# ── C / C++ toolchain ─────────────────────────────────────────────────────────
log_step "C / C++ toolchain"

paru_install \
    gcc \
    clang \
    make \
    ninja \
    cmake \
    gdb \
    lldb \
    ccache \
    pkgconf

log_success "C/C++ toolchain installed (gcc, clang, cmake, ninja, make, gdb, lldb, ccache)"

# ── Go ────────────────────────────────────────────────────────────────────────
log_step "Go"

if pkg_installed go; then
    log_skip "Go ($(go version 2>/dev/null | awk '{print $3}'))"
else
    paru_install go
    log_success "Go installed: $(go version | awk '{print $3}')"
fi

# ── Rust (rustup) ─────────────────────────────────────────────────────────────
log_step "Rust via rustup"

if is_installed rustup; then
    log_info "rustup already installed ($(rustup --version 2>/dev/null | head -1)) — updating"
    rustup update stable --no-self-update
else
    paru_install rustup
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
    paru_install uv
    log_success "uv installed: $(uv --version)"
fi

# ── SDKMan (Java) ─────────────────────────────────────────────────────────────
# SDKMan is bash-based; usable from Fish via the `bass` plugin (installed in base.sh)
# Fish config.fish adds the bass integration — see dotfiles/.config/fish/config.fish
log_step "SDKMan (Java)"

# SDKMan's installer requires both zip and unzip
if ! is_installed zip || ! is_installed unzip; then
    log_info "Installing zip/unzip (required by SDKMan)"
    paru_install zip unzip
fi

SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"

if [[ -d "$SDKMAN_DIR" && -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    log_skip "SDKMan ($SDKMAN_DIR)"
else
    log_info "Installing SDKMan to $SDKMAN_DIR"
    # SDKMAN_DIR must be exported before the installer checks it
    export SDKMAN_DIR
    curl -s "https://get.sdkman.io" | bash
    log_success "SDKMan installed"
fi

log_info "To install a JDK, open a new shell and run: sdk install java"

# ── nvm.fish (Node version manager) ──────────────────────────────────────────
# nvm.fish is a pure-Fish reimplementation of nvm installed via Fisher (see base.sh)
# Verify it's available and install LTS Node if not present
log_step "Node (nvm.fish)"

if fish -c "type -q nvm" 2>/dev/null; then
    if fish -c "nvm current" 2>/dev/null | grep -qv "none"; then
        log_skip "Node ($(fish -c 'node --version' 2>/dev/null || echo 'version check failed'))"
    else
        log_info "Installing Node LTS via nvm.fish"
        fish -c "nvm install lts && nvm use lts"
        log_success "Node LTS installed: $(fish -c 'node --version' 2>/dev/null)"
    fi
else
    log_warn "nvm.fish not found in Fish — run --base first to install Fisher plugins"
fi

# ── Anaconda (optional — large ~1 GB) ────────────────────────────────────────
log_step "Anaconda (optional)"

CONDA_PATH="$HOME/anaconda3/bin/conda"

if [[ -x "$CONDA_PATH" ]] || is_installed conda; then
    log_skip "Anaconda ($(conda --version 2>/dev/null || echo 'already installed'))"
elif [[ "${SKIP_ANACONDA:-}" == "1" ]]; then
    log_warn "Anaconda skipped (SKIP_ANACONDA=1)"
elif confirm "Install Anaconda? (~1 GB download, takes a while)"; then
    paru_install anaconda
    # Conda init for Fish
    conda init fish 2>/dev/null || true
    log_success "Anaconda installed"
    log_info "Run 'conda config --set auto_activate_base false' to prevent auto-activation"
else
    log_warn "Anaconda skipped. Install later with: paru -S anaconda"
fi

log_success "languages.sh complete"
