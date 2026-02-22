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
log_step "JetBrains Toolbox"

TOOLBOX_BIN="$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"
if [[ -x "$TOOLBOX_BIN" ]]; then
    log_skip "JetBrains Toolbox"
else
    log_info "Downloading JetBrains Toolbox installer"
    # Fetch the latest download URL from the JetBrains releases JSON
    TOOLBOX_URL=$(curl -s "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
releases = data.get('TBA', [])
if releases:
    for dl in releases[0].get('downloads', {}).values():
        if 'linux' in dl.get('link', ''):
            print(dl['link'])
            break
")

    if [[ -z "$TOOLBOX_URL" ]]; then
        log_error "Could not determine JetBrains Toolbox download URL"
        log_info "Download manually from: https://www.jetbrains.com/toolbox-app/"
    else
        TMPDIR_TB="$(mktemp -d)"
        curl -Lo "$TMPDIR_TB/toolbox.tar.gz" "$TOOLBOX_URL"
        tar -xzf "$TMPDIR_TB/toolbox.tar.gz" -C "$TMPDIR_TB"
        TOOLBOX_APP_DIR=$(find "$TMPDIR_TB" -maxdepth 1 -name "jetbrains-toolbox-*" -type d | head -1)
        mkdir -p "$HOME/.local/bin"
        cp "$TOOLBOX_APP_DIR/jetbrains-toolbox" "$HOME/.local/bin/"
        rm -rf "$TMPDIR_TB"
        log_success "JetBrains Toolbox installed to ~/.local/bin/"
        log_info "Launch once to complete setup: jetbrains-toolbox"
    fi
fi

log_success "apps.sh complete"
