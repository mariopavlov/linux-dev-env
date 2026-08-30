#!/usr/bin/env bash
# Fedora post-install setup — master orchestrator
#
# Bare-metal Fedora. For Fedora under WSL use ../setup-fedora-wsl instead: it
# drops the GUI apps, the gaming module, the terminal emulators, the fonts and
# Docker Engine, none of which belong inside a WSL distro.
#
# Tooling is split in two:
#   system layer   dnf — compilers, fish, git, terminals, fonts, Docker
#   tool layer     mise — node, go, java, bun, python, uv, neovim and the CLI
#                  tools, all pinned in dotfiles/dot_config/mise/config.toml,
#                  identical across every distro in this repo
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

usage() {
    cat <<'USAGE'
Usage: install.sh [STEPS...]

Steps
  --all        Run every install step, in order:
               base → mise → langs → apps → gaming → dotfiles → agents
  --base       System layer: dnf packages, Ghostty/Alacritty, fonts, Fish +
               Fisher, Docker CE, Git config
  --mise       mise + every tool in dotfiles/dot_config/mise/config.toml
  --langs      C/C++ toolchain, Rust (rustup), SDKMan, pynvim venv
  --apps       Zed, VS Code, JetBrains Toolbox, Ulauncher
  --gaming     Steam, Lutris, Heroic, Wine/Proton, NVIDIA
  --dotfiles   Apply dotfiles via Chezmoi (../dotfiles/)
  --agents     Claude Code, Codex, OpenCode, Herdr, integrations, Fish completion

Maintenance
  --update     Update everything already installed. Not part of --all:
               dnf upgrade → mise up → rustup update → fisher update →
               chezmoi apply → agent CLI self-updates
  -h, --help   Show this help

Migrating from the pre-mise setup
  bash migrate-legacy.sh           dry run — shows what would be removed
  bash migrate-legacy.sh --apply   remove the superseded copies (backed up first)

Examples
  bash install.sh --all
  bash install.sh --base --mise --langs
  bash install.sh --update
  op run --env-file=~/.op-env -- bash install.sh --all

Note: --claude is currently a no-op while the skills are being rewritten.
USAGE
}

# ── Argument parsing ──────────────────────────────────────────────────────────
RUN_BASE=false
RUN_MISE=false
RUN_LANGS=false
RUN_APPS=false
RUN_GAMING=false
RUN_DOTFILES=false
RUN_CLAUDE=false  # disabled: --claude is a no-op while skills are being rewritten
RUN_AGENTS=false
RUN_UPDATE=false

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

for arg in "$@"; do
    case "$arg" in
        --all)      RUN_BASE=true; RUN_MISE=true; RUN_LANGS=true; RUN_APPS=true
                    RUN_GAMING=true; RUN_DOTFILES=true; RUN_AGENTS=true ;;
        --base)     RUN_BASE=true ;;
        --mise)     RUN_MISE=true ;;
        --langs)    RUN_LANGS=true ;;
        --apps)     RUN_APPS=true ;;
        --gaming)   RUN_GAMING=true ;;
        --dotfiles) RUN_DOTFILES=true ;;
        --agents)   RUN_AGENTS=true ;;
        --update)   RUN_UPDATE=true ;;
        --claude)   log_warn "--claude is currently disabled while skills are being rewritten; skipping" ;;
        -h|--help)  usage; exit 0 ;;
        *) log_error "Unknown flag: $arg"; echo ""; usage; exit 1 ;;
    esac
done

# ── Preflight ─────────────────────────────────────────────────────────────────
assert_not_root
assert_dnf

log_step "Fedora post-install setup"
log_info "Script dir: $SCRIPT_DIR"
log_info "Fedora version: $(rpm -E %fedora)"

if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    log_warn "WSL detected — use ../setup-fedora-wsl instead; this variant installs GUI apps, fonts and Docker Engine"
fi

# ── Update ────────────────────────────────────────────────────────────────────
# Standalone: updates what is installed rather than installing anything new.
# This is the step the pre-mise setup was missing entirely — eza, lazygit,
# starship, chezmoi, neovim and bun were installed once and then never touched
# again, because every guard was a bare `is_installed` check.
if $RUN_UPDATE; then
    log_step "Updating everything"

    log_step "System packages (dnf)"
    sudo dnf upgrade -y
    log_success "dnf packages upgraded"

    if is_installed mise; then
        log_step "mise tools"
        mise up --yes
        mise prune --yes 2>/dev/null || true
        log_success "mise tools upgraded"
        mise ls --installed 2>/dev/null || true
    else
        log_warn "mise not installed — run --mise"
    fi

    if is_installed rustup; then
        log_step "Rust toolchain"
        rustup update
        log_success "Rust updated"
    else
        log_skip "rustup (not installed)"
    fi

    if fish -c "type -q fisher" 2>/dev/null; then
        log_step "Fisher plugins"
        fish -c "fisher update"
        log_success "Fisher plugins updated"
    else
        log_skip "Fisher (not installed)"
    fi

    if is_installed chezmoi && [[ -d "$SCRIPT_DIR/../dotfiles" ]]; then
        log_step "Dotfiles (Chezmoi)"
        chezmoi apply --source="$SCRIPT_DIR/../dotfiles" --verbose
        log_success "Dotfiles re-applied"
    else
        log_skip "chezmoi (not installed)"
    fi

    # Agent CLIs self-update on their own channels rather than through mise,
    # which is why they are installed by their native installers in agents.sh.
    log_step "Agent CLIs"
    is_installed claude   && { claude update       || log_warn "claude update failed"; }
    is_installed opencode && { opencode upgrade    || log_warn "opencode upgrade failed"; }
    is_installed herdr    && { herdr self update   || log_warn "herdr self update failed"; }
    is_installed codex    && log_info "codex: self-updates on launch"
    log_success "Agent CLIs updated"

    echo ""
    echo -e "${BOLD}${GREEN}Update complete!${RESET}"
    exit 0
fi

# ── Steps ─────────────────────────────────────────────────────────────────────
if $RUN_BASE; then
    run_step "Base packages" bash "$SCRIPT_DIR/packages/base.sh"
fi

if $RUN_MISE; then
    run_step "mise and managed tools" bash "$SCRIPT_DIR/packages/mise.sh"
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
    # chezmoi comes from mise, so --mise must have run at least once.
    export PATH="$HOME/.local/share/mise/shims:$PATH"

    if ! is_installed chezmoi; then
        log_error "chezmoi not found — run --mise first (chezmoi is a mise-managed tool)"
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

if $RUN_AGENTS; then
    run_step "Agentic development tools" bash "$SCRIPT_DIR/packages/agents.sh"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}Setup complete!${RESET}"
echo ""

if $RUN_BASE; then
    log_info "Docker: log out and back in (or 'newgrp docker') for group changes to take effect"
    log_info "Shell: log out and back in for Fish to become your login shell"
fi
if $RUN_MISE; then
    log_info "mise: 'mise ls' to see what is managed, 'mise up' to upgrade everything"
    log_info "  Versions are pinned in dotfiles/dot_config/mise/config.toml — one file, every distro"
fi
if $RUN_LANGS; then
    log_info "Java comes from mise; use SDKMan for kotlin/scala/maven/gradle"
fi
if $RUN_GAMING; then
    log_info "Gaming: reboot if NVIDIA drivers were just installed (akmod builds on first boot)"
fi
if $RUN_DOTFILES; then
    log_info "Dotfiles applied — start a new Fish session to pick up all changes"
fi
if $RUN_CLAUDE; then
    log_info "Claude Code config linked — new skills available in all projects"
fi
if $RUN_AGENTS; then
    log_info "Agents: run 'claude', 'codex', or 'opencode' inside Herdr"
    log_info "Herdr: run 'herdr' to start or reattach; Fish completion is installed"
fi

if $RUN_MISE; then
    echo ""
    log_info "Coming from the pre-mise setup? Reclaim the superseded copies:"
    log_info "  bash migrate-legacy.sh           # dry run"
    log_info "  bash migrate-legacy.sh --apply   # execute (backs up first)"
fi
