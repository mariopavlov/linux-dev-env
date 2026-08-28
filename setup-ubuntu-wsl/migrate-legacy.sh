#!/usr/bin/env bash
# Migrate an existing Ubuntu WSL environment from the pre-mise layout.
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
assert_apt

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
        sudo apt-get remove -y "${present[@]}"
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
log_step "Go: apt → mise"
remove_pkg golang-go

# ── 4. Hand-installed binaries → mise ─────────────────────────────────────────
# These were installed from GitHub release tarballs into /usr/local/bin and had
# no upgrade path at all — the exact problem mise solves.
log_step "Hand-installed binaries → mise"

for legacy_bin in eza lazygit chezmoi starship nvim; do
    remove_path "/usr/local/bin/$legacy_bin" "now provided by mise"
done
remove_path "/opt/nvim-linux-x86_64" "Neovim now provided by mise"

# ── 5. bat / fd naming shims → mise ───────────────────────────────────────────
# mise installs these under their real names, so the Debian batcat/fdfind
# workaround is no longer needed. This is Debian-only weirdness Fedora never
# had, so removing it is also a cross-distro unification win.
log_step "bat / fd naming shims"
remove_path "$HOME/.local/bin/bat" "mise installs bat under its real name"
remove_path "$HOME/.local/bin/fd"  "mise installs fd under its real name"

# ── 6. uv installer copy → mise uv ────────────────────────────────────────────
log_step "uv: standalone installer → mise"
remove_path "$HOME/.local/bin/uv"  "uv now managed by mise"
remove_path "$HOME/.local/bin/uvx" "uv now managed by mise"

# ── 7. Distro packages superseded by mise ─────────────────────────────────────
log_step "Distro packages superseded by mise"
remove_pkg zoxide fzf bat ripgrep fd-find jq

# ── 8. Anaconda → mise python + uv ────────────────────────────────────────────
# Anaconda was dropped from this setup: it is a competing environment manager,
# and having it and mise both own PATH invites confusing breakage.
log_step "Anaconda → mise python + uv"
remove_path "$HOME/anaconda3" "replaced by mise python + uv"

if [[ -f "$HOME/.config/fish/conf.d/conda.fish" ]]; then
    remove_path "$HOME/.config/fish/conf.d/conda.fish" "leftover from 'conda init fish'"
fi

# ── 9. SDKMan — kept, not removed ─────────────────────────────────────────────
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
