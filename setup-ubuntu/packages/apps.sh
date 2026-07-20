#!/usr/bin/env bash
# Desktop applications: Zed, VS Code, Ulauncher
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_apt

# ── Zed editor ─────────────────────────────────────────────────────────────────
log_step "Zed editor"

if is_installed zed; then
    log_skip "Zed ($(zed --version 2>/dev/null || echo 'already installed'))"
else
    log_info "Installing Zed via official installer"
    curl -f https://zed.dev/install.sh | sh
    log_success "Zed installed"
fi

# ── VS Code (Microsoft apt repo) ──────────────────────────────────────────────
log_step "VS Code"

if is_installed code; then
    log_skip "VS Code ($(code --version 2>/dev/null | head -1))"
else
    log_info "Adding Microsoft VS Code repository"
    _MS_TMP="$(mktemp -d)"
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor > "$_MS_TMP/packages.microsoft.gpg"
    sudo install -D -o root -g root -m 644 \
        "$_MS_TMP/packages.microsoft.gpg" /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    rm -rf "$_MS_TMP"
    APT_UPDATED=false
    apt_install code
    log_success "VS Code installed"
fi

# ── Ulauncher (application launcher, official PPA) ────────────────────────────
log_step "Ulauncher"

if is_installed ulauncher; then
    log_skip "Ulauncher"
else
    ppa_add "ppa:agornostal/ulauncher"
    apt_install ulauncher
    log_success "Ulauncher installed"
fi

# ── wmctrl (Ulauncher Wayland hotkey helper) ──────────────────────────────────
# On the default GNOME/Wayland session, apps can't grab global hotkeys directly.
# The workaround is to bind `ulauncher-toggle` via a GNOME custom shortcut.
log_step "wmctrl (Ulauncher helper)"

if is_installed wmctrl; then
    log_skip "wmctrl"
else
    apt_install wmctrl
    log_success "wmctrl installed"
fi

if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    log_warn "Ulauncher on Wayland — bind the hotkey manually:"
    log_info "  1. Open Ulauncher Preferences → set hotkey to something unused (e.g. Ctrl+F23)"
    log_info "  2. Settings → Keyboard → View and Customize Shortcuts → Custom Shortcuts → +"
    log_info "     Name: Ulauncher   Command: ulauncher-toggle   Shortcut: Alt+Space"
else
    log_info "Ulauncher hotkey (Alt+Space) works out of the box on X11 sessions"
fi

log_success "apps.sh complete"
