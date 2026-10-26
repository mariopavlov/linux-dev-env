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

# A line that is exactly `<!-- include: <path> -->` is replaced by the contents of $SRC/<path>.
# Included files are copied as-is; includes do not nest.
render() {
    local source="$1" slug line path
    slug="$(basename "$source" .md)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^'<!-- include: '(.+)' -->'$ ]]; then
            path="${BASH_REMATCH[1]}"
            if [[ ! -f "$SRC/$path" ]]; then
                echo "missing include: $path (in $slug)" >&2
                return 1
            fi
            cat "$SRC/$path"
        else
            printf '%s\n' "$line"
        fi
    done < "$source"
    printf '\n## Team rules\n\n'
    cat "$SRC/team-rules.md"
}

shopt -s nullglob
stale=0
rendered="$(mktemp)"
trap 'rm -f "$rendered"' EXIT
for source in "$SRC"/agents/*.md; do
    slug="$(basename "$source" .md)"
    target="$OUT/agents/$slug/AGENTS.md"
    # Render to a file first so a failed include stops the build in both modes.
    render "$source" > "$rendered" || exit 1
    if $CHECK; then
        if ! diff -q "$rendered" "$target" >/dev/null 2>&1; then
            echo "stale: $target" >&2
            stale=1
        fi
    else
        mkdir -p "$(dirname "$target")"
        cp "$rendered" "$target"
    fi
done

for dir in "$OUT"/agents/*/; do
    slug="$(basename "$dir")"
    [[ -f "$SRC/agents/$slug.md" ]] && continue
    if $CHECK; then
        echo "orphaned: $dir" >&2
        stale=1
    else
        rm -rf "$dir"
    fi
done

exit "$stale"
