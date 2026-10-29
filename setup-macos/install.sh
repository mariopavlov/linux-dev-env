#!/usr/bin/env bash
# macOS post-install setup — master orchestrator
#
# Tooling is split in two, the same as on every Linux directory in this repo:
#   system layer   Homebrew — Ghostty, fonts, fish, 1Password, Docker Desktop,
#                  build tools, GUI apps
#   tool layer     mise — node, go, java, bun, python, uv, neovim and the CLI
#                  tools, all pinned in dotfiles/dot_config/mise/config.toml,
#                  identical across every platform in this repo
#
# Runs under the bash 3.2 that macOS ships, so it works before Homebrew exists.
#
# 1Password secret injection (recommended, once --base has installed `op`):
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
               base → mise → langs → apps → dotfiles → agents
  --base       System layer: Homebrew, Ghostty, JetBrainsMono Nerd Font, Fish +
               Fisher, 1Password + CLI, Docker Desktop, Git config
  --mise       mise + every tool in dotfiles/dot_config/mise/config.toml
  --langs      C/C++ build tools, Rust (rustup), SDKMan, pynvim venv
  --apps       Zed, VS Code, JetBrains Toolbox
  --dotfiles   Apply dotfiles via Chezmoi (../dotfiles/)
  --agents     Claude Code, Codex, OpenCode, Herdr, integrations, Fish completion

Maintenance
  --update     Update everything already installed. Not part of --all:
               brew upgrade → mise up → rustup update → fisher update →
               chezmoi apply → lazy.nvim sync → agent CLI self-updates →
               macOS software updates
  --repos SET  Also clone the missing repos in workspace/repos-SET.txt,
               e.g. --repos graphwise (repeatable). --update and --repos
               always clone workspace/repos.txt (personal).
  -h, --help   Show this help

Examples
  bash install.sh --all
  bash install.sh --base --mise --langs
  bash install.sh --update
  bash install.sh --update --repos graphwise
  op run --env-file=~/.op-env -- bash install.sh --all

Note: --claude is currently a no-op while the skills are being rewritten.
USAGE
}

# ── Argument parsing ──────────────────────────────────────────────────────────
RUN_BASE=false
RUN_MISE=false
RUN_LANGS=false
RUN_APPS=false
RUN_DOTFILES=false
RUN_CLAUDE=false  # disabled: --claude is a no-op while skills are being rewritten
RUN_AGENTS=false
RUN_UPDATE=false
REPO_SETS=()

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

while [[ $# -gt 0 ]]; do
    arg="$1"; shift
    case "$arg" in
        --all)      RUN_BASE=true; RUN_MISE=true; RUN_LANGS=true; RUN_APPS=true
                    RUN_DOTFILES=true; RUN_AGENTS=true ;;
        --base)     RUN_BASE=true ;;
        --mise)     RUN_MISE=true ;;
        --langs)    RUN_LANGS=true ;;
        --apps)     RUN_APPS=true ;;
        --dotfiles) RUN_DOTFILES=true ;;
        --agents)   RUN_AGENTS=true ;;
        --update)   RUN_UPDATE=true ;;
        --repos)    [[ $# -gt 0 ]] || { log_error "--repos needs a set name"; exit 1; }
                    REPO_SETS+=("$1"); shift ;;
        --claude)   log_warn "--claude is currently disabled while skills are being rewritten; skipping" ;;
        -h|--help)  usage; exit 0 ;;
        *) log_error "Unknown flag: $arg"; echo ""; usage; exit 1 ;;
    esac
done

# ── Preflight ─────────────────────────────────────────────────────────────────
assert_not_root
assert_macos

# Homebrew may not exist yet — --base installs it — so this is not fatal here.
load_brew_env || true

log_step "macOS post-install setup"
log_info "Script dir: $SCRIPT_DIR"
log_info "macOS version: $(sw_vers -productVersion) ($(uname -m))"

# ── Update ────────────────────────────────────────────────────────────────────
# Standalone: updates what is installed rather than installing anything new.
if $RUN_UPDATE; then
    log_step "Updating everything"

    if is_installed brew; then
        log_step "Homebrew formulae and casks"
        brew update
        brew upgrade
        brew cleanup
        log_success "Homebrew packages upgraded"
    else
        log_warn "Homebrew not installed — run --base"
    fi

    if is_installed mise; then
        log_step "mise tools"
        mise up --yes
        mise prune --yes 2>/dev/null || true
        log_success "mise tools upgraded"
        mise ls --installed 2>/dev/null || true
    else
        log_warn "mise not installed — run --mise"
    fi

    export PATH="$HOME/.local/share/mise/shims:$HOME/.cargo/bin:$HOME/.local/bin:$HOME/.opencode/bin:$PATH"

    if is_installed rustup; then
        log_step "Rust toolchain"
        rustup update
        log_success "Rust updated"
    else
        log_skip "rustup (not installed)"
    fi

    if is_installed fish && fish -c "type -q fisher" 2>/dev/null; then
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

        # lazy-lock.json is a symlink into this repo, so the sync writes the new
        # plugin pins straight into git: review with `git diff`, commit, or
        # `git checkout` the lockfile + `:Lazy restore` to roll back.
        if is_installed nvim; then
            log_step "Neovim plugins (lazy.nvim)"
            nvim --headless "+Lazy! sync" +qa
            log_success "Neovim plugins synced — commit dotfiles/dot_config/nvim/.lazy-lock.json"
        fi
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

    # The macOS counterpart of the Linux firmware check: list, then ask, since
    # some updates restart the machine.
    log_step "macOS software updates"
    SWU_LIST="$(softwareupdate --list 2>&1 || true)"
    echo "$SWU_LIST"
    if grep -q '^\* Label:' <<<"$SWU_LIST"; then
        if confirm "Install the listed macOS updates? (some restart the Mac)"; then
            sudo softwareupdate --install --all
            log_success "macOS updates installed"
        else
            log_info "macOS updates declined"
        fi
    else
        log_info "No macOS updates available"
    fi

    echo ""
    echo -e "${BOLD}${GREEN}Update complete!${RESET}"
    exit 0
fi

# ── Steps ─────────────────────────────────────────────────────────────────────
if $RUN_BASE; then
    run_step "Base packages" bash "$SCRIPT_DIR/packages/base.sh"
    load_brew_env || true
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
    git config --global ghq.root "$HOME/workspace"
fi

# ── Workspace repos ───────────────────────────────────────────────────────────
# Clones whatever the manifests list but this machine lacks; existing repos
# are left alone. Needs the GitHub/GitLab SSH keys to work already.
if $RUN_UPDATE || [[ ${#REPO_SETS[@]} -gt 0 ]]; then
    run_step "Workspace repos" bash "$SCRIPT_DIR/../workspace/clone.sh" personal "${REPO_SETS[@]}"
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
    log_info "Shell: quit and reopen Ghostty for Fish to become your shell"
    log_info "1Password: enable Settings → Developer → 'Use the SSH agent' for SSH keys"
    log_info "Docker: open Docker.app once to accept its terms and start the engine"
fi
if $RUN_MISE; then
    log_info "mise: 'mise ls' to see what is managed, 'mise up' to upgrade everything"
    log_info "  Versions are pinned in dotfiles/dot_config/mise/config.toml — one file, every platform"
fi
if $RUN_LANGS; then
    log_info "Java comes from mise; use SDKMan for kotlin/scala/maven/gradle"
fi
if $RUN_DOTFILES; then
    log_info "Dotfiles applied — open a new Ghostty window to pick up all changes"
fi
if $RUN_CLAUDE; then
    log_info "Claude Code config linked — new skills available in all projects"
fi
if $RUN_AGENTS; then
    log_info "Agents: run 'claude', 'codex', or 'opencode' inside Herdr"
    log_info "Herdr: run 'herdr' to start or reattach; Fish completion is installed"
fi
