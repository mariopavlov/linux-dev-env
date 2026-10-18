#!/usr/bin/env bash
# Imports the company package (once) and applies everything the package format cannot carry:
# instance flags, pinned skill sources, per-agent skills, working directories, environment,
# heartbeats and concurrency, and the agents' GitHub token. Safe to re-run.
#
#   bash paperclip/configure.sh
#   GITHUB_TOKEN=github_pat_… bash paperclip/configure.sh    also stores the company secret
set -euo pipefail

PAPERCLIP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API="${PAPERCLIP_API:-http://127.0.0.1:3100/api}"
COMPANY_NAME="Mario Solutions Architecture"
AGENT_HOMES="$HOME/.paperclip/agent-homes"

api() {
    local method="$1" path="$2" body="${3:-}"
    if [[ -n "$body" ]]; then
        curl -fsS -X "$method" "$API$path" -H 'content-type: application/json' -d "$body"
    else
        curl -fsS -X "$method" "$API$path"
    fi
}

log() { printf '▶ %s\n' "$*"; }

declare -A NAME=(
    [ceo-principal-architect]="Principal Architect"
    [delivery-lead]="Delivery Lead"
    [developer-1]="Developer 1"
    [developer-2]="Developer 2"
    [refactorer]="Refactorer"
    [platform-devops]="Platform Engineer"
    [cloud-architect]="Cloud Architect"
    [security-codex]="Security·Codex"
    [security-claude]="Security·Claude"
    [ddd-reviewer]="DDD Reviewer"
    [qa]="QA Engineer"
    [teacher]="Teacher"
)

SUPERPOWERS="brainstorming writing-plans executing-plans test-driven-development systematic-debugging verification-before-completion requesting-code-review receiving-code-review"
AZURE="azure-kubernetes azure-storage azure-messaging azure-reliability azure-compliance azure-cloud-migrate azure-well-architected azure-architecture azure-kubernetes-service"
AWS="aws-containers aws-compute aws-database aws-networking aws-security aws-storage aws-messaging-and-streaming aws-well-architected-review"
TERRAFORM="terraform-style-guide terraform-test refactor-module azure-verified-modules"

declare -A SKILLS=(
    [ceo-principal-architect]="brainstorming writing-plans"
    [delivery-lead]="writing-plans executing-plans requesting-code-review"
    [developer-1]="$SUPERPOWERS"
    [developer-2]="$SUPERPOWERS"
    [refactorer]="systematic-debugging verification-before-completion receiving-code-review"
    [platform-devops]="$SUPERPOWERS $TERRAFORM"
    [cloud-architect]="$AZURE $AWS $TERRAFORM requesting-code-review"
    [security-codex]="requesting-code-review"
    [security-claude]="requesting-code-review"
    [ddd-reviewer]="requesting-code-review"
    [qa]="verification-before-completion systematic-debugging requesting-code-review"
    [teacher]="teacher"
)

# repo|commit|path prefix|skill names
SOURCES=(
    "obra/superpowers|bb92a77741419a4ab5f06e711a283343f1ada0c3|skills|$SUPERPOWERS"
    "microsoft/azure-skills|cf79ce8778ad063eeac19dbe8bf982d71b466ce0|skills|azure-kubernetes azure-storage azure-messaging azure-reliability azure-compliance azure-cloud-migrate"
    "MicrosoftDocs/Agent-Skills|ba74e8fcc5cf4864798beaf95e53d7c4840bac5e|skills|azure-well-architected azure-architecture azure-kubernetes-service"
    "aws/agent-toolkit-for-aws|44ba1a5451913998815111cc2d518f5c45f95ef7|plugins/aws-core/skills|$AWS"
    "hashicorp/agent-skills|f706481af9b8fedb66de909f6243ad29601afa0c|plugins/terraform/skills|$TERRAFORM"
)

is_claude() { [[ "$(jq -r --arg n "${NAME[$1]}" '.[] | select(.name==$n) | .adapterType' <<<"$AGENTS")" == "claude_local" ]]; }

api GET /health >/dev/null || { echo "Paperclip is not reachable at $API" >&2; exit 1; }

log "Instance: isolated workspaces"
api PATCH /instance/settings/experimental \
    '{"enableIsolatedWorkspaces":true,"enableIsolatedWorkspacesByDefault":true}' >/dev/null

log "Company: $COMPANY_NAME"
company_id() { api GET /companies | jq -r --arg n "$COMPANY_NAME" '.[] | select(.name==$n and .status!="archived") | .id' | head -n1; }
COMPANY="$(company_id)"
if [[ -z "$COMPANY" ]]; then
    bash "$PAPERCLIP_DIR/build.sh" --check
    paperclipai company import "$PAPERCLIP_DIR/company" --target new --yes >/dev/null
    COMPANY="$(company_id)"
fi
[[ -n "$COMPANY" ]] || { echo "company import failed" >&2; exit 1; }
echo "  id: $COMPANY"

log "Skill sources"
existing_sources="$(api GET "/companies/$COMPANY/skill-sources" | jq -r '(if type=="array" then . else (.sources // .items // []) end)[] | .repositoryUrl')"
for entry in "${SOURCES[@]}"; do
    IFS='|' read -r repo sha prefix names <<<"$entry"
    url="https://github.com/$repo"
    if grep -qix "$url" <<<"$existing_sources"; then
        echo "  skip $repo"
        continue
    fi
    paths="$(printf '%s\n' $names | jq -R --arg p "$prefix" '"\($p)/\(.)/SKILL.md"' | jq -sc .)"
    api POST "/companies/$COMPANY/skill-sources" \
        "$(jq -nc --arg u "$url" --arg s "$sha" --argjson p "$paths" '{repositoryUrl:$u,commitSha:$s,selectedPaths:$p}')" >/dev/null
    echo "  added $repo@${sha:0:7}"
done
log "Local skills (teacher)"
SKILLS_ROOT="$(cd "$PAPERCLIP_DIR/../claude-skills/dot-claude/skills" && pwd)"
skills_project="$(api GET "/companies/$COMPANY/projects" | jq -r '.[] | select(.name=="Team Skills") | .id' | head -n1)"
if [[ -z "$skills_project" ]]; then
    skills_project="$(api POST "/companies/$COMPANY/projects" '{"name":"Team Skills","description":"Local skills imported into the company. Not a work project.","status":"planned"}' | jq -r .id)"
    api POST "/projects/$skills_project/workspaces" "$(jq -nc --arg c "$SKILLS_ROOT" '{name:"claude-skills",cwd:$c,isPrimary:true}')" >/dev/null
fi
api POST "/companies/$COMPANY/skills/import" "$(jq -nc --arg s "$SKILLS_ROOT/teacher" '{source:$s}')" >/dev/null
echo "  teacher <- $SKILLS_ROOT/teacher"

SKILL_KEYS="$(api GET "/companies/$COMPANY/skills" | jq -c '[(if type=="array" then . else (.skills // .items) end)[] | {slug, key}]')"

log "Agents"
AGENTS="$(api GET "/companies/$COMPANY/agents")"
for slug in "${!NAME[@]}"; do
    id="$(jq -r --arg n "${NAME[$slug]}" '.[] | select(.name==$n) | .id' <<<"$AGENTS")"
    [[ -n "$id" ]] || { echo "agent not found: ${NAME[$slug]}" >&2; exit 1; }

    home="$AGENT_HOMES/$slug"
    mkdir -p "$home"
    if is_claude "$slug"; then
        env='{"ENABLE_CLAUDEAI_MCP_SERVERS":"false"}'
        concurrency=1
    else
        env='{}'
        concurrency=2
    fi
    if [[ "$slug" == "delivery-lead" ]]; then
        heartbeat="{\"enabled\":true,\"intervalSec\":86400,\"maxConcurrentRuns\":$concurrency}"
    else
        heartbeat="{\"enabled\":false,\"maxConcurrentRuns\":$concurrency}"
    fi
    api PATCH "/agents/$id" "$(jq -nc --arg cwd "$home" --argjson env "$env" --argjson hb "$heartbeat" \
        '{adapterConfig:{cwd:$cwd, env:$env}, runtimeConfig:{heartbeat:$hb}}')" >/dev/null

    keys="$(printf '%s\n' ${SKILLS[$slug]} | jq -R . | jq -sc --argjson all "$SKILL_KEYS" \
        '[.[] | select(. != "") as $s | ($all[] | select(.slug==$s) | .key)] | unique')"
    api POST "/agents/$id/skills/sync" "$(jq -nc --argjson k "$keys" '{mode:"replace",desiredSkills:$k}')" >/dev/null

    status="$(jq -r --arg n "${NAME[$slug]}" '.[] | select(.name==$n) | .status' <<<"$AGENTS")"
    [[ "$status" == "paused" ]] && api POST "/agents/$id/resume" >/dev/null
    printf '  %-24s skills=%-3s concurrency=%s\n' "$slug" "$(jq length <<<"$keys")" "$concurrency"
done

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    log "Secret: GITHUB_TOKEN"
    if api GET "/companies/$COMPANY/secrets" | jq -e '(if type=="array" then . else (.secrets // .items // []) end)[] | select(.key=="GITHUB_TOKEN")' >/dev/null; then
        echo "  exists (rotate in the UI)"
    else
        api POST "/companies/$COMPANY/secrets" \
            "$(jq -nc --arg v "$GITHUB_TOKEN" '{name:"GITHUB_TOKEN",key:"GITHUB_TOKEN",value:$v}')" >/dev/null
        echo "  stored"
    fi
fi

log "Done — http://localhost:3100"
