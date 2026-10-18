#!/usr/bin/env bash
# Paperclip — agent orchestration for Claude Code and Codex, served on
# http://localhost:3100 (loopback, local_trusted, telemetry off).
#
# Installed with Paperclip's own managed installer, not mise: mise's npm backend
# skips postinstall scripts, which leaves the embedded PostgreSQL without its
# shared-library symlinks. Runs as a *system* unit with User=$USER because the
# per-user systemd manager (user@UID.service) fails to start on this WSL.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

assert_not_root

PAPERCLIP_VERSION="2026.1012.0"
SHIM="$HOME/.local/bin/paperclipai"
CONFIG="$HOME/.paperclip/instances/default/config.json"
HEALTH_URL="http://127.0.0.1:3100/api/health"
UNIT_DIR="${SYSTEMD_UNIT_DIR:-/etc/systemd/system}"
HEALTH_TIMEOUT="${PAPERCLIP_HEALTH_TIMEOUT:-120}"

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

if ! is_installed node; then
    log_error "node not found — run --mise first (node is a mise-managed tool)"
    exit 1
fi

shim_node() {
    sed -n "s/^exec '\([^']*\)'.*/\1/p" "$SHIM"
}

needs_install() {
    [[ -x "$SHIM" ]] || return 0
    [[ -e "$(shim_node)" ]] || return 0
    [[ "$("$SHIM" --version 2>/dev/null)" == "$PAPERCLIP_VERSION" ]] || return 0
    return 1
}

health_code() {
    curl -s -o /dev/null -w '%{http_code}' "$HEALTH_URL" || true
}

log_step "Paperclip $PAPERCLIP_VERSION"
if needs_install; then
    npx -y "paperclipai@$PAPERCLIP_VERSION" install --version "$PAPERCLIP_VERSION" --yes
    log_success "Paperclip $PAPERCLIP_VERSION installed: $SHIM"
else
    log_skip "Paperclip $PAPERCLIP_VERSION"
fi

log_step "Paperclip instance"
if [[ -f "$CONFIG" ]]; then
    log_skip "Paperclip instance ($CONFIG)"
else
    PAPERCLIP_TELEMETRY_DISABLED=1 "$SHIM" onboard --yes --no-install-service </dev/null >/dev/null 2>&1 &
    onboard_pid=$!
    for _ in $(seq 1 "$HEALTH_TIMEOUT"); do
        [[ -f "$CONFIG" && "$(health_code)" == "200" ]] && break
        sleep 1
    done
    pkill -P "$onboard_pid" 2>/dev/null || true
    kill "$onboard_pid" 2>/dev/null || true
    wait "$onboard_pid" 2>/dev/null || true
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
sed -e "s|@USER@|$USER|g" -e "s|@HOME@|$HOME|g" "$SCRIPT_DIR/systemd/paperclip.service" \
    | sudo tee "$UNIT_DIR/paperclip.service" >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now paperclip.service
log_success "paperclip.service enabled ($UNIT_DIR/paperclip.service)"

if ! codex login status 2>/dev/null | grep -qi "logged in using"; then
    log_warn "Codex is not logged in — run 'codex login' (ChatGPT account) before starting Codex agents"
fi

log_info "Paperclip UI: http://localhost:3100 (also from Windows)"
log_success "paperclip.sh complete"
