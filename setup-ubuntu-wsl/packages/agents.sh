#!/usr/bin/env bash
# Agentic development tools: Claude Code, Codex, OpenCode, and Herdr
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root

# Native installers use these user-local locations. Export them now so tools
# installed during this script are immediately available to later steps.
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"

install_native_tool() {
    local command_name="$1"
    local display_name="$2"
    local installer_url="$3"
    local installer_shell="$4"

    log_step "$display_name"

    if is_installed "$command_name"; then
        log_skip "$display_name"
        return
    fi

    curl -fsSL "$installer_url" | "$installer_shell"
    hash -r

    if ! is_installed "$command_name"; then
        log_error "$display_name installer completed, but '$command_name' is not on PATH"
        exit 1
    fi

    log_success "$display_name installed"
}

install_native_tool \
    claude \
    "Claude Code" \
    "https://claude.ai/install.sh" \
    bash

install_native_tool \
    codex \
    "OpenAI Codex CLI" \
    "https://chatgpt.com/codex/install.sh" \
    sh

install_native_tool \
    opencode \
    "OpenCode" \
    "https://opencode.ai/install" \
    bash

install_native_tool \
    herdr \
    "Herdr" \
    "https://herdr.dev/install.sh" \
    sh

# Herdr integrations require each agent's configuration directory to exist.
# Fresh CLI installs may not create these directories until their first launch.
mkdir -p \
    "$HOME/.claude" \
    "$HOME/.codex" \
    "$HOME/.config/opencode"

log_step "Herdr agent integrations"
for agent_name in claude codex opencode; do
    herdr integration install "$agent_name"
    log_success "Herdr integration: $agent_name"
done

log_step "Herdr Fish completion"
FISH_COMPLETION_DIR="$HOME/.config/fish/completions"
FISH_COMPLETION_FILE="$FISH_COMPLETION_DIR/herdr.fish"
COMPLETION_TMP="$(mktemp)"
mkdir -p "$FISH_COMPLETION_DIR"

if herdr completion fish > "$COMPLETION_TMP"; then
    install -m 0644 "$COMPLETION_TMP" "$FISH_COMPLETION_FILE"
    rm -f "$COMPLETION_TMP"
    log_success "Fish completion installed: $FISH_COMPLETION_FILE"
else
    rm -f "$COMPLETION_TMP"
    log_error "Failed to generate Herdr Fish completion"
    exit 1
fi

log_success "agents.sh complete"
