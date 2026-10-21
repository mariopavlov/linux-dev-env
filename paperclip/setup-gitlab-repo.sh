#!/usr/bin/env bash
# Lets Keystone agents push a GitLab repo with the project token configure.sh hands them as
# GITLAB_TOKEN. Safe to re-run.
#
#   bash paperclip/setup-gitlab-repo.sh <local-path>
#
# Agent runs ignore the global git config, their SSH carries no keys, and Paperclip's git
# launcher clears credential helpers and askpass. So inside Paperclip's worktrees (an includeIf
# on .git/worktrees/) the remote is routed through bin/git-remote-keystone-gitlab, which adds
# the token back. Mario's own checkout keeps pushing over SSH.
set -euo pipefail

REPO="${1:?usage: setup-gitlab-repo.sh <local-path>}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
PAPERCLIP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$BIN_DIR"
ln -sfn "$PAPERCLIP_DIR/bin/git-remote-keystone-gitlab" "$BIN_DIR/git-remote-keystone-gitlab"

common="$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)"
remote="$(git -C "$REPO" remote get-url origin)"
host="$(sed -E 's#^(ssh://)?([^@/]+@)?([^:/]+).*#\3#' <<<"$remote")"
inc="$common/keystone-gitlab.inc"

rm -f "$inc"
git config --file "$inc" --add "url.keystone-gitlab://$host/.insteadOf" "ssh://git@$host/"
git config --file "$inc" --add "url.keystone-gitlab://$host/.insteadOf" "git@$host:"

git -C "$REPO" config --local --replace-all "includeIf.gitdir:$common/worktrees/.path" "$inc"
echo "$REPO: agent worktrees push to https://$host with \$GITLAB_TOKEN"
