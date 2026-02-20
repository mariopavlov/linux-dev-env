#!/usr/bin/env bash
# Shared helpers for setup-cachy-os scripts

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

# pkg_installed PKG — true if pacman knows the package
pkg_installed() {
    pacman -Q "$1" &>/dev/null
}

# assert_not_root — exit if running as root
assert_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run as root. Run as your regular user (sudo will be used internally)."
        exit 1
    fi
}

# assert_paru — exit if paru is not available
assert_paru() {
    if ! is_installed paru; then
        log_error "paru not found. Install it first: https://github.com/Morganamilo/paru"
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

# paru_install PKG... — install with --needed, skip already-installed
paru_install() {
    paru -S --needed --noconfirm "$@"
}

# confirm "Question?" — returns 0 for yes, 1 for no
confirm() {
    local prompt="$1"
    local answer
    read -rp "${YELLOW}?${RESET} $prompt [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}
