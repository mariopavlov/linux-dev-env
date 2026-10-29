#!/usr/bin/env bash
# Shared helpers for setup-macos scripts
#
# Must stay compatible with the bash 3.2 that macOS ships in /bin/bash: these
# scripts run before Homebrew (and a newer bash) exist. No mapfile, no
# associative arrays, no ${var,,}.

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

# assert_not_root — exit if running as root
assert_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run as root. Run as your regular user (sudo will be used internally)."
        exit 1
    fi
}

# assert_macos — exit if not running on macOS
assert_macos() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        log_error "This script is for macOS. Use the matching ../setup-*/ directory on Linux."
        exit 1
    fi
}

# assert_xcode_clt — exit if the Xcode Command Line Tools are missing.
# Homebrew, git and every compiler on macOS come from them. The installer is a
# GUI dialog, so start it and ask for a re-run rather than waiting on it.
assert_xcode_clt() {
    if xcode-select -p &>/dev/null; then
        return
    fi
    log_warn "Xcode Command Line Tools not found — opening the installer"
    xcode-select --install 2>/dev/null || true
    log_error "Finish the Command Line Tools install, then re-run this step"
    exit 1
}

# load_brew_env — put Homebrew on PATH for this process if it is installed.
# Apple Silicon uses /opt/homebrew, Intel uses /usr/local; neither is on the
# PATH a fresh non-login bash gets.
load_brew_env() {
    local brew_bin
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$brew_bin" ]]; then
            eval "$("$brew_bin" shellenv)"
            return 0
        fi
    done
    return 1
}

# assert_brew — exit if Homebrew is not installed (--base installs it)
assert_brew() {
    if ! load_brew_env; then
        log_error "Homebrew not found — run 'bash install.sh --base' first"
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

# brew_install FORMULA... — install formulae; brew itself skips installed ones
brew_install() {
    brew install --quiet "$@"
}

# cask_install CASK "App Name.app" — install a cask unless the app is already
# in /Applications. Checking the app rather than `brew list` keeps a copy
# installed by hand (or from the App Store) from making brew fail with
# "there is already an App at …".
cask_install() {
    local cask="$1"
    local app="$2"
    local name="${cask##*/}"

    if [[ -d "/Applications/$app" || -d "$HOME/Applications/$app" ]]; then
        log_skip "$name ($app)"
        return
    fi
    brew install --cask --quiet "$cask"
    log_success "$name installed"
}

# confirm "Question?" — returns 0 for yes, 1 for no
confirm() {
    local prompt="$1"
    local answer
    printf "${YELLOW}?${RESET} %s [y/N] " "$prompt"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}
