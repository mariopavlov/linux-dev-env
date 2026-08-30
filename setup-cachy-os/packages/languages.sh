#!/usr/bin/env bash
# Programming languages that mise does NOT manage: C/C++ toolchain, Rust, SDKMan
#
# Node, Go, Java, Bun, Python and uv moved to mise — see packages/mise.sh and
# dotfiles/dot_config/mise/config.toml. What is left here is what genuinely
# does not belong in mise:
#
#   C/C++     system compilers and debuggers; needs system integration
#   rustup    mise's `rust` delegates to rustup anyway, and clippy / rustfmt /
#             rust-analyzer are per-toolchain rustup components
#   SDKMan    kept for its non-Java candidates (kotlin, scala, maven, gradle,
#             springboot). The JDK itself comes from mise.
#   pynvim    a dedicated venv for Neovim's Python provider — uv's job
#
# Anaconda was dropped: it is a competing environment manager and having it and
# mise both own PATH is a recipe for confusing breakage. Use mise's python plus
# uv instead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_paru

# mise-managed tools (uv) are needed below. mise.sh runs first under --all.
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

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

# ── Rust (rustup) ─────────────────────────────────────────────────────────────
log_step "Rust via rustup"

if is_installed rustup; then
    log_info "rustup already installed ($(rustup --version 2>/dev/null | head -1)) — updating"
    rustup update stable --no-self-update
else
    # Arch's rustup package is the upstream binary and stays current
    paru_install rustup
    rustup default stable
    log_success "Rust installed: $(rustc --version)"
fi

# Essential components (idempotent)
rustup component add rust-analyzer clippy rustfmt 2>/dev/null || true
log_success "Rust components: rust-analyzer, clippy, rustfmt"

# Make cargo available to bash, which is the shell Neovim shells out through.
# Every other toolchain gets this for free from the mise shims line that
# packages/mise.sh adds to ~/.bashrc; cargo needs its own because rustup is
# outside mise.
if ! grep -q 'cargo/env' "$HOME/.bashrc" 2>/dev/null; then
    echo 'source "$HOME/.cargo/env"' >> "$HOME/.bashrc"
    log_success "cargo added to ~/.bashrc (available to nvim and bash sessions)"
else
    log_skip "cargo already in ~/.bashrc"
fi

# ── pynvim (Neovim Python provider) ───────────────────────────────────────────
# uv comes from mise. A dedicated venv lets nvim's python3_host_prog import
# pynvim directly without touching the mise-managed python.
log_step "pynvim (Neovim Python provider)"

if ! is_installed uv; then
    log_error "uv not found — run 'bash install.sh --mise' first"
    exit 1
fi

NVIM_VENV="$HOME/.nvim-venv"
if [[ -f "$NVIM_VENV/bin/python" ]] && "$NVIM_VENV/bin/python" -c "import pynvim" 2>/dev/null; then
    log_skip "pynvim ($NVIM_VENV)"
else
    uv venv "$NVIM_VENV"
    uv pip install --python "$NVIM_VENV/bin/python" pynvim
    log_success "pynvim installed to $NVIM_VENV"
fi

# ── SDKMan (JVM ecosystem, minus the JDK) ─────────────────────────────────────
# SDKMan is bash-based; usable from Fish via the `bass` plugin (installed in
# base.sh). The `sdk` wrapper lives in dotfiles/dot_config/fish/config.fish.
#
# Java itself is mise's (temurin-21). mise's shims are prepended after SDKMan's
# candidate paths in config.fish, so `java` resolves to the mise JDK. Use SDKMan
# for kotlin, scala, maven, gradle, springboot and friends.
log_step "SDKMan (JVM ecosystem)"

SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"

if [[ -d "$SDKMAN_DIR" && -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    log_skip "SDKMan ($SDKMAN_DIR)"
else
    log_info "Installing SDKMan to $SDKMAN_DIR"
    export SDKMAN_DIR
    curl -s "https://get.sdkman.io" | bash
    log_success "SDKMan installed"
fi

log_info "Java comes from mise — 'mise ls java' to check, not 'sdk install java'"
log_info "Use SDKMan for other candidates: sdk install kotlin | maven | gradle"

log_success "languages.sh complete"
