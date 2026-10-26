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

bash "$PAPERCLIP_DIR/build.sh" --src "$TEST_ROOT/src" --out "$TEST_ROOT/out"
rm "$TEST_ROOT/src/agents/beta.md"
if bash "$PAPERCLIP_DIR/build.sh" --src "$TEST_ROOT/src" --out "$TEST_ROOT/out" --check 2>/dev/null; then
    fail "--check passed with an orphaned agent dir"
fi
bash "$PAPERCLIP_DIR/build.sh" --src "$TEST_ROOT/src" --out "$TEST_ROOT/out"
[[ ! -e "$TEST_ROOT/out/agents/beta" ]] || fail "orphaned agent dir not removed"
[[ -f "$TEST_ROOT/out/agents/alpha/AGENTS.md" ]] || fail "removed the wrong agent"

# include directive
mkdir -p "$TEST_ROOT/src/roles"
printf '%s\n' "Gamma method." > "$TEST_ROOT/src/roles/gamma.md"
printf '%s\n' "---" 'name: "Alpha"' "---" "" "Alpha does alpha things." "<!-- include: roles/gamma.md -->" "Tail line." > "$TEST_ROOT/src/agents/alpha.md"
bash "$PAPERCLIP_DIR/build.sh" --src "$TEST_ROOT/src" --out "$TEST_ROOT/out"
inc_out="$TEST_ROOT/out/agents/alpha/AGENTS.md"
grep -qx "Gamma method." "$inc_out" || fail "include: shared file not inlined"
grep -qx "Tail line." "$inc_out" || fail "include: text after the directive lost"
! grep -q "<!-- include:" "$inc_out" || fail "include: directive line left in output"
bash "$PAPERCLIP_DIR/build.sh" --src "$TEST_ROOT/src" --out "$TEST_ROOT/out" --check \
    || fail "include: --check failed on fresh output"
echo "Gamma changed." > "$TEST_ROOT/src/roles/gamma.md"
if bash "$PAPERCLIP_DIR/build.sh" --src "$TEST_ROOT/src" --out "$TEST_ROOT/out" --check 2>/dev/null; then
    fail "include: --check passed after the included file changed"
fi

sed -i 's#roles/gamma.md#roles/missing.md#' "$TEST_ROOT/src/agents/alpha.md"
for mode in "" "--check"; do
    set +e
    # shellcheck disable=SC2086
    err="$(bash "$PAPERCLIP_DIR/build.sh" --src "$TEST_ROOT/src" --out "$TEST_ROOT/out" $mode 2>&1 >/dev/null)"
    status=$?
    set -e
    [[ $status -ne 0 ]] || fail "include: missing target did not fail (${mode:-build})"
    grep -qF "missing include: roles/missing.md (in alpha)" <<<"$err" || fail "include: missing-target message absent (${mode:-build}): $err"
done
printf '%s\n' "---" 'name: "Alpha"' "---" "" "Alpha does alpha things." > "$TEST_ROOT/src/agents/alpha.md"

bash "$PAPERCLIP_DIR/build.sh" --check || fail "committed company/ is stale — run paperclip/build.sh"

printf '%s\n' "build_test.sh: PASS"
