#!/usr/bin/env bash
# Gaming: Steam, Lutris, Heroic, Wine/Proton + NVIDIA RTX 5090 32-bit libs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_paru

# ── Multilib check ────────────────────────────────────────────────────────────
# Steam and 32-bit Wine require [multilib] in /etc/pacman.conf
log_step "Checking multilib repository"

if grep -q '^\[multilib\]' /etc/pacman.conf; then
    log_success "multilib repository is enabled"
else
    log_warn "[multilib] not found in /etc/pacman.conf"
    log_info "Enabling multilib..."
    # Uncomment [multilib] and Include line
    sudo sed -i '/^#\[multilib\]/{
        s/^#//
        n
        s/^#//
    }' /etc/pacman.conf
    sudo pacman -Sy
    log_success "multilib enabled and repos synced"
fi

# ── NVIDIA 32-bit libraries (RTX 5090) ───────────────────────────────────────
# Required for Steam (32-bit games) and Wine/DXVK/VKD3D
log_step "NVIDIA 32-bit & Vulkan libraries"

paru_install \
    lib32-nvidia-utils \
    vulkan-nvidia \
    lib32-vulkan-nvidia \
    vulkan-icd-loader \
    lib32-vulkan-icd-loader

log_success "NVIDIA Vulkan libraries installed"

# ── Steam ─────────────────────────────────────────────────────────────────────
log_step "Steam"

if pkg_installed steam; then
    log_skip "Steam"
else
    paru_install steam
    log_success "Steam installed"
fi

log_info "Enable Steam Play (Proton) in Steam Settings → Compatibility → Enable Steam Play for all titles"

# ── Proton GE (community Proton build with extra patches) ────────────────────
log_step "Proton GE (ProtonUp-Qt)"

if pkg_installed protonup-qt || is_installed protonup-qt; then
    log_skip "ProtonUp-Qt"
else
    paru_install protonup-qt
    log_success "ProtonUp-Qt installed (use it to install Proton-GE versions)"
fi

# ── Lutris ────────────────────────────────────────────────────────────────────
log_step "Lutris"

if pkg_installed lutris; then
    log_skip "Lutris"
else
    paru_install lutris
    log_success "Lutris installed"
fi

# ── Heroic Games Launcher (Epic / GOG / Amazon) ───────────────────────────────
log_step "Heroic Games Launcher"

if pkg_installed heroic-games-launcher; then
    log_skip "Heroic Games Launcher"
else
    paru_install heroic-games-launcher
    log_success "Heroic Games Launcher installed"
fi

# ── Wine staging + helpers ────────────────────────────────────────────────────
log_step "Wine staging + dependencies"

paru_install \
    wine-staging \
    winetricks \
    wine-mono \
    wine-gecko \
    lib32-gnutls \
    lib32-libpulse \
    lib32-alsa-lib \
    lib32-alsa-plugins \
    lib32-openal

log_success "Wine staging installed"

# ── Gamemode (performance governor while gaming) ──────────────────────────────
log_step "Gamemode"

if pkg_installed gamemode; then
    log_skip "Gamemode"
else
    paru_install gamemode lib32-gamemode
    # Add user to gamemode group
    sudo usermod -aG gamemode "$USER" 2>/dev/null || true
    log_success "Gamemode installed"
fi

# ── MangoHud (FPS/GPU overlay) ────────────────────────────────────────────────
log_step "MangoHud"

if pkg_installed mangohud; then
    log_skip "MangoHud"
else
    paru_install mangohud lib32-mangohud
    log_success "MangoHud installed (use MANGOHUD=1 game or enable in Steam launch options)"
fi

log_success "gaming.sh complete"
echo ""
log_info "Recommended next steps:"
log_info "  1. Launch Steam → Settings → Compatibility → Enable Steam Play for all titles"
log_info "  2. Open ProtonUp-Qt and install the latest Proton-GE"
log_info "  3. For Lutris: install runners via Lutris → Preferences → Runners"
log_info "  4. MangoHud launch option for Steam: MANGOHUD=1 %command%"
