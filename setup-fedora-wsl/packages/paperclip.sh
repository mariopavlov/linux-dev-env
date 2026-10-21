#!/usr/bin/env bash
# Paperclip — agent orchestration for Claude Code and Codex, served on
# http://localhost:3100 (loopback, local_trusted, telemetry off).
#
# Installed with Paperclip's own managed installer, not mise: mise's npm backend
# skips postinstall scripts, which leaves the embedded PostgreSQL without its
# shared-library symlinks. Runs as a *system* unit with User=$USER because the
# per-user systemd manager (user@UID.service) fails to start on this WSL.
# Ends by running paperclip/configure.sh, which imports the Keystone agent team.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root
assert_dnf

PAPERCLIP_VERSION="2026.1012.0"
SHIM="$HOME/.local/bin/paperclipai"
CONFIG="$HOME/.paperclip/instances/default/config.json"
HEALTH_URL="http://127.0.0.1:3100/api/health"
UNIT_DIR="${SYSTEMD_UNIT_DIR:-/etc/systemd/system}"
HEALTH_TIMEOUT="${PAPERCLIP_HEALTH_TIMEOUT:-120}"
CONFIGURE="${PAPERCLIP_CONFIGURE:-$SCRIPT_DIR/../paperclip/configure.sh}"

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

if ! is_installed node; then
    log_error "node not found — run --mise first (node is a mise-managed tool)"
    exit 1
fi

# Shared libraries for the headless Chromium that agents' mermaid-cli renders with.
dnf_install nss nspr nss-util atk at-spi2-atk at-spi2-core alsa-lib mesa-libgbm \
    libXcomposite libXdamage libXfixes libXrandr

shim_node() {
    sed -n "s/^exec '\([^']*\)'.*/\1/p" "$SHIM"
}

needs_install() {
    [[ -x "$SHIM" ]] || return 0
    [[ -e "$(shim_node)" ]] || return 0
    [[ "$("$SHIM" --version 2>/dev/null | awk '{print $1}')" == "$PAPERCLIP_VERSION" ]] || return 0
    return 1
}

health_code() {
    curl -s -o /dev/null -w '%{http_code}' "$HEALTH_URL" || true
}

restart_needed=false

log_step "Paperclip $PAPERCLIP_VERSION"
if needs_install; then
    restart_needed=true
    npx -y "paperclipai@$PAPERCLIP_VERSION" install --version "$PAPERCLIP_VERSION" --yes
    log_success "Paperclip $PAPERCLIP_VERSION installed: $SHIM"
else
    log_skip "Paperclip $PAPERCLIP_VERSION"
fi

log_step "Paperclip instance"
if [[ -f "$CONFIG" ]]; then
    log_skip "Paperclip instance ($CONFIG)"
else
    PAPERCLIP_TELEMETRY_DISABLED=1 setsid "$SHIM" onboard --yes --no-install-service </dev/null >/dev/null 2>&1 &
    onboard_pid=$!
    for _ in $(seq 1 "$HEALTH_TIMEOUT"); do
        [[ -f "$CONFIG" && "$(health_code)" == "200" ]] && break
        sleep 1
    done
    kill -- "-$onboard_pid" 2>/dev/null || true
    wait "$onboard_pid" 2>/dev/null || true
    for _ in $(seq 1 30); do
        pgrep -g "$onboard_pid" >/dev/null 2>&1 || break
        sleep 1
    done
    if [[ ! -f "$CONFIG" ]]; then
        log_error "Onboarding did not write $CONFIG"
        exit 1
    fi
    log_success "Instance onboarded (local_trusted, loopback)"
fi

node -e '
    const fs = require("fs");
    const path = process.argv[1];
    const config = JSON.parse(fs.readFileSync(path, "utf8"));
    config.telemetry = { ...config.telemetry, enabled: false };
    fs.writeFileSync(path, JSON.stringify(config, null, 2) + "\n");
' "$CONFIG"
log_success "Telemetry disabled in $CONFIG"

log_step "Paperclip system service"
unit="$(sed -e "s|@USER@|$USER|g" -e "s|@HOME@|$HOME|g" "$SCRIPT_DIR/systemd/paperclip.service")"
if [[ "$unit" != "$(cat "$UNIT_DIR/paperclip.service" 2>/dev/null)" ]]; then
    printf '%s\n' "$unit" | sudo tee "$UNIT_DIR/paperclip.service" >/dev/null
    restart_needed=true
fi
sudo systemctl daemon-reload
sudo systemctl enable --now paperclip.service
if $restart_needed; then
    sudo systemctl restart paperclip.service
    log_info "paperclip.service restarted to pick up the new install or unit"
fi
log_success "paperclip.service enabled ($UNIT_DIR/paperclip.service)"

log_step "Keystone agent team"
for _ in $(seq 1 "$HEALTH_TIMEOUT"); do
    [[ "$(health_code)" == "200" ]] && break
    sleep 1
done
if [[ "$(health_code)" != "200" ]]; then
    log_error "Paperclip is not healthy at $HEALTH_URL — check 'sudo systemctl status paperclip'"
    exit 1
fi
bash "$CONFIGURE"
log_success "Keystone agent team configured"

if ! codex login status >/dev/null 2>&1; then
    log_warn "Codex is not logged in — run 'codex login' (ChatGPT account) before starting Codex agents"
fi

log_info "Paperclip UI: http://localhost:3100 (also from Windows)"
log_success "paperclip.sh complete"
