#!/usr/bin/env bash
# Prepares a GitHub repo for the agent team. Safe to re-run.
#
#   bash paperclip/setup-repo.sh <owner/repo> <milestone-branch> [local-path]
#
# - rebase-only merges, merged branches auto-deleted
# - "Main: Only PRs": main takes PRs only, linear, no force push, no deletion, 0 approvals —
#   Mario reviews and merges the milestone PR himself
# - milestone branch created from main if missing
# - "Milestone: <branch>": PRs only, linear, and the `paperclip/approval` status the Principal
#   Architect sets when it approves a task — so nobody can merge a task PR before that
# - reports .gitignore entries the local checkout is missing
set -euo pipefail

REPO="${1:?usage: setup-repo.sh <owner/repo> <milestone-branch> [local-path]}"
MILESTONE="${2:?usage: setup-repo.sh <owner/repo> <milestone-branch> [local-path]}"
LOCAL="${3:-}"

pull_request_rule='{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"required_reviewers":[],"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false,"require_extra_approval_for_unattributed_changes":false,"allowed_merge_methods":["rebase"]}}'

ruleset() {
    local name="$1" ref="$2" rules="$3"
    jq -nc --arg n "$name" --arg r "$ref" --argjson rules "$rules" \
        '{name:$n,target:"branch",enforcement:"active",bypass_actors:[],conditions:{ref_name:{include:[$r],exclude:[]}},rules:$rules}'
}

apply_ruleset() {
    local name="$1" body="$2" id file
    id="$(gh api "repos/$REPO/rulesets" --paginate | jq -r --arg n "$name" '.[] | select(.name==$n) | .id' | head -n1)"
    file="$(mktemp)"
    printf '%s\n' "$body" > "$file"
    if [[ -n "$id" ]]; then
        gh api "repos/$REPO/rulesets/$id" -X PUT --input "$file" >/dev/null
    else
        gh api "repos/$REPO/rulesets" -X POST --input "$file" >/dev/null
    fi
    rm -f "$file"
    echo "ruleset: $name"
}

gh api "repos/$REPO" -X PATCH -F allow_merge_commit=false -F allow_squash_merge=false \
    -F allow_rebase_merge=true -F delete_branch_on_merge=true >/dev/null
echo "merge settings: rebase only, auto-delete merged branches"

apply_ruleset "Main: Only PRs" "$(ruleset "Main: Only PRs" "~DEFAULT_BRANCH" \
    "[{\"type\":\"deletion\"},{\"type\":\"non_fast_forward\"},{\"type\":\"required_linear_history\"},$pull_request_rule]")"

if gh api "repos/$REPO/git/ref/heads/$MILESTONE" >/dev/null 2>&1; then
    echo "branch: $MILESTONE exists"
else
    sha="$(gh api "repos/$REPO/git/ref/heads/main" | jq -r .object.sha)"
    gh api "repos/$REPO/git/refs" -X POST -f "ref=refs/heads/$MILESTONE" -f "sha=$sha" >/dev/null
    echo "branch: $MILESTONE created from main"
fi

apply_ruleset "Milestone: $MILESTONE" "$(ruleset "Milestone: $MILESTONE" "refs/heads/$MILESTONE" \
    "[{\"type\":\"non_fast_forward\"},{\"type\":\"required_linear_history\"},$pull_request_rule,{\"type\":\"required_status_checks\",\"parameters\":{\"strict_required_status_checks_policy\":false,\"required_status_checks\":[{\"context\":\"paperclip/approval\"}]}}]")"

if [[ -n "$LOCAL" ]]; then
    for entry in .paperclip/ .claude/; do
        grep -qxF "$entry" "$LOCAL/.gitignore" 2>/dev/null || echo "missing in $LOCAL/.gitignore: $entry"
    done
fi
