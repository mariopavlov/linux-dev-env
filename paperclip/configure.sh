#!/usr/bin/env bash
# Imports the company package (once) and applies everything the package format cannot carry:
# instance flags, pinned skill sources, per-agent skills, working directories, environment,
# heartbeats and concurrency, and agent instructions. Safe to re-run.
#
#   bash paperclip/configure.sh
set -euo pipefail

PAPERCLIP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API="${PAPERCLIP_API:-http://127.0.0.1:3100/api}"
COMPANY_NAME="Mario Solutions Architecture"
AGENT_HOMES="$HOME/.paperclip/agent-homes"
GIT_EMAIL="$(git config --global user.email)"

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
TERRAFORM="terraform-style-guide terraform-test refactor-module azure-verified-modules"

declare -A SKILLS=(
    [ceo-principal-architect]="brainstorming writing-plans executing-plans receiving-code-review domain-modeling pr retro"
    [developer-1]="$SUPERPOWERS pr"
    [developer-2]="$SUPERPOWERS pr"
    [refactorer]="systematic-debugging verification-before-completion receiving-code-review"
    [platform-devops]="$SUPERPOWERS $TERRAFORM"
    [cloud-architect]="azure-well-architected azure-architecture azure-kubernetes-service azure-reliability aws-well-architected-review aws-containers aws-security terraform-style-guide"
    [security-codex]="requesting-code-review"
    [security-claude]="requesting-code-review"
    [ddd-reviewer]="domain-modeling"
    [qa]="code-review verification-before-completion systematic-debugging"
    [teacher]="teacher"
)

# repo|commit|path prefix|skill names
SOURCES=(
    "obra/superpowers|bb92a77741419a4ab5f06e711a283343f1ada0c3|skills|$SUPERPOWERS"
    "microsoft/azure-skills|cf79ce8778ad063eeac19dbe8bf982d71b466ce0|skills|azure-reliability"
    "MicrosoftDocs/Agent-Skills|ba74e8fcc5cf4864798beaf95e53d7c4840bac5e|skills|azure-well-architected azure-architecture azure-kubernetes-service"
    "aws/agent-toolkit-for-aws|44ba1a5451913998815111cc2d518f5c45f95ef7|plugins/aws-core/skills|aws-well-architected-review aws-containers aws-security"
    "mattpocock/skills|49dd158d1076134a641b33efb035946536778336|skills/engineering|domain-modeling code-review pr retro"
    "hashicorp/agent-skills|f706481af9b8fedb66de909f6243ad29601afa0c|plugins/terraform/skills|$TERRAFORM"
)

is_claude() { [[ "$(jq -r --arg n "${NAME[$1]}" '.[] | select(.name==$n) | .adapterType' <<<"$AGENTS")" == "claude_local" ]]; }

api GET /health >/dev/null || { echo "Paperclip is not reachable at $API" >&2; exit 1; }

log "Instance: isolated workspaces, agent chat"
api PATCH /instance/settings/experimental \
    '{"enableIsolatedWorkspaces":true,"enableIsolatedWorkspacesByDefault":true,"enableAgentChat":true}' >/dev/null

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
existing_sources="$(api GET "/companies/$COMPANY/skill-sources" | jq -c '[(if type=="array" then . else (.sources // .items // []) end)[] | {url: (.repositoryUrl | ascii_downcase), id, commit: .lastScanCommit}]')"
for entry in "${SOURCES[@]}"; do
    IFS='|' read -r repo sha prefix names <<<"$entry"
    url="https://github.com/$repo"
    existing="$(jq -c --arg u "${url,,}" '.[] | select(.url==$u)' <<<"$existing_sources")"
    if [[ -n "$existing" ]]; then
        pinned="$(jq -r .commit <<<"$existing")"
        if [[ "$pinned" == "$sha" ]]; then
            echo "  skip $repo@${sha:0:7}"
        else
            echo "  WARN $repo is pinned at ${pinned:0:7}, configured ${sha:0:7} — Paperclip's API cannot re-pin a source; change it in the UI (Skills → sources)"
        fi
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
    author="${NAME[$slug]} (Paperclip)"
    env="$(jq -nc --arg n "$author" --arg e "$GIT_EMAIL" \
        '{GIT_AUTHOR_NAME:$n, GIT_AUTHOR_EMAIL:$e, GIT_COMMITTER_NAME:$n, GIT_COMMITTER_EMAIL:$e}')"
    if is_claude "$slug"; then
        env="$(jq -c '. + {ENABLE_CLAUDEAI_MCP_SERVERS:"false"}' <<<"$env")"
        concurrency=1
    else
        concurrency=2
    fi
    if [[ "$slug" == "ceo-principal-architect" ]]; then
        heartbeat="{\"enabled\":true,\"intervalSec\":86400,\"maxConcurrentRuns\":$concurrency}"
    else
        heartbeat="{\"enabled\":false,\"maxConcurrentRuns\":$concurrency}"
    fi
    api PATCH "/agents/$id" "$(jq -nc --arg cwd "$home" --argjson env "$env" --argjson hb "$heartbeat" \
        '{adapterConfig:{cwd:$cwd, env:$env}, runtimeConfig:{heartbeat:$hb}}')" >/dev/null

    for wanted_skill in ${SKILLS[$slug]}; do
        jq -e --arg s "$wanted_skill" 'any(.[]; .slug==$s)' <<<"$SKILL_KEYS" >/dev/null \
            || echo "  WARN $slug: skill '$wanted_skill' not found in the company"
    done
    keys="$(printf '%s\n' ${SKILLS[$slug]} | jq -R . | jq -sc --argjson all "$SKILL_KEYS" \
        '[.[] | select(. != "") as $s | ($all[] | select(.slug==$s) | .key)] | unique')"
    api POST "/agents/$id/skills/sync" "$(jq -nc --argjson k "$keys" '{mode:"replace",desiredSkills:$k}')" >/dev/null

    wanted="$(awk 'f>=2 {print; next} /^---$/ {f++}' "$PAPERCLIP_DIR/company/agents/$slug/AGENTS.md")"
    entry="$(api GET "/agents/$id/instructions-bundle/file?path=AGENTS.md")"
    if [[ "$wanted" != "$(jq -r '.content' <<<"$entry")" ]]; then
        api PUT "/agents/$id/instructions-bundle/file" "$(jq -nc --arg c "$wanted" \
            --argjson base "$(jq '.revision.id' <<<"$entry")" \
            '{path:"AGENTS.md",content:$c,baseRevisionId:$base}')" >/dev/null
        instructions="updated"
    else
        instructions="current"
    fi

    status="$(jq -r --arg n "${NAME[$slug]}" '.[] | select(.name==$n) | .status' <<<"$AGENTS")"
    [[ "$status" == "paused" ]] && api POST "/agents/$id/resume" >/dev/null
    printf "  %-24s skills=%-3s concurrency=%s instructions=%s\n" "$slug" "$(jq length <<<"$keys")" "$concurrency" "$instructions"
done

log "Done — http://localhost:3100"
