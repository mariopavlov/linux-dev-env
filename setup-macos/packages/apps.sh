#!/usr/bin/env bash
# Desktop applications: Zed, VS Code, JetBrains Toolbox
#
# Raycast is deliberately absent: it is installed and kept up to date by hand.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_macos
assert_brew

# ── Editors and IDEs ──────────────────────────────────────────────────────────
log_step "Zed editor"
cask_install zed "Zed.app"

log_step "VS Code"
cask_install visual-studio-code "Visual Studio Code.app"

# Toolbox then installs and updates the JetBrains IDEs themselves.
log_step "JetBrains Toolbox"
cask_install jetbrains-toolbox "JetBrains Toolbox.app"

log_success "apps.sh complete"
