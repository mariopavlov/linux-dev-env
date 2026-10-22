# Paperclip spike findings

Paperclip 2026.1012.0, Fedora WSL2, 2026-10-18. Throwaway company "Spike" with one `claude_local`
and one `codex_local` probe agent and a scratch Go repo. Each entry: question, what was done,
result, decision for the real company.

## 1. Company package format

**Did:** `paperclipai company export <id> --include company,agents,skills`.

**Result:**
- `COMPANY.md` — frontmatter `name`, `description`, `schema: agentcompanies/v1`, `slug`.
- `agents/<slug>/AGENTS.md` — frontmatter `name`, `reportsTo: <slug>`, `skills: [<skill key>…]`;
  the body is the agent's instructions.
- `.paperclip.yaml` — `schema: paperclip/v1`; per agent: `role`, `adapter.type`, `adapter.config`,
  `permissions`, `permissionGrants`, `appearance`.
- `skills/<key>/SKILL.md` — skills with `metadata.sources` (repo, commit, path).
- **`adapter.config.cwd` is not exported** — it is machine-specific and must be set after import.
- **Default permissions are broad:** every agent gets `canCreateAgents`, `canCreateSkills`,
  `agents:configure`, `tools:manage_connections`.

**Decision:** author the company in this format under `paperclip/company/`. Set `cwd` per agent
after import (script). Tighten permissions: only the CEO and Delivery Lead keep task assignment;
nobody creates agents or skills or manages connections.

## 2. Claude agent: plugins and Superpowers through its `cwd`

**Did:** `claude_local` agent with `cwd` = a folder whose `.claude/settings.json` enables plugins at
project scope (`claude plugin install <p> --scope project`). Asked it to list skills and MCP tools.

**Result:**
- Project-scope plugins load fully: `azure` gave 28 skills and its MCP server (~80 tools);
  `superpowers` gave all 15 skills plus its SessionStart hook.
- **User-scope plugins do not load** (Superpowers was missing until enabled in the `cwd`).

**Correction (SPI-11, issue run inside a project worktree):** the agent's `pwd` is the issue's
worktree, not its adapter `cwd`, so **no plugins load during real work** — neither project-scope
plugins from the adapter `cwd` nor user-scope ones. Only Paperclip-attached skills appear.

**Decision:** all skills reach all agents (Claude and Codex) as **Paperclip company skill sources**,
pinned to a commit and attached per agent: Superpowers for every delivery agent; Azure
(`microsoft/azure-skills`, `MicrosoftDocs/Agent-Skills` well-architected), AWS
(`aws/agent-toolkit-for-aws`) and Terraform (`hashicorp/agent-skills`) skills for the Cloud
Architect; Terraform for Platform/DevOps. No cloud MCP servers in the pilot — agents hold no cloud
credentials, so the skill text is what review needs. MCP servers that are needed (Notion) go
through Paperclip's governed tools (`POST /api/companies/{id}/tools/mcp/import-json`) and are
granted only to the agents that need them.

## 3. Codex agent: Superpowers

**Did:** first run without skills; then added `obra/superpowers` as a company skill source pinned
to commit `bb92a77741419a4ab5f06e711a283343f1ada0c3` (`POST /api/companies/{id}/skill-sources`)
and attached its 15 skills to the agent (`POST /api/agents/{id}/skills/sync`).

**Result:** Codex runs with an isolated per-company `CODEX_HOME`, so it sees none of
`~/.codex`. After attaching, it listed all Superpowers skills and quoted `brainstorming`'s first
step correctly.

**Decision:** Codex agents get Superpowers as a pinned company skill source. Bumping Superpowers
is a deliberate commit change.

## 4. claude.ai connectors (Notion) — security finding

**Did:** asked the Claude agent to fetch a Notion page and list one Gmail thread (metadata only).

**Result:** every Claude agent inherits **all 21 claude.ai connectors** of Mario's account
(Gmail, Google Drive/Calendar/Docs/Sheets, Dropbox, Notion, Todoist, Superhuman, Figma, Miro, …),
and they are usable, not gated: Notion fetch and Gmail search both worked. With permission
bypass on, any agent could read or act on Mario's mail and files.

**Lockdown check:** set `ENABLE_CLAUDEAI_MCP_SERVERS=false` in the agent's adapter `env` and
re-probed. Gmail became unreachable ("No matching deferred tools"); only the Paperclip, Azure and
unauthenticated synced-plugin stubs remained.

**Decision:** every Claude agent runs with `ENABLE_CLAUDEAI_MCP_SERVERS=false` in its adapter
`env` (SPI-11 confirmed no connectors inside a worktree with it set). The agents that need Notion
(CEO for decision sync, Teacher for learning records) get Notion's official MCP server through
Paperclip's governed tools, authenticated with a Notion **internal integration token** — the
integration only sees the pages Mario shares with it (Perigee area, Study Assignments, Knowledge
Checks, Check Attempts), not the whole workspace.

## 5. Wake on @-mention

**Did:** commented `@claude-probe …` on an issue assigned to the Codex probe.

**Result:** the **assignee** (Codex) woke and answered; the mentioned agent did not.

**Decision:** the Teacher's in-context mode uses a child issue assigned to the Teacher
(`issue child:create`), which reliably wakes it. Mentions are not used to route work.

## 6. Review stage routing (Codex → Claude)

**Did:** Codex task with `executionPolicy: {mode: normal, commentRequired: true, stages: [{type:
review, approvalsNeeded: 1, participants: [{type: agent, agentId: <claude>}]}]}`.

**Result:** when Codex finished, the issue moved to `in_review` and was **reassigned to the Claude
reviewer**, who re-ran `go test` and `go vet`, checked the diff and commit message, approved with a
comment, and the issue closed `done`. Stage types are `review` and `approval`; participants are
agents or users; `approvalsNeeded` only allows 1.

**Decision:** chained stages, one participant per stage, so every review is its own visible
decision on the issue: `review` Refactorer → `review` DDD Reviewer → `review` QA → `approval`
Delivery Lead. The Refactorer stage commits its cleanup on the issue's branch and then approves;
that a review-stage agent can commit in the issue's workspace is **unverified** — Task 10 checks it,
fallback is a Refactorer child issue on the same branch.

**Superseded (WKL M0, 2026-10-22):** on KEY-16 the reviewer's stage decision reassigned the issue,
which cancelled the reviewer's run before the decision was saved; the issue then refused every
wake and QA re-ran on KEY-23. Reviews are now child issues the reviewer closes, in the build
issue's workspace, and the Principal waits on them through `blockedBy`. Fix issues and follow-ups
on an existing branch need `executionWorkspaceId` set at creation: `isolated_workspace` alone gave
them a fresh worktree from `main` (KEY-28, 31, 51, 54, 61). Paperclip bug report: Notion,
"Contribute to Paperclip (open source)".

## 8. Isolated workspaces and branches

**Did:** three Codex tasks against a `local_path` project workspace.

**Result:**
- Project `executionWorkspacePolicy` alone did nothing: the first task switched the shared
  checkout to a new branch; the second created its own worktree **in `/tmp`** via Superpowers'
  `using-git-worktrees` (lost on every WSL restart).
- Isolation is an **experimental instance flag**, off by default:
  `PATCH /api/instance/settings/experimental {"enableIsolatedWorkspaces": true}`. With it on and the
  issue carrying `projectWorkspaceId` + `executionWorkspaceSettings: {mode: isolated_workspace}`,
  Paperclip created `<repo>/.paperclip/worktrees/<ISSUE-ID>-<slug>` on branch `<ISSUE-ID>-<slug>`
  and the shared checkout was untouched.
- Runs leave untracked `.paperclip/` and `.claude/` in the repo.

**Decision:** enable `enableIsolatedWorkspaces` (and `…ByDefault`); project policy `defaultMode:
isolated_workspace`, `workspaceStrategy: {type: git_worktree, baseRef: m0}`. Developer instructions:
work in the directory you start in, never create your own worktree. Perigee `.gitignore` gets
`.paperclip/` and `.claude/` in the first Paperclip issue.

## 9. Codex permission bypass

`codex_local` agents are created with `dangerouslyBypassApprovalsAndSandbox: true` (export shows it).
Accepted for the pilot per the spec (no cloud credentials); revisit before credentials.

## 10. Cleanup

`company delete` fails once a company has runs (500: `cost_events_heartbeat_run_id_heartbeat_runs_id_fk`
blocks deleting `heartbeat_runs`). Workaround used on 2026-10-18 after a `paperclipai db:backup`:
delete that company's rows from `cost_events` (embedded Postgres on :54329, user/db `paperclip`),
then `DELETE /api/companies/<id>` succeeds. Archived spike, v1 and duplicate companies were removed
this way; the company was re-created as Keystone to get the `KEY` prefix. Deleting a **project**
that has had runs hits the same bug (`cost_events_project_id_projects_id_fk`); same workaround,
scoped by `project_id`.

## 11. Smoke runs v1 and v2 (paperclip-smoke, 2026-10-18)

**v1 (`/health`, original flow):** the design phase alone — four mandatory specialist reviews —
read ~3.5M tokens and moved Claude's 5-hour window from 11 % to 25 %. Cause: the Principal's
instructions forced all four reviews regardless of size. Led to flow v2 (spec §11a).

**v2 (`/health` via Agent Chat, then a cloud-native task via a project task):**
- Worked: brainstorm in chat and in a task; small sizing skipped reviews; Gate 2 as an in-thread
  confirmation card; Developer → Refactorer → QA → Principal → task PR into `m0` (PR #1, with a
  `refactor:` commit); specialist spec reviews for the standard task.
- Mario merged the task PR before the Principal approved — agent PRs are opened with Mario's
  `gh` login and looked like his to merge. **Fix:** draft task PRs and a `Milestone: <branch>`
  ruleset requiring the `paperclip/approval` status, which only the Principal sets
  (`setup-repo.sh`).
- The status stayed `in_review` through four Q&A rounds, so Mario could not see what waited on
  him. **Fix:** team rule — `in_progress` working, `in_review` awaiting an agent review, `blocked`
  awaiting Mario.
- One question per card meant one cold-start Principal run per answer (13 runs, ~21M cached
  tokens). **Fix:** all questions in one card.
- The Principal created build issues reusing **its own** execution workspace; both developers
  wrote into the spec worktree. **Fix:** build issues are created with
  `executionWorkspaceSettings: {mode: isolated_workspace}` and no `executionWorkspaceId`, and the
  Principal checks each got its own branch; every agent stops if its directory is not its own
  worktree.
- Codex agents call Paperclip's `connections_search`/`connection_request` and file "Connect
  GitHub" cards (OAuth start 403), then use `gh` anyway — `gh` works for every agent. **Fix:**
  team rule — `gh` only, never request a GitHub connection.
- A comment by Mario on an issue while its agent is running **cancels and restarts** that run.
- The Principal opened a milestone PR after a single task. **Fix:** a milestone ends when every
  build issue of the approved plan is merged.
- Agent commits were authored as Mario. **Fix:** `configure.sh` sets `GIT_AUTHOR_NAME` /
  `GIT_COMMITTER_NAME` to the agent's name with Mario's email (keeps his contribution graph)
  and every commit ends with `Co-Authored-By: <agent> <marioppavlov@gmail.com>` (replacing Paperclip's bare `Co-Authored-By: Paperclip` line).
- Quota after v2: Claude week 8 % → 11 %, Codex 5-hour 3 %. The Principal is the cost centre.
  Open lever for later: reviewers on Sonnet, more review on Codex.

## Claude agents fail with "ACP agent reported a terminal service failure" (2026-10-18)

- `claude_local` runs through ACP by default (`engine: auto`). Paperclip 2026.1012.0 ships
  `@agentclientprotocol/claude-agent-acp` 0.73.0, whose agent SDK bundles Claude Code 2.1.257.
  That build rejects `claude-opus-5-5` ("version 2.1.28x or newer is required"); the run log
  shows it under the generic `acpx_turn_failed` / terminal service failure.
- The sidecar only resolves the system `claude` on Windows, so on Linux the bundled one is used.
- Fix: `configure.sh` sets `CLAUDE_CODE_EXECUTABLE=$(command -v claude)` in every Claude agent's
  env, so ACP uses the self-updating system Claude Code. Exact failed-run retries keep their old
  context; wake the agent on the issue instead.

## M0 build: sub-agents asking Mario, a hung run, and Codex spend (2026-10-19)

- A team rule told every agent to put what it needs from Mario in a card. Developers and the
  Platform Engineer then posted cards addressed to the Principal; the Principal's wake was
  cancelled each time (`issue_assignee_changed`) as the asker set its own issue `blocked`, so the
  cards fell to Mario. While a card waited, the asker was re-woken about once a minute
  (`blockers_restored`) — 73 Codex sessions on KEY-21. Fix: only the Principal, Mentor and Teacher
  create cards; others open a `Question:` child issue for the Principal and `blockedBy` it.
- KEY-16's Developer 1 run hung for nine hours after opening its PR: no adapter timeout and only a
  daily sweep. Fix: `timeoutSec` 2700 (5400 for Principal and Mentor), hourly Coordinator.
- Codex usage since setup: 165 sessions, 7.1M uncached input, 95.5M cached. `codex-acp`'s default
  mode ("Approve for me", `auto_review`) runs a guardian sub-agent (`codex-auto-review`) that
  re-reads the whole context per check: 39% of uncached tokens. The wake loop added 14%. Fix:
  `INITIAL_AGENT_MODE=agent-full-access` for Codex agents (applies to new sessions) and one-shot
  sessions for single-pass reviewers.
