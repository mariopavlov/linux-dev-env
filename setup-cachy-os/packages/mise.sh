#!/usr/bin/env bash
# mise — tool version manager (node, go, java, bun, python, uv, neovim, CLI tools)
#
# mise ships in Arch's `extra` repo, so it is installed with paru rather than the
# curl installer and upgrades with the rest of the system (`paru -Syu`). mise
# itself then manages every tool listed in dotfiles/dot_config/mise/config.toml.
#
# On a rolling distro the repo versions are already current, so this is not about
# freshness — it is about every machine in this repo resolving the same tool
# versions from the same manifest, instead of `paru` here and a tarball there.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_paru

# ── Install mise ──────────────────────────────────────────────────────────────
log_step "mise"

if is_installed mise; then
    log_skip "mise ($(mise --version))"
else
    paru_install mise
    log_success "mise installed: $(mise --version)"
fi

# ── Install the shared tool manifest ──────────────────────────────────────────
# Chezmoi normally owns ~/.config/mise/config.toml, but chezmoi is itself one of
# the tools mise installs. Break the cycle by copying the repo's copy into place
# now; the later `--dotfiles` step writes the identical file, so this is a no-op
# from Chezmoi's point of view.
log_step "mise tool manifest"

MISE_SRC="$SCRIPT_DIR/../dotfiles/dot_config/mise/config.toml"
MISE_DST="$HOME/.config/mise/config.toml"

if [[ ! -f "$MISE_SRC" ]]; then
    log_error "mise manifest not found at $MISE_SRC"
    exit 1
fi

mkdir -p "$(dirname "$MISE_DST")"
install -m 0644 "$MISE_SRC" "$MISE_DST"
log_success "Manifest installed: $MISE_DST"

mise trust "$MISE_DST" >/dev/null 2>&1 || true

# ── Install the tools ─────────────────────────────────────────────────────────
log_step "Installing tools via mise"
log_info "This compiles nothing — mise fetches prebuilt binaries — but the first"
log_info "run downloads a lot (node, go, java, python, neovim, …)"

if ! mise install --yes; then
    log_error "mise install failed"
    log_info "  Inspect with: mise ls --missing"
    log_info "  A tool missing from the registry can be given an explicit backend,"
    log_info "  e.g. 'aqua:owner/repo', in dotfiles/dot_config/mise/config.toml"
    exit 1
fi

log_success "All mise tools installed"
mise ls --installed 2>/dev/null || true

# ── PATH for non-interactive shells ───────────────────────────────────────────
# Fish gets `mise activate fish` from config.fish. Bash does not read that, and
# Neovim shells out through non-interactive bash (`:!`, `:terminal`, LSP and
# Mason spawns), so it needs mise's shims explicitly. Shims (rather than
# `mise activate bash`) are what mise recommends for non-interactive use.
#
# This replaces the old per-toolchain `source ~/.cargo/env` approach: one line
# now covers node, go, java, bun, python, uv, neovim and every CLI tool.
log_step "mise shims for bash / Neovim"

MISE_BASHRC_MARKER='# mise shims (non-interactive shells, e.g. Neovim)'
if grep -qF "$MISE_BASHRC_MARKER" "$HOME/.bashrc" 2>/dev/null; then
    log_skip "mise shims already in ~/.bashrc"
else
    cat >> "$HOME/.bashrc" <<'BASHRC'

# mise shims (non-interactive shells, e.g. Neovim)
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash --shims)"
fi
BASHRC
    log_success "mise shims added to ~/.bashrc"
fi

log_success "mise.sh complete"
