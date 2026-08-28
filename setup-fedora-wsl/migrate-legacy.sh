#!/usr/bin/env bash
# Migrate an existing Fedora WSL environment from the pre-mise layout.
#
#   bash migrate-legacy.sh            # DRY RUN — prints what it would do
#   bash migrate-legacy.sh --apply    # actually do it
#
# Safe by design:
#   1. Dry run is the default. --apply is required to touch anything.
#   2. It refuses to run until mise has installed the replacements, so you
#      always have a working toolchain before anything is removed.
#   3. Everything removable is copied to ~/.dev-env-backup-<timestamp>/ first.
#
# If you skip this script entirely, nothing breaks. `mise activate` prepends its
# shims to PATH, so the mise-managed tools already win over the leftovers. This
# script only reclaims disk and removes the ambiguity.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_dnf

# utils' log_skip appends "(already installed)", which reads as nonsense here —
# this script reports things that are ABSENT, not things already present.
log_skip() { echo -e "${YELLOW}[SKIP]${RESET}  $*"; }


APPLY=false
FORCE=false

for arg in "$@"; do
    case "$arg" in
        --apply) APPLY=true ;;
        --force) FORCE=true ;;
        -h|--help)
            sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
            exit 0
            ;;
        *) log_error "Unknown flag: $arg"; exit 1 ;;
    esac
done

BACKUP_DIR="$HOME/.dev-env-backup-$(date +%Y%m%d-%H%M%S)"

# ── Preflight: is the replacement actually in place? ──────────────────────────
log_step "Preflight"

if ! is_installed mise; then
    log_error "mise is not installed — run 'bash install.sh --mise' first"
    exit 1
fi

REQUIRED_TOOLS=(node go java bun uv neovim eza lazygit starship chezmoi gh bat fd fzf jq ripgrep zoxide)
MISSING=()
INSTALLED_LIST="$(mise ls --installed 2>/dev/null || true)"

for tool in "${REQUIRED_TOOLS[@]}"; do
    grep -qE "^${tool}[[:space:]]" <<<"$INSTALLED_LIST" || MISSING+=("$tool")
done

if (( ${#MISSING[@]} > 0 )); then
    log_warn "mise has not installed: ${MISSING[*]}"
    if ! $FORCE; then
        log_error "Refusing to migrate before the replacements exist."
        log_info "  Run 'bash install.sh --mise', or pass --force if you know why they are absent."
        exit 1
    fi
    log_warn "--force given — continuing anyway"
else
    log_success "All ${#REQUIRED_TOOLS[@]} replacement tools are installed via mise"
fi

# The tools being installed is NOT sufficient. They must also be REACHABLE:
# `mise activate` lives in config.fish, which the --dotfiles step applies.
# Removing /usr/local/bin/starship while Fish still cannot see mise's starship
# leaves you with a broken prompt, no `ls`, and no `cat` — the tools exist on
# disk but nothing is on PATH to find them.
log_step "Preflight: shell activation"

ACTIVATION_MISSING=()

FISH_CONFIG="$HOME/.config/fish/config.fish"
if grep -q 'mise activate fish' "$FISH_CONFIG" 2>/dev/null; then
    log_success "Fish activates mise ($FISH_CONFIG)"
else
    ACTIVATION_MISSING+=("Fish: 'mise activate fish' is not in $FISH_CONFIG")
fi

if grep -q 'mise activate bash --shims' "$HOME/.bashrc" 2>/dev/null; then
    log_success "Bash has mise shims (~/.bashrc)"
else
    ACTIVATION_MISSING+=("Bash: 'mise activate bash --shims' is not in ~/.bashrc")
fi

# The decisive check: does a fresh login Fish actually resolve a mise tool?
if fish -l -c 'command -q starship; and command -q eza' 2>/dev/null; then
    log_success "A fresh login Fish resolves mise-managed tools"
else
    ACTIVATION_MISSING+=("A fresh login Fish cannot resolve starship/eza")
fi

if (( ${#ACTIVATION_MISSING[@]} > 0 )); then
    log_error "mise is installed but its tools are not reachable from your shell:"
    for problem in "${ACTIVATION_MISSING[@]}"; do
        log_error "  - $problem"
    done
    echo ""
    log_info "Removing the old copies now would leave you with no prompt and no ls."
    log_info "Fix it first:"
    log_info "  bash install.sh --dotfiles      # applies the config.fish that activates mise"
    log_info "  exec fish                       # new session"
    log_info "Then re-run this script."
    $FORCE || exit 1
    log_warn "--force given — continuing anyway"
fi

if $APPLY; then
    log_warn "APPLY mode — changes will be made. Backups go to $BACKUP_DIR"
else
    log_info "DRY RUN — nothing will be changed. Re-run with --apply to execute."
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
PLANNED=0

backup_path() {
    local path="$1"
    [[ -e "$path" ]] || return 0
    mkdir -p "$BACKUP_DIR"
    local dest="$BACKUP_DIR/$(basename "$path")"
    cp -a "$path" "$dest"
    log_info "  backed up → $dest"
}

# remove_path PATH "why"
remove_path() {
    local path="$1" why="$2"
    if [[ ! -e "$path" && ! -L "$path" ]]; then
        log_skip "$path (not present)"
        return
    fi

    (( PLANNED++ )) || true
    local size
    size="$(du -sh "$path" 2>/dev/null | cut -f1 || echo "?")"

    if $APPLY; then
        log_info "Removing $path ($size) — $why"
        backup_path "$path"
        if [[ -w "$(dirname "$path")" ]]; then
            rm -rf "$path"
        else
            sudo rm -rf "$path"
        fi
        log_success "Removed $path"
    else
        log_info "WOULD REMOVE  $path ($size) — $why"
    fi
}

# remove_pkg PKG... — drop distro packages that mise now provides
remove_pkg() {
    local present=()
    for pkg in "$@"; do
        pkg_installed "$pkg" && present+=("$pkg")
    done

    if (( ${#present[@]} == 0 )); then
        log_skip "distro packages (none of $* installed)"
        return
    fi

    (( PLANNED++ )) || true
    if $APPLY; then
        log_info "Removing distro packages: ${present[*]}"
        sudo dnf remove -y "${present[@]}"
        log_success "Removed: ${present[*]}"
    else
        log_info "WOULD REMOVE  distro packages: ${present[*]}"
    fi
}

# ── 1. nvm.fish → mise node ───────────────────────────────────────────────────
log_step "Node: nvm.fish → mise"

if fish -c "fisher list" 2>/dev/null | grep -qi 'nvm.fish'; then
    (( PLANNED++ )) || true
    if $APPLY; then
        fish -c "fisher remove jorgebucaran/nvm.fish" || log_warn "fisher remove reported an error"
        fish -c "set --erase --universal nvm_default_version" 2>/dev/null || true
        log_success "Removed Fisher plugin nvm.fish"
    else
        log_info "WOULD REMOVE  Fisher plugin jorgebucaran/nvm.fish"
    fi
else
    log_skip "nvm.fish Fisher plugin (not installed)"
fi

remove_path "$HOME/.local/share/nvm" "Node versions now managed by mise"

# ── 2. Bun → mise bun ─────────────────────────────────────────────────────────
log_step "Bun: ~/.bun → mise"
remove_path "$HOME/.bun" "Bun now managed by mise"

# ── 3. Go: distro package → mise go ───────────────────────────────────────────
log_step "Go: dnf → mise"
remove_pkg golang

# ── 4. Hand-installed binaries → mise ─────────────────────────────────────────
# These were installed from GitHub release tarballs into /usr/local/bin and had
# no upgrade path at all — the exact problem mise solves.
log_step "Hand-installed binaries → mise"

for legacy_bin in eza lazygit chezmoi starship nvim; do
    remove_path "/usr/local/bin/$legacy_bin" "now provided by mise"
done

# ── 5. uv installer copy → mise uv ────────────────────────────────────────────
log_step "uv: standalone installer → mise"
remove_path "$HOME/.local/bin/uv"  "uv now managed by mise"
remove_path "$HOME/.local/bin/uvx" "uv now managed by mise"

# ── 6. Distro packages superseded by mise ─────────────────────────────────────
log_step "Distro packages superseded by mise"
remove_pkg zoxide fzf bat ripgrep fd-find jq chezmoi neovim starship lazygit

# ── 7. Anaconda → mise python + uv ────────────────────────────────────────────
# Anaconda was dropped from this setup: it is a competing environment manager,
# and having it and mise both own PATH invites confusing breakage.
log_step "Anaconda → mise python + uv"
remove_path "$HOME/anaconda3" "replaced by mise python + uv"

if [[ -f "$HOME/.config/fish/conf.d/conda.fish" ]]; then
    remove_path "$HOME/.config/fish/conf.d/conda.fish" "leftover from 'conda init fish'"
fi

# ── 9. Stale Fish universal PATH entries ──────────────────────────────────────
# `fish_add_path` writes to the UNIVERSAL variable $fish_user_paths, which
# persists in fish_variables independently of config.fish. Deleting the
# fish_add_path line does not remove the entry, so directories removed above
# linger on PATH forever. Purge them explicitly.
log_step "Stale Fish universal PATH entries"

for stale in "$HOME/.bun/bin" "$HOME/.local/share/nvm" "$HOME/anaconda3/bin"; do
    if fish -c "contains '$stale' \$fish_user_paths" 2>/dev/null; then
        (( PLANNED++ )) || true
        if $APPLY; then
            fish -c "set -U fish_user_paths (string match -v '$stale' \$fish_user_paths)"
            log_success "Removed $stale from \$fish_user_paths"
        else
            log_info "WOULD REMOVE  $stale from Fish's universal \$fish_user_paths"
        fi
    else
        log_skip "$stale (not in \$fish_user_paths)"
    fi
done

# ── 8. SDKMan — kept, not removed ─────────────────────────────────────────────
log_step "SDKMan"
if [[ -d "$HOME/.sdkman" ]]; then
    log_info "SDKMan is KEPT — it still owns kotlin, scala, maven, gradle, springboot."
    log_info "  Java now comes from mise. If you have a SDKMan JDK installed, it stays"
    log_info "  on disk but mise's shims take precedence, so 'java' resolves to mise's."
    log_info "  To reclaim the space: sdk uninstall java <version>"
else
    log_skip "SDKMan (not installed)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if $APPLY; then
    log_success "Migration complete — $PLANNED item(s) actioned"
    [[ -d "$BACKUP_DIR" ]] && log_info "Backups: $BACKUP_DIR (delete once you are happy)"
    log_info "Start a new Fish session, then verify with: mise doctor && mise ls"
else
    log_info "$PLANNED item(s) would be actioned. Re-run with --apply to execute:"
    log_info "  bash migrate-legacy.sh --apply"
fi
