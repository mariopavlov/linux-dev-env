#!/usr/bin/env bash
# Claude Code config — symlink ~/.claude/ entries from repo
#
# What gets symlinked: everything inside claude-skills/dot-claude/
# What stays local:    credentials, cache, history, and all other ~/.claude/ runtime dirs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root

CLAUDE_SRC="$SCRIPT_DIR/../claude-skills/dot-claude"
CLAUDE_DST="$HOME/.claude"

if [[ ! -d "$CLAUDE_SRC" ]]; then
    log_error "claude-skills/dot-claude not found at $CLAUDE_SRC"
    exit 1
fi

# Resolve to absolute path (handles ../  in the path)
CLAUDE_SRC="$(cd "$CLAUDE_SRC" && pwd)"

log_step "Claude Code config symlinks"
log_info "Source: $CLAUDE_SRC"
log_info "Target: $CLAUDE_DST"

# Ensure ~/.claude exists (Claude Code creates it, but guard anyway)
mkdir -p "$CLAUDE_DST"

link_item() {
    local src="$1"
    local name
    name="$(basename "$src")"
    local dst="$CLAUDE_DST/$name"

    if [[ -L "$dst" ]]; then
        local current_target
        current_target="$(readlink -f "$dst")"
        if [[ "$current_target" == "$(readlink -f "$src")" ]]; then
            log_skip "~/.claude/$name"
        else
            log_warn "~/.claude/$name → $current_target (different target, skipping)"
            log_info "  To fix: rm '$dst' and re-run"
        fi
    elif [[ -e "$dst" ]]; then
        log_warn "~/.claude/$name exists (not a symlink) — skipping"
        log_info "  To replace: rm -rf '$dst' and re-run"
    else
        ln -s "$src" "$dst"
        log_success "~/.claude/$name → $src"
    fi
}

# Symlink each item inside dot-claude/ into ~/.claude/
linked=0
for item in "$CLAUDE_SRC"/*; do
    [[ -e "$item" ]] || continue   # skip if glob matched nothing
    link_item "$item"
    (( linked++ )) || true
done

if [[ $linked -eq 0 ]]; then
    log_warn "No items found in $CLAUDE_SRC — nothing to link"
else
    log_success "claude.sh complete ($linked item(s) processed)"
fi
