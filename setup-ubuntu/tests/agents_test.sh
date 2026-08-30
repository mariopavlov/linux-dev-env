#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$(cd "$TEST_DIR/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
MOCK_BIN="$TEST_ROOT/bin"
mkdir -p "$HOME" "$MOCK_BIN"
export PATH="$MOCK_BIN:/usr/bin:/bin"

cat > "$MOCK_BIN/curl" <<'MOCK_CURL'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${FAIL_INSTALLERS:-0}" == "1" ]]; then
    echo "installer unexpectedly invoked" >&2
    exit 99
fi

url="${*: -1}"
case "$url" in
    https://claude.ai/install.sh) command_name=claude ;;
    https://chatgpt.com/codex/install.sh) command_name=codex ;;
    https://opencode.ai/install) command_name=opencode ;;
    https://herdr.dev/install.sh) command_name=herdr ;;
    *) echo "unexpected installer URL: $url" >&2; exit 98 ;;
esac

if [[ "$command_name" == "herdr" ]]; then
    cat <<'INSTALL_HERDR'
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/herdr" <<'HERDR'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
    integration)
        [[ "${2:-}" == "install" ]]
        mkdir -p "$HOME/.cache/herdr-test/integrations"
        touch "$HOME/.cache/herdr-test/integrations/${3:?missing integration name}"
        ;;
    completion)
        [[ "${2:-}" == "fish" ]]
        printf '%s\n' 'complete -c herdr -f'
        ;;
    --version)
        printf '%s\n' 'herdr test'
        ;;
    *)
        echo "unexpected herdr invocation: $*" >&2
        exit 97
        ;;
esac
HERDR
chmod +x "$HOME/.local/bin/herdr"
INSTALL_HERDR
else
    if [[ "$command_name" == "opencode" ]]; then
        install_dir="$HOME/.opencode/bin"
    else
        install_dir="$HOME/.local/bin"
    fi
    printf 'mkdir -p "%s"\nprintf "#!/usr/bin/env bash\\n" > "%s/%s"\nchmod +x "%s/%s"\n' \
        "$install_dir" "$install_dir" "$command_name" "$install_dir" "$command_name"
fi
MOCK_CURL
chmod +x "$MOCK_BIN/curl"

assert_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "expected file: $path" >&2
        exit 1
    fi
}

assert_executable() {
    local path="$1"
    if [[ ! -x "$path" ]]; then
        echo "expected executable: $path" >&2
        exit 1
    fi
}

bash "$SETUP_DIR/packages/agents.sh"

for command_name in claude codex herdr; do
    assert_executable "$HOME/.local/bin/$command_name"
done
assert_executable "$HOME/.opencode/bin/opencode"

for integration_name in claude codex opencode; do
    assert_file "$HOME/.cache/herdr-test/integrations/$integration_name"
done

COMPLETION_FILE="$HOME/.config/fish/completions/herdr.fish"
assert_file "$COMPLETION_FILE"
if [[ "$(<"$COMPLETION_FILE")" != "complete -c herdr -f" ]]; then
    echo "unexpected Fish completion content" >&2
    exit 1
fi

FAIL_INSTALLERS=1 bash "$SETUP_DIR/packages/agents.sh"
FAIL_INSTALLERS=1 bash "$SETUP_DIR/install.sh" --agents

printf '%s\n' "agents_test.sh: PASS"
