#!/usr/bin/env bash
set -euo pipefail

PAPERCLIP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
repo="$TEST_ROOT/repo"
git init -q -b main "$repo"
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$repo" remote add origin ssh://git@gitlab.example.com/group/project.git
git -C "$repo" worktree add -q -b KEY-1-task "$repo/.paperclip/worktrees/KEY-1-task"
worktree="$repo/.paperclip/worktrees/KEY-1-task"

BIN_DIR="$TEST_ROOT/bin" bash "$PAPERCLIP_DIR/setup-gitlab-repo.sh" "$repo" >/dev/null
BIN_DIR="$TEST_ROOT/bin" bash "$PAPERCLIP_DIR/setup-gitlab-repo.sh" "$repo" >/dev/null

remote_url() { git -C "$1" ls-remote --get-url origin; }
[[ "$(remote_url "$worktree")" == "keystone-gitlab://gitlab.example.com/group/project.git" ]] \
    || fail "worktree remote not routed through the helper: $(remote_url "$worktree")"
[[ "$(remote_url "$repo")" == "ssh://git@gitlab.example.com/group/project.git" ]] \
    || fail "main checkout remote changed: $(remote_url "$repo")"
[[ "$(git -C "$repo" config --local --get-all "includeIf.gitdir:$repo/.git/worktrees/.path" | wc -l)" == 1 ]] \
    || fail "include added more than once"
[[ -x "$TEST_ROOT/bin/git-remote-keystone-gitlab" ]] || fail "remote helper not installed"

# The helper must add its credential helper after the launcher's `credential.helper=` reset
# and hand the plain https URL to git's own HTTPS transport.
mkdir -p "$TEST_ROOT/stub"
cat > "$TEST_ROOT/stub/git" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$STUB_OUT.args"
env | grep '^GIT_CONFIG_' | sort > "$STUB_OUT.env"
EOF
chmod +x "$TEST_ROOT/stub/git"
STUB_OUT="$TEST_ROOT/out" PATH="$TEST_ROOT/stub:$PATH" \
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0= \
    "$TEST_ROOT/bin/git-remote-keystone-gitlab" origin keystone-gitlab://gitlab.example.com/group/project.git
[[ "$(cat "$TEST_ROOT/out.args")" == $'remote-https\norigin\nhttps://gitlab.example.com/group/project.git' ]] \
    || fail "wrong handover: $(cat "$TEST_ROOT/out.args")"
grep -qx "GIT_CONFIG_COUNT=2" "$TEST_ROOT/out.env" || fail "config count not extended"
grep -qx "GIT_CONFIG_KEY_1=credential.helper" "$TEST_ROOT/out.env" || fail "credential helper not appended"

helper="$(sed -n 's/^GIT_CONFIG_VALUE_1=!//p' "$TEST_ROOT/out.env")"
[[ "$(printf 'host=x\n\n' | GITLAB_TOKEN=secret-123 sh -c "$helper \"\$@\"" sh get)" == $'username=oauth2\npassword=secret-123' ]] \
    || fail "credential helper did not return GITLAB_TOKEN"
[[ -z "$(printf 'host=x\n\n' | GITLAB_TOKEN= sh -c "$helper \"\$@\"" sh get)" ]] \
    || fail "credential helper answered without GITLAB_TOKEN"
echo "PASS"
