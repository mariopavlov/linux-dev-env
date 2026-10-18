#!/usr/bin/env bash
set -euo pipefail

PAPERCLIP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

export GH_LOG="$TEST_ROOT/gh.log"
export PATH="$TEST_ROOT/bin:$PATH"
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/repo"

cat > "$TEST_ROOT/bin/gh" <<'MOCK'
#!/usr/bin/env bash
args="$*"
input=""
for ((i = 1; i <= $#; i++)); do
    if [[ "${!i}" == "--input" ]]; then j=$((i + 1)); input="$(cat "${!j}")"; fi
done
printf '%s\n%s\n' "$args" "$input" >> "$GH_LOG"
case "$args" in
    *"rulesets --paginate"*) printf '%s\n' "${EXISTING_RULESETS:-[]}" ;;
    *"git/ref/heads/main"*) printf '%s\n' '{"object":{"sha":"abc123"}}' ;;
    *"git/ref/heads/m0"*) [[ "${MILESTONE_EXISTS:-0}" == 1 ]] && echo '{"object":{"sha":"abc123"}}' || exit 1 ;;
esac
MOCK
chmod +x "$TEST_ROOT/bin/gh"

fail() { echo "FAIL: $*" >&2; exit 1; }
logged() { grep -qF -- "$1" "$GH_LOG" || fail "expected gh call containing: $1"; }

printf '.paperclip/\n' > "$TEST_ROOT/repo/.gitignore"
OUT="$(bash "$PAPERCLIP_DIR/setup-repo.sh" owner/repo m0 "$TEST_ROOT/repo" 2>&1)"

logged "repos/owner/repo -X PATCH -F allow_merge_commit=false -F allow_squash_merge=false -F allow_rebase_merge=true -F delete_branch_on_merge=true"
logged "repos/owner/repo/git/refs -X POST -f ref=refs/heads/m0 -f sha=abc123"
logged '"name":"Main: Only PRs"'
logged '"include":["~DEFAULT_BRANCH"]'
logged '"type":"deletion"'
logged '"name":"Milestone: m0"'
logged '"include":["refs/heads/m0"]'
logged '"context":"paperclip/approval"'
logged '"allowed_merge_methods":["rebase"]'
grep -qF ".claude/" <<<"$OUT" || fail "missing .gitignore entry .claude/ not reported"
grep -qF -- '"name":"Milestone: m0"' "$GH_LOG" && grep -A1 -F 'Milestone: m0' "$GH_LOG" | grep -qF '"type":"deletion"' \
    && fail "milestone branch must stay deletable (auto-delete after merge into main)"

: > "$GH_LOG"
EXISTING_RULESETS='[{"id":7,"name":"Main: Only PRs"},{"id":8,"name":"Milestone: m0"}]' MILESTONE_EXISTS=1 \
    bash "$PAPERCLIP_DIR/setup-repo.sh" owner/repo m0 >/dev/null 2>&1
logged "repos/owner/repo/rulesets/7 -X PUT"
logged "repos/owner/repo/rulesets/8 -X PUT"
grep -qF "git/refs -X POST" "$GH_LOG" && fail "created a milestone branch that already exists"

printf '%s\n' "setup_repo_test.sh: PASS"
