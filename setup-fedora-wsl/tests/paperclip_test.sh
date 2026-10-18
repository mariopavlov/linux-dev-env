#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$(cd "$TEST_DIR/.." && pwd)"
REAL_NODE_DIR="$(dirname "$(command -v node)")"
TEST_ROOT="$(mktemp -d)"
trap 'pkill -f "$TEST_ROOT" 2>/dev/null || true; rm -rf "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
export USER="tester"
export SYSTEMD_UNIT_DIR="$TEST_ROOT/etc/systemd/system"
export PAPERCLIP_HEALTH_TIMEOUT=10
MOCK_BIN="$TEST_ROOT/bin"
LOG_DIR="$HOME/.cache/pc-test"
FAKE_NODE="$TEST_ROOT/node/bin/node"
mkdir -p "$HOME" "$MOCK_BIN" "$LOG_DIR" "$SYSTEMD_UNIT_DIR" "$(dirname "$FAKE_NODE")"
touch "$FAKE_NODE"
export PATH="$MOCK_BIN:$REAL_NODE_DIR:/usr/bin:/bin"
export LOG_DIR FAKE_NODE

cat > "$MOCK_BIN/npx" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "$LOG_DIR/npx.log"
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/paperclipai" <<'SHIM'
#!/usr/bin/env bash
echo "$*" >> "$LOG_DIR/paperclipai.log"
case "$1" in
    --version) echo "${MOCK_VERSION:-2026.1012.0}" ;;
    onboard)
        mkdir -p "$HOME/.paperclip/instances/default"
        printf '{"server":{"port":3100},"telemetry":{"enabled":true}}\n' > "$HOME/.paperclip/instances/default/config.json"
        bash -c 'echo $$ > "$LOG_DIR/grandchild.pid"; exec sleep 300' &
        sleep 300 ;;
esac
exit 0
SHIM
printf "exec '%s' '/payload/index.js' \"\$@\"\n" "$FAKE_NODE" >> "$HOME/.local/bin/paperclipai"
chmod +x "$HOME/.local/bin/paperclipai"
MOCK

cat > "$MOCK_BIN/curl" <<'MOCK'
#!/usr/bin/env bash
if [[ -f "$HOME/.paperclip/instances/default/config.json" ]]; then printf 200; else printf 000; fi
MOCK

cat > "$MOCK_BIN/sudo" <<'MOCK'
#!/usr/bin/env bash
"$@"
MOCK

cat > "$MOCK_BIN/systemctl" <<'MOCK'
#!/usr/bin/env bash
echo "$*" >> "$LOG_DIR/systemctl.log"
MOCK

cat > "$MOCK_BIN/codex" <<'MOCK'
#!/usr/bin/env bash
if [[ "${CODEX_LOGGED_IN:-0}" == "1" ]]; then echo "Logged in using ChatGPT" >&2; else echo "Not logged in" >&2; exit 1; fi
MOCK
chmod +x "$MOCK_BIN"/*

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() { grep -qF -- "$2" "$1" || fail "expected '$2' in $1"; }
count_lines() { [[ -f "$1" ]] && grep -cF -- "$2" "$1" || echo 0; }

UNIT="$SYSTEMD_UNIT_DIR/paperclip.service"
CONFIG="$HOME/.paperclip/instances/default/config.json"

OUT="$(bash "$SETUP_DIR/packages/paperclip.sh" 2>&1)"

assert_contains "$LOG_DIR/npx.log" "-y paperclipai@2026.1012.0 install --version 2026.1012.0 --yes"
assert_contains "$LOG_DIR/paperclipai.log" "onboard --yes --no-install-service"
[[ "$(node -e 'console.log(require(process.argv[1]).telemetry.enabled)' "$CONFIG")" == "false" ]] \
    || fail "telemetry not disabled in $CONFIG"

[[ -f "$UNIT" ]] || fail "unit not written: $UNIT"
assert_contains "$UNIT" "User=tester"
assert_contains "$UNIT" "ExecStart=$HOME/.local/bin/paperclipai run --instance default"
assert_contains "$UNIT" "Environment=PAPERCLIP_TELEMETRY_DISABLED=1"
assert_contains "$UNIT" "Environment=PATH=$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin"
assert_contains "$UNIT" "Restart=on-failure"
assert_contains "$LOG_DIR/systemctl.log" "daemon-reload"
assert_contains "$LOG_DIR/systemctl.log" "enable --now paperclip.service"

grep -qF "codex login" <<<"$OUT" || fail "expected a codex login warning"
OUT="$(CODEX_LOGGED_IN=1 bash "$SETUP_DIR/packages/paperclip.sh" 2>&1)"
grep -qF "codex login" <<<"$OUT" && fail "codex warning shown while logged in"

[[ "$(count_lines "$LOG_DIR/npx.log" install)" == 1 ]] || fail "reinstalled although up to date"
[[ "$(count_lines "$LOG_DIR/paperclipai.log" onboard)" == 1 ]] || fail "onboarded twice"

rm "$FAKE_NODE"
bash "$SETUP_DIR/packages/paperclip.sh" >/dev/null 2>&1
[[ "$(count_lines "$LOG_DIR/npx.log" install)" == 2 ]] || fail "no reinstall after the shim's node disappeared"
touch "$FAKE_NODE"

: > "$LOG_DIR/systemctl.log"
bash "$SETUP_DIR/install.sh" --paperclip >/dev/null 2>&1
assert_contains "$LOG_DIR/systemctl.log" "enable --now paperclip.service"

GRANDCHILD="$(cat "$LOG_DIR/grandchild.pid")"
kill -0 "$GRANDCHILD" 2>/dev/null && fail "onboarding left a process behind (pid $GRANDCHILD)"

: > "$LOG_DIR/systemctl.log"
CODEX_LOGGED_IN=1 bash "$SETUP_DIR/packages/paperclip.sh" >/dev/null 2>&1
grep -qF "restart paperclip.service" "$LOG_DIR/systemctl.log" && fail "restarted although nothing changed"

: > "$LOG_DIR/systemctl.log"
MOCK_VERSION=old CODEX_LOGGED_IN=1 bash "$SETUP_DIR/packages/paperclip.sh" >/dev/null 2>&1
assert_contains "$LOG_DIR/systemctl.log" "restart paperclip.service"

: > "$LOG_DIR/systemctl.log"
echo "# drift" >> "$UNIT"
CODEX_LOGGED_IN=1 bash "$SETUP_DIR/packages/paperclip.sh" >/dev/null 2>&1
assert_contains "$LOG_DIR/systemctl.log" "restart paperclip.service"

printf '%s\n' "paperclip_test.sh: PASS"
