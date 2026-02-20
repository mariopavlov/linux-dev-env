#!/usr/bin/env bash
# CachyOS post-install setup — master orchestrator
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
RUN_APPS=false
RUN_GAMING=false
RUN_DOTFILES=false

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [--all] [--base] [--langs] [--apps] [--gaming] [--dotfiles]"
    echo ""
    echo "  --all        Run all steps"
    echo "  --base       Core shell tools, fonts, Docker, Git (packages/base.sh)"
    echo "  --langs      C/C++, Go, Rust, SDKMan, nvm, uv, Anaconda (packages/languages.sh)"
    echo "  --apps       Zed, VS Code, JetBrains Toolbox (packages/apps.sh)"
    echo "  --gaming     Steam, Lutris, Heroic, Wine/Proton (packages/gaming.sh)"
    echo "  --dotfiles   Apply dotfiles via Chezmoi (dotfiles/)"
    echo ""
    echo "Tip: run with 'op run --env-file=~/.op-env -- bash install.sh --all'"
    exit 0
fi

for arg in "$@"; do
    case "$arg" in
        --all)      RUN_BASE=true; RUN_LANGS=true; RUN_APPS=true; RUN_GAMING=true; RUN_DOTFILES=true ;;
        --base)     RUN_BASE=true ;;
        --langs)    RUN_LANGS=true ;;
        --apps)     RUN_APPS=true ;;
        --gaming)   RUN_GAMING=true ;;
        --dotfiles) RUN_DOTFILES=true ;;
        *) log_error "Unknown flag: $arg"; exit 1 ;;
    esac
done

# ── Preflight ─────────────────────────────────────────────────────────────────
assert_not_root
assert_paru

log_step "CachyOS post-install setup"
log_info "Script dir: $SCRIPT_DIR"

# ── Steps ─────────────────────────────────────────────────────────────────────
if $RUN_BASE; then
    run_step "Base packages" bash "$SCRIPT_DIR/packages/base.sh"
fi

if $RUN_LANGS; then
    run_step "Programming languages" bash "$SCRIPT_DIR/packages/languages.sh"
fi

if $RUN_APPS; then
    run_step "Desktop applications" bash "$SCRIPT_DIR/packages/apps.sh"
fi

if $RUN_GAMING; then
    run_step "Gaming setup" bash "$SCRIPT_DIR/packages/gaming.sh"
fi

if $RUN_DOTFILES; then
    if ! is_installed chezmoi; then
        log_error "chezmoi not found — run --base first"
        exit 1
    fi

    DOTFILES_SRC="$SCRIPT_DIR/dotfiles"
    log_step "Dotfiles (Chezmoi)"
    log_info "Applying dotfiles from $DOTFILES_SRC"
    chezmoi apply --source="$DOTFILES_SRC" --verbose
    log_success "Dotfiles applied"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}Setup complete!${RESET}"
echo ""

if $RUN_BASE; then
    log_info "Docker: log out and back in (or 'newgrp docker') for group changes to take effect"
fi
if $RUN_LANGS; then
    log_info "SDKMan: open a new shell and run 'sdk install java' to install a JDK"
    log_info "nvm.fish: run 'nvm install lts' in Fish to install Node LTS"
fi
if $RUN_DOTFILES; then
    log_info "Dotfiles applied — start a new Fish session to pick up all changes"
fi
