#!/usr/bin/env bash
# Shared helpers for setup-fedora scripts

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────
log_info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()    { echo -e "\n${BOLD}${BLUE}▶ $*${RESET}"; }
log_skip()    { echo -e "${YELLOW}[SKIP]${RESET}  $* (already installed)"; }

# ── Checks ────────────────────────────────────────────────────────────────────

# is_installed CMD — true if command exists in PATH
is_installed() {
    command -v "$1" &>/dev/null
}

# pkg_installed PKG — true if rpm knows the package
pkg_installed() {
    rpm -q "$1" &>/dev/null
}

# assert_not_root — exit if running as root
assert_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run as root. Run as your regular user (sudo will be used internally)."
        exit 1
    fi
}

# assert_dnf — exit if dnf is not available (should always be present on Fedora)
assert_dnf() {
    if ! is_installed dnf; then
        log_error "dnf not found. This script requires Fedora or a DNF-based distribution."
        exit 1
    fi
}

# ── Step runner ───────────────────────────────────────────────────────────────

# run_step "Label" function_name [args...]
# Runs function_name, prints success/failure around it
run_step() {
    local label="$1"
    shift
    log_step "$label"
    if "$@"; then
        log_success "$label done"
    else
        log_error "$label failed (exit $?)"
        return 1
    fi
}

# ── Prompt helpers ────────────────────────────────────────────────────────────

# prompt_value VAR_NAME "Prompt text" [default]
# Sets VAR_NAME from env, or prompts user, or uses default
prompt_value() {
    local var_name="$1"
    local prompt_text="$2"
    local default="${3:-}"

    if [[ -n "${!var_name:-}" ]]; then
        log_info "$var_name set from environment"
        return
    fi

    local value
    if [[ -n "$default" ]]; then
        read -rp "$prompt_text [$default]: " value
        value="${value:-$default}"
    else
        read -rp "$prompt_text: " value
    fi

    if [[ -z "$value" ]]; then
        log_error "$var_name is required"
        exit 1
    fi

    export "$var_name=$value"
}

# ── Package helpers ───────────────────────────────────────────────────────────

# dnf_install PKG... — install with --skip-unavailable, skip already-installed
dnf_install() {
    sudo dnf install -y "$@"
}

# copr_enable REPO — enable a COPR repository (idempotent)
copr_enable() {
    local repo="$1"
    if sudo dnf copr list --enabled 2>/dev/null | grep -q "$(echo "$repo" | cut -d/ -f2)"; then
        log_skip "COPR $repo"
    else
        sudo dnf copr enable -y "$repo"
        log_success "COPR $repo enabled"
    fi
}

# confirm "Question?" — returns 0 for yes, 1 for no
confirm() {
    local prompt="$1"
    local answer
    printf "${YELLOW}?${RESET} %s [y/N] " "$prompt"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}
