#!/usr/bin/env bash
# Desktop applications: Zed, VS Code, JetBrains Toolbox
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_dnf

# ── Zed editor ─────────────────────────────────────────────────────────────────
log_step "Zed editor"

if is_installed zed; then
    log_skip "Zed ($(zed --version 2>/dev/null || echo 'already installed'))"
else
    log_info "Installing Zed via official installer"
    curl -f https://zed.dev/install.sh | sh
    log_success "Zed installed"
fi

# ── VS Code (Microsoft DNF repo) ──────────────────────────────────────────────
log_step "VS Code"

if is_installed code; then
    log_skip "VS Code ($(code --version 2>/dev/null | head -1))"
else
    log_info "Adding Microsoft VS Code repository"
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo sh -c 'cat > /etc/yum.repos.d/vscode.repo << EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF'
    sudo dnf check-update || true
    dnf_install code
    log_success "VS Code installed"
fi

# ── JetBrains Toolbox ─────────────────────────────────────────────────────────
# Manual install required: download the tarball from https://www.jetbrains.com/toolbox-app/
# Extract and run the jetbrains-toolbox binary — it self-installs to ~/.local/share/JetBrains/
log_step "JetBrains Toolbox"

TOOLBOX_BIN="$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"
if [[ -x "$TOOLBOX_BIN" ]]; then
    log_skip "JetBrains Toolbox"
else
    log_warn "JetBrains Toolbox not installed — download manually from:"
    log_info "  https://www.jetbrains.com/toolbox-app/"
fi

# ── Ulauncher (application launcher) ──────────────────────────────────────────
log_step "Ulauncher"

if is_installed ulauncher; then
    log_skip "Ulauncher"
else
    dnf_install ulauncher
    log_success "Ulauncher installed"
fi

# ── wmctrl (required for Ulauncher hotkey on Wayland) ─────────────────────────
# On Wayland (Fedora default), Ulauncher cannot receive global hotkey events from
# some windows (terminals, OS Settings). The workaround is to register the hotkey
# via GNOME's custom shortcuts using the `ulauncher-toggle` command instead.
log_step "wmctrl (Ulauncher Wayland hotkey fix)"

if is_installed wmctrl; then
    log_skip "wmctrl"
else
    dnf_install wmctrl
    log_success "wmctrl installed"
fi

log_warn "Ulauncher Wayland hotkey — manual steps required:"
log_info "  1. Open Ulauncher Preferences → set hotkey to something unused (e.g. Ctrl+F23)"
log_info "  2. Open Settings → Keyboard → Keyboard Shortcuts → Custom Shortcuts → +"
log_info "     Name: Ulauncher"
log_info "     Command: ulauncher-toggle"
log_info "     Shortcut: Alt+Space"

log_success "apps.sh complete"
