#!/usr/bin/env bash
# Builds paperclip/company/agents/<slug>/AGENTS.md from src/agents/<slug>.md plus the shared
# src/team-rules.md, so every agent carries the same team rules.
#
#   bash paperclip/build.sh            write company/agents/*/AGENTS.md
#   bash paperclip/build.sh --check    exit 1 if company/ is out of date
set -euo pipefail

PAPERCLIP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$PAPERCLIP_DIR/src"
OUT="$PAPERCLIP_DIR/company"
CHECK=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --src)   SRC="$2"; shift 2 ;;
        --out)   OUT="$2"; shift 2 ;;
        --check) CHECK=true; shift ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

render() {
    cat "$1"
    printf '\n## Team rules\n\n'
    cat "$SRC/team-rules.md"
}

shopt -s nullglob
stale=0
for source in "$SRC"/agents/*.md; do
    slug="$(basename "$source" .md)"
    target="$OUT/agents/$slug/AGENTS.md"
    if $CHECK; then
        if ! diff -q <(render "$source") "$target" >/dev/null 2>&1; then
            echo "stale: $target" >&2
            stale=1
        fi
    else
        mkdir -p "$(dirname "$target")"
        render "$source" > "$target"
    fi
done

exit "$stale"
