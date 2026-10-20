#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${WSL_DISTRO_NAME:-}" ]]; then
    echo "The Graphwise 1Password profile requires WSL." >&2
    exit 1
fi
command -v python3 >/dev/null
command -v fish >/dev/null

CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
COMPLETION_DIR="$CONFIG_ROOT/fish/completions"
mkdir -p "$COMPLETION_DIR"
COMPLETION_TMP="$(mktemp "$COMPLETION_DIR/.glab.fish.XXXXXX")"
trap 'rm -f "$COMPLETION_TMP"' EXIT
"$HOME/.local/share/mise/shims/glab" completion -s fish > "$COMPLETION_TMP"
cat >> "$COMPLETION_TMP" <<'FISH'
complete -c glab --long-option graphwise --description 'Use the Graphwise 1Password profile'
complete -c glab --long-option profile --require-parameter --description 'Use a named 1Password profile'
FISH
fish --no-config --no-execute "$COMPLETION_TMP"
chmod 600 "$COMPLETION_TMP"
mv "$COMPLETION_TMP" "$COMPLETION_DIR/glab.fish"
trap - EXIT

install -D -m 700 "$SCRIPT_DIR/config/glab-graphwise/glab-1password" "$HOME/.local/bin/glab-1password"
install -D -m 600 "$SCRIPT_DIR/config/glab-graphwise/glab.fish" "$CONFIG_ROOT/fish/functions/glab.fish"
printf 'Installed the optional glab --graphwise profile.\nConfigure %s/glab-1password/graphwise.json, then start a new Fish session.\n' "$CONFIG_ROOT"
