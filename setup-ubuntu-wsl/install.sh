#!/usr/bin/env bash
# Ubuntu WSL post-install setup — master orchestrator
#
# WSL-specific variant of ../setup-ubuntu: no GUI apps, no in-distro terminal
# emulator, no fonts, no Docker Engine (use Docker Desktop's WSL integration
# instead — enable this distro under Settings > Resources > WSL Integration on
# the Windows side).
#
# Usage:
#   bash install.sh --all
#   bash install.sh --base --langs
#   bash install.sh --dotfiles
#
# 1Password secret injection (recommended):
#   op run --env-file=~/.op-env -- bash install.sh --all
#
# ~/.op-env (NOT in this repo):
#   GIT_USER_NAME=op://Private/Git/username
#   GIT_USER_EMAIL=op://Private/Git/email
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

# ── Argument parsing ──────────────────────────────────────────────────────────
RUN_BASE=false
RUN_LANGS=false
RUN_DOTFILES=false
RUN_CLAUDE=false

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [--all] [--base] [--langs] [--dotfiles] [--claude]"
    echo ""
    echo "  --all        Run all steps (base → langs → dotfiles → claude)"
    echo "  --base       Core shell tools, Git config (packages/base.sh)"
    echo "  --langs      C/C++, Go, Rust, SDKMan, nvm, uv, Anaconda (packages/languages.sh)"
    echo "  --dotfiles   Apply dotfiles via Chezmoi (../dotfiles/)"
    echo "  --claude     Symlink Claude Code config from claude-skills/ into ~/.claude/"
    echo ""
    echo "WSL variant — no GUI apps, no terminal emulator, no fonts, no Docker Engine."
    echo "Tip: run with 'op run --env-file=~/.op-env -- bash install.sh --all'"
    exit 0
fi

for arg in "$@"; do
    case "$arg" in
        --all)      RUN_BASE=true; RUN_LANGS=true; RUN_DOTFILES=true; RUN_CLAUDE=true ;;
        --base)     RUN_BASE=true ;;
        --langs)    RUN_LANGS=true ;;
        --dotfiles) RUN_DOTFILES=true ;;
        --claude)   RUN_CLAUDE=true ;;
        *) log_error "Unknown flag: $arg"; exit 1 ;;
    esac
done

# ── Preflight ─────────────────────────────────────────────────────────────────
assert_not_root
assert_apt

log_step "Ubuntu WSL post-install setup"
log_info "Script dir: $SCRIPT_DIR"
if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    log_info "Distribution: ${PRETTY_NAME:-unknown} (codename: ${UBUNTU_CODENAME:-${VERSION_CODENAME:-unknown}})"
fi
if is_wsl; then
    log_info "WSL distro: ${WSL_DISTRO_NAME:-detected via /proc/version}"
else
    log_warn "WSL not detected — for a bare-metal Ubuntu install use ../setup-ubuntu instead"
fi

# ── Steps ─────────────────────────────────────────────────────────────────────
if $RUN_BASE; then
    run_step "Base packages" bash "$SCRIPT_DIR/packages/base.sh"
fi

if $RUN_LANGS; then
    run_step "Programming languages" bash "$SCRIPT_DIR/packages/languages.sh"
fi

if $RUN_DOTFILES; then
    if ! is_installed chezmoi; then
        log_error "chezmoi not found — run --base first"
        exit 1
    fi

    DOTFILES_SRC="$SCRIPT_DIR/../dotfiles"
    if [[ ! -d "$DOTFILES_SRC" ]]; then
        log_error "Dotfiles not found at $DOTFILES_SRC"
        exit 1
    fi

    log_step "Dotfiles (Chezmoi)"
    log_info "Applying dotfiles from $DOTFILES_SRC"
    chezmoi apply --source="$DOTFILES_SRC" --verbose
    log_success "Dotfiles applied"
fi

if $RUN_CLAUDE; then
    run_step "Claude Code config" bash "$SCRIPT_DIR/packages/claude.sh"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}Setup complete!${RESET}"
echo ""

if $RUN_BASE; then
    log_info "Docker: not installed here — enable this distro under Docker Desktop's"
    log_info "  Settings > Resources > WSL Integration on the Windows side"
    log_info "Shell: run 'wsl --shutdown' from Windows (or reopen the distro) for Fish to become your login shell"
fi
if $RUN_LANGS; then
    log_info "SDKMan: open a new shell and run 'sdk install java' to install a JDK"
    log_info "nvm.fish: run 'nvm install lts' in Fish to install Node LTS"
fi
if $RUN_DOTFILES; then
    log_info "Dotfiles applied — start a new Fish session to pick up all changes"
    log_info "Terminal config (Alacritty) is unused in WSL — set the font in Windows Terminal instead"
fi
if $RUN_CLAUDE; then
    log_info "Claude Code config linked — new skills available in all projects"
fi
