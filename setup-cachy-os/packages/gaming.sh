#!/usr/bin/env bash
# Gaming: Steam, Lutris, Heroic, Faugus, Wine/Proton
# GPU auto-detected at runtime: NVIDIA discrete | Intel+NVIDIA Optimus | AMD+NVIDIA Optimus
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

# ── GPU detection ─────────────────────────────────────────────────────────────
# Supports three configurations:
#   Desktop  AMD + NVIDIA         → NVIDIA discrete, AMD RADV libs
#   Laptop   Intel + NVIDIA       → Intel+NVIDIA Optimus, ANV + Prime offload
#   Laptop   AMD + NVIDIA         → AMD+NVIDIA Optimus, RADV + Prime offload
log_step "Detecting GPU configuration"

HAS_NVIDIA=false
HAS_INTEL_GPU=false
HAS_AMD_GPU=false
IS_OPTIMUS=false

_GPU_LIST=$(lspci | grep -iE 'VGA compatible controller|3D controller|Display controller')
log_info "PCI display devices detected:"
echo "$_GPU_LIST" | while IFS= read -r _line; do log_info "  $_line"; done

if echo "$_GPU_LIST" | grep -qi 'nvidia';                    then HAS_NVIDIA=true;    fi
if echo "$_GPU_LIST" | grep -qi 'intel';                     then HAS_INTEL_GPU=true; fi
if echo "$_GPU_LIST" | grep -qiE '\bamd\b|\bati\b|\bradeon'; then HAS_AMD_GPU=true;   fi
if $HAS_NVIDIA && { $HAS_INTEL_GPU || $HAS_AMD_GPU; }; then IS_OPTIMUS=true; fi

if $IS_OPTIMUS; then
    $HAS_INTEL_GPU && log_info "Config: Intel iGPU + NVIDIA Optimus" || true
    $HAS_AMD_GPU   && log_info "Config: AMD iGPU + NVIDIA Optimus"   || true
elif $HAS_NVIDIA; then
    log_info "Config: NVIDIA discrete GPU (no Optimus)"
elif $HAS_AMD_GPU; then
    log_info "Config: AMD GPU only"
fi

# ── Vulkan & Mesa libraries ───────────────────────────────────────────────────
# Base Vulkan loader + Mesa always installed (Mesa provides RADV backend and
# software fallback; Vulkan ICD loader dispatches to the right driver at runtime).
log_step "Vulkan & Mesa base libraries"
paru_install vulkan-icd-loader lib32-vulkan-icd-loader mesa lib32-mesa

# NVIDIA: proprietary Vulkan (bundled in nvidia-utils) + prime-run offload tool
if $HAS_NVIDIA; then
    log_step "NVIDIA Vulkan libraries + nvidia-prime"
    paru_install nvidia-prime lib32-nvidia-utils
    # Note: vulkan-nvidia / lib32-vulkan-nvidia are bundled inside
    # nvidia-utils / lib32-nvidia-utils — no separate package on CachyOS.
    log_success "NVIDIA Vulkan libraries installed"
fi

# Intel iGPU: ANV (Intel open-source Vulkan driver, ships in mesa but ICD
# registration requires the separate vulkan-intel package).
if $HAS_INTEL_GPU; then
    log_step "Intel iGPU Vulkan libraries (ANV)"
    paru_install vulkan-intel lib32-vulkan-intel
    log_success "Intel Vulkan (ANV) libraries installed"
fi

# AMD GPU/iGPU: RADV ICD registration (driver is in mesa, but vulkan-radeon
# provides the ICD json that makes the loader discover the RADV driver).
if $HAS_AMD_GPU; then
    log_step "AMD GPU Vulkan libraries (RADV)"
    paru_install vulkan-radeon lib32-vulkan-radeon
    log_success "AMD Vulkan (RADV) libraries installed"
fi


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

# ── Faugus Launcher (Battle.net / GE-Proton) ─────────────────────────────────
# Faugus wraps GE-Proton for non-Steam Windows games (Battle.net, etc.).
# On Optimus: set __NV_PRIME_RENDER_OFFLOAD=1 etc. in Faugus env vars,
# or rely on the session-wide nvidia-prime.conf created above.
log_step "Faugus Launcher"

if pkg_installed faugus-launcher; then
    log_skip "Faugus Launcher"
else
    paru_install faugus-launcher
    log_success "Faugus Launcher installed (use with GE-Proton for Battle.net)"
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
log_info "  2. Open ProtonUp-Qt and install the latest GE-Proton"
log_info "  3. Battle.net: open Faugus Launcher → select GE-Proton → install Battle.net"
if $IS_OPTIMUS; then
    log_info "     Optimus detected — set these env vars inside Faugus to use the NVIDIA dGPU:"
    log_info "       __NV_PRIME_RENDER_OFFLOAD=1"
    log_info "       __GLX_VENDOR_LIBRARY_NAME=nvidia"
    log_info "       __VK_LAYER_NV_optimus=NVIDIA_only"
    log_info "     These are inherited by all games launched from Battle.net (SC2, D4, etc.)"
    log_info "     For Steam games: add the same vars before %command% in launch options"
fi
log_info "  4. For Lutris: install runners via Lutris → Preferences → Runners"
log_info "  5. MangoHud launch option for Steam: MANGOHUD=1 %command%"
if $HAS_NVIDIA; then
    log_info "  6. Verify GPU: prime-run glxinfo | grep 'OpenGL renderer'"
fi
