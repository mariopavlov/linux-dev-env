#!/usr/bin/env bash
set -euo pipefail

PAPERCLIP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$TEST_ROOT/src/agents"
printf '%s\n' "- Rule one." "- Rule two." > "$TEST_ROOT/src/team-rules.md"
printf '%s\n' "---" 'name: "Alpha"' "---" "" "Alpha does alpha things." > "$TEST_ROOT/src/agents/alpha.md"
printf '%s\n' "---" 'name: "Beta"' 'reportsTo: "alpha"' "---" "" "Beta does beta things." > "$TEST_ROOT/src/agents/beta.md"

bash "$PAPERCLIP_DIR/build.sh" --src "$TEST_ROOT/src" --out "$TEST_ROOT/out"

for slug in alpha beta; do
    out="$TEST_ROOT/out/agents/$slug/AGENTS.md"
    [[ -f "$out" ]] || fail "missing $out"
    head -n1 "$out" | grep -qx -- "---" || fail "$slug: frontmatter not first"
    grep -qx "## Team rules" "$out" || fail "$slug: no team rules heading"
    grep -qx -- "- Rule two." "$out" || fail "$slug: team rules not appended"
done
grep -qx 'reportsTo: "alpha"' "$TEST_ROOT/out/agents/beta/AGENTS.md" || fail "frontmatter changed"
grep -qx "Beta does beta things." "$TEST_ROOT/out/agents/beta/AGENTS.md" || fail "body lost"

bash "$PAPERCLIP_DIR/build.sh" --src "$TEST_ROOT/src" --out "$TEST_ROOT/out" --check \
    || fail "--check failed on fresh output"
echo "- Rule three." >> "$TEST_ROOT/src/team-rules.md"
if bash "$PAPERCLIP_DIR/build.sh" --src "$TEST_ROOT/src" --out "$TEST_ROOT/out" --check 2>/dev/null; then
    fail "--check passed on stale output"
fi

bash "$PAPERCLIP_DIR/build.sh" --check || fail "committed company/ is stale — run paperclip/build.sh"

printf '%s\n' "build_test.sh: PASS"
