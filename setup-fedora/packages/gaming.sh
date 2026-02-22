#!/usr/bin/env bash
# Gaming: Steam, Lutris, Heroic, Faugus, Wine/Proton
# GPU auto-detected at runtime: NVIDIA discrete | Intel+NVIDIA Optimus | AMD+NVIDIA Optimus
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_dnf

# ── RPM Fusion (required for Steam, NVIDIA, Wine) ─────────────────────────────
log_step "RPM Fusion repositories"

FEDORA_VERSION=$(rpm -E %fedora)

if pkg_installed rpmfusion-free-release && pkg_installed rpmfusion-nonfree-release; then
    log_skip "RPM Fusion (free + nonfree)"
else
    log_info "Enabling RPM Fusion Free and Nonfree for Fedora $FEDORA_VERSION"
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
    log_success "RPM Fusion enabled"
fi

# Install multimedia codec group (needed by Steam, Wine, etc.)
sudo dnf group upgrade -y --with-optional Multimedia 2>/dev/null || true

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
log_step "Vulkan & Mesa base libraries"
dnf_install vulkan-loader mesa-vulkan-drivers

# ── NVIDIA driver (akmod, from RPM Fusion Nonfree) ───────────────────────────
if $HAS_NVIDIA; then
    log_step "NVIDIA driver (akmod-nvidia)"
    if pkg_installed akmod-nvidia; then
        log_skip "akmod-nvidia"
    else
        dnf_install akmod-nvidia xorg-x11-drv-nvidia-cuda
        log_success "NVIDIA driver installed — reboot required for module build to complete"
        log_warn "After reboot, verify: nvidia-smi"
    fi

    if $IS_OPTIMUS; then
        log_info "Optimus detected — to use dGPU for an app: prime-run <app>"
        log_info "Or set environment vars in per-app launch options:"
        log_info "  __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia <app>"
    fi
fi

# Intel iGPU Vulkan (ANV driver — ships in mesa, ICD registered via mesa-vulkan-drivers)
if $HAS_INTEL_GPU; then
    log_step "Intel iGPU Vulkan (ANV)"
    dnf_install mesa-vulkan-drivers
    log_success "Intel Vulkan (ANV) available via mesa-vulkan-drivers"
fi

# AMD GPU Vulkan (RADV driver — ships in mesa)
if $HAS_AMD_GPU; then
    log_step "AMD GPU Vulkan (RADV)"
    dnf_install mesa-vulkan-drivers mesa-va-drivers mesa-vdpau-drivers
    log_success "AMD Vulkan (RADV) available via mesa-vulkan-drivers"
fi

# ── Steam ─────────────────────────────────────────────────────────────────────
log_step "Steam"

if pkg_installed steam; then
    log_skip "Steam"
else
    dnf_install steam
    log_success "Steam installed"
fi

log_info "Enable Steam Play (Proton) in Steam Settings → Compatibility → Enable Steam Play for all titles"

# ── Proton GE (ProtonUp-Qt) ──────────────────────────────────────────────────
log_step "Proton GE (ProtonUp-Qt)"

if is_installed protonup-qt; then
    log_skip "ProtonUp-Qt"
else
    # ProtonUp-Qt is available as Flatpak
    if ! is_installed flatpak; then
        dnf_install flatpak
    fi
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub net.davidotek.pupgui2
    log_success "ProtonUp-Qt installed via Flatpak (use it to install Proton-GE versions)"
fi

# ── Lutris ────────────────────────────────────────────────────────────────────
log_step "Lutris"

if pkg_installed lutris; then
    log_skip "Lutris"
else
    dnf_install lutris
    log_success "Lutris installed"
fi

# ── Heroic Games Launcher (Epic / GOG / Amazon) ───────────────────────────────
log_step "Heroic Games Launcher"

if is_installed heroic; then
    log_skip "Heroic Games Launcher"
else
    if ! is_installed flatpak; then
        dnf_install flatpak
    fi
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.heroicgameslauncher.hgl
    log_success "Heroic Games Launcher installed via Flatpak"
fi

# ── Faugus Launcher (Battle.net / GE-Proton) ─────────────────────────────────
log_step "Faugus Launcher"

if is_installed faugus-launcher; then
    log_skip "Faugus Launcher"
else
    # Faugus is available via COPR
    copr_enable "faugus/faugus-launcher"
    dnf_install faugus-launcher
    log_success "Faugus Launcher installed (use with GE-Proton for Battle.net)"
fi

# ── Wine staging + helpers ────────────────────────────────────────────────────
log_step "Wine staging + dependencies"

dnf_install \
    wine \
    winetricks \
    wine-mono

log_success "Wine installed"

# ── Gamemode (performance governor while gaming) ──────────────────────────────
log_step "Gamemode"

if pkg_installed gamemode; then
    log_skip "Gamemode"
else
    dnf_install gamemode
    sudo usermod -aG gamemode "$USER" 2>/dev/null || true
    log_success "Gamemode installed"
fi

# ── MangoHud (FPS/GPU overlay) ────────────────────────────────────────────────
log_step "MangoHud"

if pkg_installed mangohud && pkg_installed mangohud.i686; then
    log_skip "MangoHud (64-bit + 32-bit)"
else
    # Install both 64-bit and 32-bit — Wine/Proton games (Battle.net, SC2) need the i686 lib
    dnf_install mangohud mangohud.i686
    log_success "MangoHud installed (64-bit + 32-bit for Wine/Proton)"
fi

log_success "gaming.sh complete"
echo ""
log_info "Recommended next steps:"
log_info "  1. Reboot if NVIDIA drivers were just installed (akmod builds on first boot)"
log_info "  2. Launch Steam → Settings → Compatibility → Enable Steam Play for all titles"
log_info "  3. Open ProtonUp-Qt (Flatpak) and install the latest GE-Proton"
log_info "  4. Battle.net: open Faugus Launcher → select GE-Proton → install Battle.net"
if $IS_OPTIMUS; then
    log_info "     Optimus detected — set these env vars inside Faugus to use the NVIDIA dGPU:"
    log_info "       __NV_PRIME_RENDER_OFFLOAD=1"
    log_info "       __GLX_VENDOR_LIBRARY_NAME=nvidia"
    log_info "       __VK_LAYER_NV_optimus=NVIDIA_only"
    log_info "     These are inherited by all games launched from Battle.net (SC2, D4, etc.)"
    log_info "     For Steam games: add the same vars before %command% in launch options"
fi
log_info "  5. For Lutris: install runners via Lutris → Preferences → Runners"
log_info "  6. MangoHud for Faugus / Battle.net games (SC2, D4, WoW, etc.):"
log_info "     Enable MangoHud in Faugus AND add this environment variable:"
log_info "       MANGOHUD_DLSYM=1"
log_info "     (Required because games launched by Battle.net are child processes;"
log_info "      MANGOHUD_DLSYM=1 switches from LD_PRELOAD to dlsym hooking so"
log_info "      the overlay works in the child game process, not just the launcher)"
log_info "  7. MangoHud launch option for Steam: MANGOHUD=1 %command%"
if $HAS_NVIDIA; then
    log_info "  8. Verify GPU: prime-run glxinfo | grep 'OpenGL renderer'"
fi
