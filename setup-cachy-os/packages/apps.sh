#!/usr/bin/env bash
# Desktop applications: Zed, VS Code, JetBrains Toolbox, Copilot CLI
#
# The other agent CLIs (Claude Code, Codex, OpenCode, Herdr) live in agents.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_paru

# ── Zed ───────────────────────────────────────────────────────────────────────
log_step "Zed editor"

if is_installed zed; then
    log_skip "Zed ($(zed --version 2>/dev/null || echo 'already installed'))"
else
    paru_install zed
    log_success "Zed installed"
fi

# ── VS Code ───────────────────────────────────────────────────────────────────
log_step "VS Code"

if is_installed code; then
    log_skip "VS Code ($(code --version 2>/dev/null | head -1))"
else
    paru_install visual-studio-code-bin
    log_success "VS Code installed"
fi

# ── VS Code Insiders ─────────────────────────────────────────────────────────
log_step "VS Code Insiders"

if is_installed code-insiders; then
    log_skip "VS Code Insiders ($(code-insiders --version 2>/dev/null | head -1))"
else
    paru_install visual-studio-code-insiders-bin
    log_success "VS Code Insiders installed"
fi

# ── JetBrains Toolbox ─────────────────────────────────────────────────────────
log_step "JetBrains Toolbox"

# jetbrains-toolbox installs to ~/.local/share/JetBrains/Toolbox/
TOOLBOX_BIN="$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"
if [[ -x "$TOOLBOX_BIN" ]] || is_installed jetbrains-toolbox; then
    log_skip "JetBrains Toolbox"
else
    paru_install jetbrains-toolbox
    log_success "JetBrains Toolbox installed"
    log_info "Launch once to complete setup: jetbrains-toolbox"
fi

# ── GitHub Copilot CLI ────────────────────────────────────────────────────────
# Node comes from mise, whose prefix is user-owned — no sudo, which is also what
# fixes the EACCES failures the old `sudo npm install -g` produced here.
log_step "GitHub Copilot CLI"

export PATH="$HOME/.local/share/mise/shims:$PATH"

if is_installed copilot; then
    log_skip "Copilot CLI ($(copilot --version 2>/dev/null || echo 'already installed'))"
elif ! is_installed npm; then
    log_warn "npm not found — run --mise first, then re-run --apps for Copilot CLI"
else
    npm install -g @github/copilot
    log_success "Copilot CLI installed"
fi

# Codex, Claude Code, OpenCode and Herdr are installed by packages/agents.sh
# from their official native installers — run `bash install.sh --agents`.

log_success "apps.sh complete"
