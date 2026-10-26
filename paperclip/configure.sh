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
CLAUDE_BIN="$(command -v claude)" || { echo "claude CLI not found on PATH" >&2; exit 1; }
CODEX_BIN="$(command -v codex)" || { echo "codex CLI not found on PATH" >&2; exit 1; }

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
    [mentor]="Mentor"
    [ceo-principal-architect]="Principal Architect"
    [developer-1]="Developer 1"
    [developer-2]="Developer 2"
    [refactorer]="Refactorer"
    [platform-devops]="Platform Engineer"
    [cloud-architect]="Cloud Architect"
    [security-codex]="Security·Codex"
    [security-claude]="Security·Claude"
    [ddd-reviewer]="DDD Reviewer"
    [delivery-qa]="Delivery QA"
    [teacher]="Teacher"
    [cloud-architect-advisor]="Cloud Architect Advisor"
    [research-scout]="Research Scout"
    [security-deepseek]="Security·DeepSeek"
    [red-team-engineer]="Red Team Engineer"
    [security-lead]="Security Lead"
    [technical-writer]="Technical Writer"
    [delivery-lead]="Delivery Lead"
    [security-qa]="Security QA"
    [audit-writer]="Audit Writer"
    [review-lead]="Review Lead"
    [bug-hunter-claude]="Bug Hunter·Claude"
    [bug-hunter-open]="Bug Hunter·Open"
    [spec-contract-critic]="Spec & Contract Critic"
    [maintainability-critic]="Maintainability Critic"
    [first-principles-critic]="First-Principles Critic"
    [history-critic]="History Critic"
    [disprover-claude]="Disprover·Claude"
    [disprover-open]="Disprover·Open"
    [critic-sol]="Critic·Sol"
    [chronicle-lead]="Chronicle Lead"
)

declare -A MODEL=(
    [mentor]="claude-opus-5-5"
    [ceo-principal-architect]="claude-opus-5-5"
    [cloud-architect]="claude-sonnet-5-5"
    [ddd-reviewer]="claude-sonnet-5-5"
    [security-claude]="claude-sonnet-5-5"
    [delivery-qa]="claude-sonnet-5-5"
    [teacher]="claude-sonnet-5-5"
    [cloud-architect-advisor]="claude-sonnet-5-5"
    [developer-1]="gpt-6-astra"
    [developer-2]="gpt-6-astra"
    [refactorer]="gpt-6-astra"
    [platform-devops]="gpt-6-astra"
    [security-codex]="gpt-6-astra"
    [research-scout]="ollama/deepseek-v4.1-flash:cloud"
    [security-deepseek]="ollama/deepseek-v4-pro:0813-cloud"
    [red-team-engineer]="ollama/glm-5.3:cloud"
    [security-lead]="gpt-6.1-sol"
    [technical-writer]="claude-opus-5-5"
    [delivery-lead]="claude-sonnet-5-5"
    [security-qa]="claude-sonnet-5-5"
    [audit-writer]="claude-opus-5-5"
    [review-lead]="claude-opus-5-5"
    [bug-hunter-claude]="claude-sonnet-5-5"
    [bug-hunter-open]="ollama/deepseek-v4-pro:0813-cloud"
    [spec-contract-critic]="claude-sonnet-5-5"
    [maintainability-critic]="ollama/glm-5.3:cloud"
    [first-principles-critic]="claude-opus-5-5"
    [history-critic]="ollama/deepseek-v4.1-flash:cloud"
    [disprover-claude]="claude-sonnet-5-5"
    [disprover-open]="ollama/deepseek-v4-pro:0813-cloud"
    [critic-sol]="gpt-6.1-sol"
    [chronicle-lead]="claude-opus-5-5"
)

declare -A EFFORT=(
    [mentor]="high"
    [ceo-principal-architect]="high"
    [cloud-architect]="high"
    [ddd-reviewer]="high"
    [security-claude]="high"
    [delivery-qa]="high"
    [teacher]="high"
    [cloud-architect-advisor]="high"
    [developer-1]="medium"
    [developer-2]="medium"
    [platform-devops]="medium"
    [refactorer]="low"
    [security-codex]="high"
    [research-scout]="medium"
    [security-deepseek]="high"
    [red-team-engineer]="high"
    [security-lead]="high"
    [technical-writer]="high"
    [delivery-lead]="high"
    [security-qa]="high"
    [audit-writer]="high"
    [review-lead]="high"
    [bug-hunter-claude]="high"
    [bug-hunter-open]="high"
    [spec-contract-critic]="high"
    [maintainability-critic]="high"
    [first-principles-critic]="high"
    [history-critic]="medium"
    [disprover-claude]="high"
    [disprover-open]="high"
    [critic-sol]="high"
    [chronicle-lead]="high"
)

declare -A ICON=(
    [mentor]="target"
    [ceo-principal-architect]="crown"
    [cloud-architect]="globe"
    [ddd-reviewer]="hexagon"
    [security-claude]="lock"
    [delivery-qa]="bug"
    [teacher]="lightbulb"
    [cloud-architect-advisor]="message-square"
    [developer-1]="code"
    [developer-2]="terminal"
    [refactorer]="wand"
    [platform-devops]="package"
    [security-codex]="shield"
    [research-scout]="telescope"
    [security-deepseek]="fingerprint"
    [red-team-engineer]="swords"
    [security-lead]="radar"
    [technical-writer]="file-code"
    [delivery-lead]="git-branch"
    [security-qa]="eye"
    [audit-writer]="file-code"
    [review-lead]="microscope"
    [bug-hunter-claude]="bug"
    [bug-hunter-open]="bug"
    [spec-contract-critic]="file-code"
    [maintainability-critic]="wand"
    [first-principles-critic]="lightbulb"
    [history-critic]="git-branch"
    [disprover-claude]="shield"
    [disprover-open]="shield"
    [critic-sol]="eye"
    [chronicle-lead]="file-code"
)

declare -A PALETTE=(
    [mentor]="flamingo-jade"
    [ceo-principal-architect]="violet-ember"
    [cloud-architect]="ultraviolet-tide"
    [ddd-reviewer]="orchid-peach"
    [security-claude]="deep-tide"
    [delivery-qa]="arctic-blue"
    [teacher]="bubblegum-sky"
    [cloud-architect-advisor]="ultraviolet-tide"
    [developer-1]="tangerine-cobalt"
    [developer-2]="solar-flare"
    [refactorer]="coral-current"
    [platform-devops]="golden-hour"
    [security-codex]="cherry-pop"
    [research-scout]="electric-grove"
    [security-deepseek]="coral-mint"
    [red-team-engineer]="cherry-pop"
    [security-lead]="golden-hour"
    [technical-writer]="turquoise-cherry"
    [delivery-lead]="pink-lemonade"
    [security-qa]="deep-tide"
    [audit-writer]="pink-lemonade"
    [review-lead]="arctic-blue"
    [bug-hunter-claude]="cherry-pop"
    [bug-hunter-open]="coral-mint"
    [spec-contract-critic]="deep-tide"
    [maintainability-critic]="coral-current"
    [first-principles-critic]="violet-ember"
    [history-critic]="golden-hour"
    [disprover-claude]="ultraviolet-tide"
    [disprover-open]="electric-grove"
    [critic-sol]="solar-flare"
    [chronicle-lead]="orchid-peach"
)

SUPERPOWERS="brainstorming writing-plans executing-plans test-driven-development systematic-debugging verification-before-completion requesting-code-review receiving-code-review"
TERRAFORM="terraform-style-guide terraform-test refactor-module azure-verified-modules"

declare -A SKILLS=(
    [mentor]=""
    [ceo-principal-architect]="brainstorming writing-plans executing-plans receiving-code-review domain-modeling pr retro"
    [developer-1]="$SUPERPOWERS pr"
    [developer-2]="$SUPERPOWERS pr"
    [refactorer]="systematic-debugging verification-before-completion receiving-code-review"
    [platform-devops]="$SUPERPOWERS $TERRAFORM"
    [cloud-architect]="azure-well-architected azure-architecture azure-kubernetes-service azure-reliability aws-well-architected-review aws-containers aws-security terraform-style-guide"
    [security-codex]="requesting-code-review"
    [security-claude]="requesting-code-review"
    [ddd-reviewer]="domain-modeling"
    [delivery-qa]="verification-before-completion systematic-debugging"
    [teacher]="teacher"
    [cloud-architect-advisor]="aws-well-architected-review aws-containers aws-security azure-well-architected azure-architecture azure-kubernetes-service terraform-style-guide"
    [research-scout]=""
    [security-deepseek]="requesting-code-review"
    [red-team-engineer]="requesting-code-review"
    [security-lead]="requesting-code-review"
    [technical-writer]="verification-before-completion"
    [delivery-lead]="receiving-code-review pr"
    [security-qa]="verification-before-completion systematic-debugging terraform-test"
    [audit-writer]="verification-before-completion"
    [review-lead]="receiving-code-review"
    [bug-hunter-claude]="systematic-debugging"
    [bug-hunter-open]="systematic-debugging"
    [spec-contract-critic]=""
    [maintainability-critic]=""
    [first-principles-critic]="systematic-debugging"
    [history-critic]=""
    [disprover-claude]=""
    [disprover-open]=""
    [critic-sol]=""
    [chronicle-lead]="verification-before-completion"
)

NOTION_READ="notion-search notion-fetch notion-query-data-sources notion-query-multiple-data-sources notion-get-comments notion-list-page-backlinks notion-get-users notion-get-self notion-get-file-download-urls notion-download-attachment notion-get-async-task"
NOTION_WRITE="$NOTION_READ notion-create-pages notion-update-page"

# profile key|name|tools|agents — agents not listed get no Notion tools
NOTION_PROFILES=(
    "keystone-notion-design|Notion · Design|$NOTION_WRITE notion-create-comment notion-set-discussion-resolved|ceo-principal-architect"
    "keystone-notion-records|Notion · Records|$NOTION_WRITE|mentor teacher chronicle-lead"
    "keystone-notion-read|Notion · Read|$NOTION_READ|research-scout"
)

# Run wall-clock limits: a hung run fails and gets Paperclip's retry instead of running forever.
RUN_TIMEOUT_SEC=2700
declare -A LONG_RUN_TIMEOUT_SEC=([ceo-principal-architect]=5400 [mentor]=5400 [chronicle-lead]=5400)

# Agents renamed since they were imported: slug → previous live name. configure.sh finds agents by
# name, so it renames the live agent before checking for missing ones instead of importing a copy.
declare -A RENAMED=([delivery-qa]="QA Engineer" [audit-writer]="Security Writer")

# Single-pass reviewers start each run fresh instead of reloading their whole session history.
ONE_SHOT="refactorer security-codex bug-hunter-claude bug-hunter-open spec-contract-critic maintainability-critic first-principles-critic history-critic disprover-claude disprover-open critic-sol"

# Agents that push to GitLab get the project token Mario stores in Keystone's secrets under this key;
# setup-gitlab-repo.sh makes their worktrees use it.
GITLAB_TOKEN_SECRET="gitlab-wkl-token"
GITLAB_PUSHERS="ceo-principal-architect developer-1 developer-2 platform-devops technical-writer delivery-lead security-qa audit-writer delivery-qa refactorer chronicle-lead"

# repo|commit|path prefix|skill names
SOURCES=(
    "obra/superpowers|bb92a77741419a4ab5f06e711a283343f1ada0c3|skills|$SUPERPOWERS"
    "microsoft/azure-skills|cf79ce8778ad063eeac19dbe8bf982d71b466ce0|skills|azure-reliability"
    "MicrosoftDocs/Agent-Skills|ba74e8fcc5cf4864798beaf95e53d7c4840bac5e|skills|azure-well-architected azure-architecture azure-kubernetes-service"
    "aws/agent-toolkit-for-aws|44ba1a5451913998815111cc2d518f5c45f95ef7|plugins/aws-core/skills|aws-well-architected-review aws-containers aws-security"
    "mattpocock/skills|49dd158d1076134a641b33efb035946536778336|skills/engineering|domain-modeling code-review pr retro"
    "mariopavlov/linux-dev-env|146d95ddbac3d4ee74e44c6b90a705232da91e14|claude-skills/dot-claude/skills|teacher"
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
        elif [[ "$(gh api "repos/$repo/compare/$sha...$pinned" --jq .status 2>/dev/null)" == "ahead" ]]; then
            echo "  skip $repo@${pinned:0:7} (tracks its branch; includes ${sha:0:7})"
        else
            echo "  WARN $repo is pinned at ${pinned:0:7}, configured ${sha:0:7} — Paperclip's API cannot re-pin a source; change it in the UI (Skills → sources)"
        fi
        continue
    fi
    paths="$(printf '%s\n' $names | jq -R --arg p "$prefix" '"\($p)/\(.)/SKILL.md"' | jq -sc .)"
    # Paperclip allows 6 repository downloads per caller per sliding minute and answers 429
    # (no Retry-After header) past that, so the 7th source has to wait out the window.
    curl -fsS --retry 6 --retry-delay 15 -X POST "$API/companies/$COMPANY/skill-sources" -H 'content-type: application/json' \
        -d "$(jq -nc --arg u "$url" --arg s "$sha" --argjson p "$paths" '{repositoryUrl:$u,commitSha:$s,selectedPaths:$p}')" >/dev/null
    echo "  added $repo@${sha:0:7}"
done
SKILL_KEYS="$(api GET "/companies/$COMPANY/skills" | jq -c '[(if type=="array" then . else (.skills // .items) end)[] | {slug, key}]')"

log "Agents"
AGENTS="$(api GET "/companies/$COMPANY/agents")"
for slug in "${!RENAMED[@]}"; do
    jq -e --arg n "${NAME[$slug]}" 'any(.[]; .name==$n)' <<<"$AGENTS" >/dev/null && continue
    id="$(jq -r --arg n "${RENAMED[$slug]}" '.[] | select(.name==$n) | .id' <<<"$AGENTS")"
    [[ -n "$id" ]] || continue
    title="$(sed -n 's/^title: "\(.*\)"$/\1/p' "$PAPERCLIP_DIR/company/agents/$slug/AGENTS.md")"
    api PATCH "/agents/$id" "$(jq -nc --arg n "${NAME[$slug]}" --arg t "$title" '{name:$n, title:$t}')" >/dev/null
    echo "  renamed: ${RENAMED[$slug]} → ${NAME[$slug]}"
    AGENTS="$(api GET "/companies/$COMPANY/agents")"
done
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
GITLAB_SECRET_ID="$(api GET "/companies/$COMPANY/secrets" | jq -r --arg k "$GITLAB_TOKEN_SECRET" '.[] | select(.key==$k and .status=="active") | .id' | head -n1)"
[[ -n "$GITLAB_SECRET_ID" ]] || echo "  WARN no '$GITLAB_TOKEN_SECRET' secret in Keystone — GitLab pushers get no token"
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
    author="${NAME[$slug]}"
    env="$(jq -nc --arg n "$author" --arg e "$GIT_EMAIL" \
        '{GIT_AUTHOR_NAME:$n, GIT_AUTHOR_EMAIL:$e, GIT_COMMITTER_NAME:$n, GIT_COMMITTER_EMAIL:$e}')"
    case "$(adapter_of "$slug")" in
        claude_local)
            env="$(jq -c --arg c "$CLAUDE_BIN" '. + {ENABLE_CLAUDEAI_MCP_SERVERS:"false", CLAUDE_CODE_EXECUTABLE:$c}' <<<"$env")"
            effort="$(jq -nc --arg e "${EFFORT[$slug]}" '{effort:$e}')"
            concurrency=1 ;;
        codex_local)
            # codex-acp bundles an older Codex whose model list lacks newer models (gpt-6.1-sol).
            env="$(jq -c --arg c "$CODEX_BIN" '. + {INITIAL_AGENT_MODE:"agent-full-access", CODEX_PATH:$c}' <<<"$env")"
            effort="$(jq -nc --arg e "${EFFORT[$slug]}" '{modelReasoningEffort:$e}')"
            concurrency=2 ;;
        opencode_local)
            # The global OpenCode config enables the GitKraken MCP, which writes to Jira as Mario.
            env="$(jq -c '. + {OPENCODE_CONFIG_CONTENT:"{\"mcp\":{\"GitKraken\":{\"type\":\"local\",\"command\":[\"true\"],\"enabled\":false}}}"}' <<<"$env")"
            effort="$(jq -nc --arg e "${EFFORT[$slug]}" '{variant:$e}')"
            concurrency=2 ;;
    esac
    if [[ -n "$GITLAB_SECRET_ID" && " $GITLAB_PUSHERS " == *" $slug "* ]]; then
        env="$(jq -c --arg s "$GITLAB_SECRET_ID" \
            '. + {GITLAB_TOKEN:{type:"secret_ref", secretId:$s, version:"latest"}, GITLAB_HOST:"gitlab.ontotext.com"}' <<<"$env")"
    fi
    heartbeat="{\"enabled\":false,\"maxConcurrentRuns\":$concurrency}"
    api PATCH "/agents/$id" "$(jq -nc --arg cwd "$home" --arg model "${MODEL[$slug]}" --argjson env "$env" --argjson hb "$heartbeat" \
        --argjson effort "$effort" \
        --arg icon "${ICON[$slug]}" --arg palette "${PALETTE[$slug]}" \
        --argjson timeout "${LONG_RUN_TIMEOUT_SEC[$slug]:-$RUN_TIMEOUT_SEC}" \
        --arg mode "$([[ " $ONE_SHOT " == *" $slug "* ]] && echo oneshot || echo persistent)" \
        '{adapterConfig:({cwd:$cwd, model:$model, env:$env, timeoutSec:$timeout, mode:$mode} + $effort), runtimeConfig:{heartbeat:$hb},
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

log "Notion access"
notion="$(api GET "/companies/$COMPANY/tools/connections" | jq -r '(.connections // .)[] | select(.uid | startswith("app-gallery:notion:")) | .id' | head -n1)"
if [[ -z "$notion" ]]; then
    echo "  skip (Notion is not connected)"
else
    profiles="$(api GET "/companies/$COMPANY/tools/profiles" | jq -c '.profiles')"
    gallery_profile="$(jq -r --arg k "app:$notion" '.[] | select(.profileKey==$k) | .id' <<<"$profiles")"
    if [[ -n "$gallery_profile" ]] && jq -e --arg id "$gallery_profile" --arg c "$COMPANY" \
        'any(.[] | select(.id==$id) | .bindings[]; .targetType=="company" and .targetId==$c)' <<<"$profiles" >/dev/null; then
        api POST "/companies/$COMPANY/tools/profiles/$gallery_profile/unbind" \
            "$(jq -nc --arg c "$COMPANY" '{targetType:"company",targetId:$c}')" >/dev/null
        echo "  unbound the all-agents Notion profile"
    fi
    for entry in "${NOTION_PROFILES[@]}"; do
        IFS='|' read -r key title tools slugs <<<"$entry"
        wanted_tools="$(printf '%s\n' $tools | jq -R . | jq -sc 'sort')"
        profile="$(jq -c --arg k "$key" '.[] | select(.profileKey==$k)' <<<"$profiles")"
        if [[ -z "$profile" ]]; then
            entries="$(jq -c --arg c "$notion" '[.[] | {selectorType:"tool_name",effect:"include",connectionId:$c,toolName:.}]' <<<"$wanted_tools")"
            profile="$(api POST "/companies/$COMPANY/tools/profiles" "$(jq -nc --arg k "$key" --arg n "$title" --argjson e "$entries" \
                '{profileKey:$k,name:$n,status:"active",defaultAction:"deny",entries:$e}')")"
            profile="$(jq -c '.profile // .' <<<"$profile")"
            echo "  created $title"
        elif [[ "$(jq -c '[.entries[].toolName] | sort' <<<"$profile")" != "$wanted_tools" ]]; then
            for old in $(jq -r '.entries[].id' <<<"$profile"); do api DELETE "/tool-profile-entries/$old" >/dev/null; done
            for tool in $tools; do
                api POST "/tool-profiles/$(jq -r .id <<<"$profile")/entries" "$(jq -nc --arg c "$notion" --arg t "$tool" \
                    '{selectorType:"tool_name",effect:"include",connectionId:$c,toolName:$t}')" >/dev/null
            done
            echo "  updated $title"
        fi
        profile_id="$(jq -r .id <<<"$profile")"
        bound="$(jq -c '[(.bindings // [])[] | select(.targetType=="agent") | .targetId]' <<<"$profile")"
        wanted_ids="$(for slug in $slugs; do jq -r --arg n "${NAME[$slug]}" '.[] | select(.name==$n) | .id' <<<"$AGENTS"; done | jq -R . | jq -sc .)"
        for agent_id in $(jq -r --argjson b "$bound" '.[] | select(. as $a | $b | index($a) | not)' <<<"$wanted_ids"); do
            api POST "/companies/$COMPANY/tools/profiles/$profile_id/bind" \
                "$(jq -nc --arg a "$agent_id" '{targetType:"agent",targetId:$a}')" >/dev/null
        done
        for agent_id in $(jq -r --argjson w "$wanted_ids" '.[] | select(. as $a | $w | index($a) | not)' <<<"$bound"); do
            api POST "/companies/$COMPANY/tools/profiles/$profile_id/unbind" \
                "$(jq -nc --arg a "$agent_id" '{targetType:"agent",targetId:$a}')" >/dev/null
        done
        printf "  %-18s %2s tools → %s\n" "$title" "$(jq length <<<"$wanted_tools")" "$slugs"
    done
fi

log "Done — http://localhost:3100"
