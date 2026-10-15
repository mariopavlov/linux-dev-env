#!/usr/bin/env bash
# Clone the repos listed in workspace manifests that are missing locally.
#
#   bash clone.sh personal graphwise
#
# Each SET maps to a manifest next to this script: `personal` → repos.txt,
# anything else → repos-SET.txt. ghq places every repo at
# ~/workspace/<host>/<path>; repos already there are left untouched (no pull).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ghq is a mise tool; fall back to `mise exec` when its shims are not on PATH.
if ! command -v ghq >/dev/null 2>&1; then
    if command -v mise >/dev/null 2>&1; then
        ghq() { mise exec -- ghq "$@"; }
    else
        echo "ghq not found — run install.sh --mise first" >&2
        exit 1
    fi
fi

# Same root for every shell and tool, not just this script.
git config --global ghq.root "$HOME/workspace"

[[ $# -gt 0 ]] || set -- personal

# `all` = personal + every repos-*.txt next to this script.
if [[ " $* " == *" all "* ]]; then
    sets=(personal)
    for f in "$DIR"/repos-*.txt; do
        [[ -e "$f" ]] || continue
        f="${f##*/repos-}"
        sets+=("${f%.txt}")
    done
    set -- "${sets[@]}"
fi

for set in "$@"; do
    if [[ "$set" == personal ]]; then
        manifest="$DIR/repos.txt"
    else
        manifest="$DIR/repos-$set.txt"
    fi
    if [[ ! -f "$manifest" ]]; then
        echo "No manifest for '$set' ($manifest)" >&2
        exit 1
    fi
    echo "Cloning missing repos from $(basename "$manifest")"
    grep -vE '^[[:space:]]*(#|$)' "$manifest" | ghq get --parallel
done
