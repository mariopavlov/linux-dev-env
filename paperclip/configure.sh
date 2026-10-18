#!/usr/bin/env bash
# Imports the company package (once) and applies everything the package format cannot carry:
# instance flags, pinned skill sources, per-agent skills, working directories, environment,
# heartbeats and concurrency, and agent instructions. Safe to re-run.
#
#   bash paperclip/configure.sh
set -euo pipefail

PAPERCLIP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API="${PAPERCLIP_API:-http://127.0.0.1:3100/api}"
COMPANY_NAME="Keystone"
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
    [coordinator]="Coordinator"
    [research-scout]="Research Scout"
    [security-deepseek]="Security·DeepSeek"
)

declare -A MODEL=(
    [ceo-principal-architect]="claude-opus-5-5"
    [cloud-architect]="claude-sonnet-5-5"
    [ddd-reviewer]="claude-sonnet-5-5"
    [security-claude]="claude-sonnet-5-5"
    [qa]="claude-sonnet-5-5"
    [teacher]="claude-sonnet-5-5"
    [developer-1]="gpt-6-astra"
    [developer-2]="gpt-6-astra"
    [refactorer]="gpt-6-astra"
    [platform-devops]="gpt-6-astra"
    [security-codex]="gpt-6-astra"
    [coordinator]="ollama/nemotron-3-super:cloud"
    [research-scout]="ollama/deepseek-v4.1-flash:cloud"
    [security-deepseek]="ollama/deepseek-v4-pro:0813-cloud"
)

declare -A EFFORT=(
    [ceo-principal-architect]="high"
    [cloud-architect]="high"
    [ddd-reviewer]="high"
    [security-claude]="high"
    [qa]="medium"
    [teacher]="high"
    [developer-1]="medium"
    [developer-2]="medium"
    [platform-devops]="medium"
    [refactorer]="low"
    [security-codex]="high"
    [coordinator]="low"
    [research-scout]="medium"
    [security-deepseek]="high"
)

declare -A ICON=(
    [ceo-principal-architect]="crown"
    [cloud-architect]="globe"
    [ddd-reviewer]="hexagon"
    [security-claude]="lock"
    [qa]="bug"
    [teacher]="lightbulb"
    [developer-1]="code"
    [developer-2]="terminal"
    [refactorer]="wand"
    [platform-devops]="package"
    [security-codex]="shield"
    [coordinator]="radar"
    [research-scout]="telescope"
    [security-deepseek]="fingerprint"
)

declare -A PALETTE=(
    [ceo-principal-architect]="violet-ember"
    [cloud-architect]="ultraviolet-tide"
    [ddd-reviewer]="orchid-peach"
    [security-claude]="deep-tide"
    [qa]="arctic-blue"
    [teacher]="bubblegum-sky"
    [developer-1]="tangerine-cobalt"
    [developer-2]="solar-flare"
    [refactorer]="coral-current"
    [platform-devops]="golden-hour"
    [security-codex]="cherry-pop"
    [coordinator]="lime-lagoon"
    [research-scout]="electric-grove"
    [security-deepseek]="coral-mint"
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
    [coordinator]=""
    [research-scout]=""
    [security-deepseek]="requesting-code-review"
)

# repo|commit|path prefix|skill names
SOURCES=(
    "obra/superpowers|bb92a77741419a4ab5f06e711a283343f1ada0c3|skills|$SUPERPOWERS"
    "microsoft/azure-skills|cf79ce8778ad063eeac19dbe8bf982d71b466ce0|skills|azure-reliability"
    "MicrosoftDocs/Agent-Skills|ba74e8fcc5cf4864798beaf95e53d7c4840bac5e|skills|azure-well-architected azure-architecture azure-kubernetes-service"
    "aws/agent-toolkit-for-aws|44ba1a5451913998815111cc2d518f5c45f95ef7|plugins/aws-core/skills|aws-well-architected-review aws-containers aws-security"
    "mattpocock/skills|49dd158d1076134a641b33efb035946536778336|skills/engineering|domain-modeling code-review pr retro"
    "mariopavlov/linux-dev-env|cb65b5732621206aafd796434a56d58380f06b1a|claude-skills/dot-claude/skills|teacher"
    "hashicorp/agent-skills|f706481af9b8fedb66de909f6243ad29601afa0c|plugins/terraform/skills|$TERRAFORM"
)

adapter_of() { jq -r --arg n "${NAME[$1]}" '.[] | select(.name==$n) | .adapterType' <<<"$AGENTS"; }

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

log "Logo"
if [[ "$(api GET "/companies/$COMPANY" | jq -r '.logoAssetId // ""')" == "" ]]; then
    asset="$(curl -fsS -X POST "$API/companies/$COMPANY/logo" -F "file=@$PAPERCLIP_DIR/branding/keystone-logo.png;type=image/png" | jq -r '.assetId // .id')"
    api PATCH "/companies/$COMPANY" "$(jq -nc --arg a "$asset" '{logoAssetId:$a}')" >/dev/null
    echo "  uploaded branding/keystone-logo.png"
else
    echo "  skip (logo set)"
fi

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
SKILL_KEYS="$(api GET "/companies/$COMPANY/skills" | jq -c '[(if type=="array" then . else (.skills // .items) end)[] | {slug, key}]')"

log "Agents"
AGENTS="$(api GET "/companies/$COMPANY/agents")"
missing=()
for slug in "${!NAME[@]}"; do
    jq -e --arg n "${NAME[$slug]}" 'any(.[]; .name==$n)' <<<"$AGENTS" >/dev/null || missing+=("$slug")
done
if (( ${#missing[@]} > 0 )); then
    bash "$PAPERCLIP_DIR/build.sh" --check
    agents_csv="$(IFS=,; echo "${missing[*]}")"
    paperclipai company import "$PAPERCLIP_DIR/company" --target existing -C "$COMPANY" \
        --agents "$agents_csv" --collision skip --yes >/dev/null
    echo "  imported: $agents_csv"
    AGENTS="$(api GET "/companies/$COMPANY/agents")"
fi
for slug in "${!NAME[@]}"; do
    id="$(jq -r --arg n "${NAME[$slug]}" '.[] | select(.name==$n) | .id' <<<"$AGENTS")"
    [[ -n "$id" ]] || { echo "agent not found: ${NAME[$slug]}" >&2; exit 1; }

    manager_slug="$(sed -n 's/^reportsTo: "\(.*\)"$/\1/p' "$PAPERCLIP_DIR/company/agents/$slug/AGENTS.md")"
    if [[ -n "$manager_slug" ]]; then
        manager_id="$(jq -r --arg n "${NAME[$manager_slug]}" '.[] | select(.name==$n) | .id' <<<"$AGENTS")"
        current_manager="$(jq -r --arg n "${NAME[$slug]}" '.[] | select(.name==$n) | .reportsTo // ""' <<<"$AGENTS")"
        [[ "$current_manager" == "$manager_id" ]] \
            || api PATCH "/agents/$id" "$(jq -nc --arg m "$manager_id" '{reportsTo:$m}')" >/dev/null
    fi

    home="$AGENT_HOMES/$slug"
    mkdir -p "$home"
    author="${NAME[$slug]} (Paperclip)"
    env="$(jq -nc --arg n "$author" --arg e "$GIT_EMAIL" \
        '{GIT_AUTHOR_NAME:$n, GIT_AUTHOR_EMAIL:$e, GIT_COMMITTER_NAME:$n, GIT_COMMITTER_EMAIL:$e}')"
    case "$(adapter_of "$slug")" in
        claude_local)
            env="$(jq -c '. + {ENABLE_CLAUDEAI_MCP_SERVERS:"false"}' <<<"$env")"
            effort="$(jq -nc --arg e "${EFFORT[$slug]}" '{effort:$e}')"
            concurrency=1 ;;
        codex_local)
            effort="$(jq -nc --arg e "${EFFORT[$slug]}" '{modelReasoningEffort:$e}')"
            concurrency=2 ;;
        opencode_local)
            effort="$(jq -nc --arg e "${EFFORT[$slug]}" '{variant:$e}')"
            concurrency=2 ;;
    esac
    if [[ "$slug" == "coordinator" ]]; then
        heartbeat="{\"enabled\":true,\"intervalSec\":86400,\"maxConcurrentRuns\":$concurrency}"
    else
        heartbeat="{\"enabled\":false,\"maxConcurrentRuns\":$concurrency}"
    fi
    api PATCH "/agents/$id" "$(jq -nc --arg cwd "$home" --arg model "${MODEL[$slug]}" --argjson env "$env" --argjson hb "$heartbeat" \
        --argjson effort "$effort" \
        --arg icon "${ICON[$slug]}" --arg palette "${PALETTE[$slug]}" \
        '{adapterConfig:({cwd:$cwd, model:$model, env:$env} + $effort), runtimeConfig:{heartbeat:$hb},
          icon:$icon, appearance:{schemaVersion:1, characterVersion:"cap-v1", paletteId:$palette}}')" >/dev/null

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
    printf "  %-24s %-18s %-6s skills=%-3s concurrency=%s instructions=%s\n" "$slug" "${MODEL[$slug]}" "${EFFORT[$slug]}" "$(jq length <<<"$keys")" "$concurrency" "$instructions"
done

log "Done — http://localhost:3100"
