#!/usr/bin/env bash
# Checks that every agent in src/agents/ is wired into configure.sh and the company package, and
# that every reporting line points at an existing agent.
#
#   bash paperclip/tests/team_test.sh [PAPERCLIP_DIR]
set -euo pipefail

SELF="${BASH_SOURCE[0]}"
REPO_PAPERCLIP="$(cd "$(dirname "$SELF")/.." && pwd)"
MAPS=(NAME MODEL EFFORT ICON PALETTE SKILLS)

fail() { echo "FAIL: $*" >&2; exit 1; }

map_value() {
    local dir="$1" map="$2" slug="$3"
    sed -n "/^declare -A $map=(/,/^)/p" "$dir/configure.sh" \
        | sed -n "s/^ *\[$slug\]=\"\(.*\)\"\$/\1/p" | head -n1
}

map_has() {
    local dir="$1" map="$2" slug="$3"
    sed -n "/^declare -A $map=(/,/^)/p" "$dir/configure.sh" | grep -q "^ *\[$slug\]="
}

frontmatter() {
    local file="$1" key="$2"
    awk '/^---$/{n++; next} n==1' "$file" | sed -n "s/^$key: \"\(.*\)\"\$/\1/p"
}

check() {
    local dir="$1" source slug name manager
    for source in "$dir"/src/agents/*.md; do
        slug="$(basename "$source" .md)"
        for map in "${MAPS[@]}"; do
            map_has "$dir" "$map" "$slug" || fail "$slug missing from $map"
        done
        name="$(frontmatter "$source" name)"
        [[ "$(map_value "$dir" NAME "$slug")" == "$name" ]] \
            || fail "$slug: NAME is '$(map_value "$dir" NAME "$slug")', frontmatter name is '$name'"
        grep -q "^  $slug:\$" "$dir/company/.paperclip.yaml" || fail "$slug missing from .paperclip.yaml"
        manager="$(frontmatter "$source" reportsTo)"
        [[ -z "$manager" || -f "$dir/src/agents/$manager.md" ]] || fail "$slug reports to unknown $manager"
        if grep -qE '\b[Pp]ush\b' "$source"; then
            grep -qE "^GITLAB_PUSHERS=\"(.* )?$slug( .*)?\"" "$dir/configure.sh" \
                || fail "$slug pushes but is missing from GITLAB_PUSHERS"
        fi
    done
    for slug in $(sed -n '/^declare -A NAME=(/,/^)/p' "$dir/configure.sh" | sed -n 's/^ *\[\([^]]*\)\]=.*/\1/p'); do
        [[ -f "$dir/src/agents/$slug.md" ]] || fail "NAME has $slug but there is no src/agents/$slug.md"
    done
    for slug in $(sed -n 's/^declare -A RENAMED=(\(.*\))$/\1/p' "$dir/configure.sh" | grep -o '\[[^]]*\]' | tr -d '[]'); do
        [[ -f "$dir/src/agents/$slug.md" ]] || fail "RENAMED has $slug but there is no src/agents/$slug.md"
    done
}

if [[ $# -gt 0 ]]; then
    check "$1"
    exit 0
fi

check "$REPO_PAPERCLIP"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
expect_fail() {
    local reason="$1" out
    if out="$(bash "$SELF" "$TEST_ROOT/p" 2>&1)"; then
        fail "a broken copy passed (expected: $reason)"
    fi
    grep -qF "FAIL: $reason" <<<"$out" || fail "expected 'FAIL: $reason', got: $out"
}

cp -r "$REPO_PAPERCLIP" "$TEST_ROOT/p"
sed -i '/^declare -A ICON=(/,/^)/{/^ *\[teacher\]=/d}' "$TEST_ROOT/p/configure.sh"
expect_fail "teacher missing from ICON"

rm -rf "$TEST_ROOT/p" && cp -r "$REPO_PAPERCLIP" "$TEST_ROOT/p"
sed -i 's/^reportsTo: .*/reportsTo: "nobody"/' "$TEST_ROOT/p/src/agents/developer-1.md"
expect_fail "developer-1 reports to unknown nobody"

rm -rf "$TEST_ROOT/p" && cp -r "$REPO_PAPERCLIP" "$TEST_ROOT/p"
sed -i 's/^declare -A RENAMED=(/&[ghost-agent]="Ghost" /' "$TEST_ROOT/p/configure.sh"
expect_fail "RENAMED has ghost-agent but there is no src/agents/ghost-agent.md"

printf '%s\n' "team_test.sh: PASS"
