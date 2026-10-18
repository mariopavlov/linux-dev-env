# Paperclip agent team

The agent company that runs on this machine's Paperclip (`http://localhost:3100`, installed by
`setup-fedora-wsl/install.sh --paperclip`). Design: `docs/superpowers/specs/2026-10-18-paperclip-agent-team-design.md`.
Why things are the way they are: `FINDINGS.md`.

## Layout

| Path | What |
|---|---|
| `src/agents/<slug>.md` | Each agent's instructions (frontmatter: name, title, reportsTo) |
| `src/team-rules.md` | Rules every agent follows; appended to every agent by `build.sh` |
| `company/` | The importable Paperclip package — `agents/*/AGENTS.md` are **generated**, `COMPANY.md` and `.paperclip.yaml` (roles, adapters, permissions) are hand-written |
| `build.sh` | Regenerates `company/agents/*/AGENTS.md`; `--check` fails when stale |
| `configure.sh` | Imports the company once, then applies what the package cannot carry |
| `tests/build_test.sh` | Build test, including "committed package is up to date" |

## The team

| Agent | Runtime | Reports to | Role |
|---|---|---|---|
| Principal Architect | Claude | — (CEO) | Requirements → design, D-decisions, board approval, Notion sync |
| Delivery Lead | Claude | Principal Architect | Plan → issues, review chains, merges into milestone branch, milestone PR |
| Developer 1, 2 | Codex | Delivery Lead | Implement issues, TDD |
| Refactorer | Codex | Delivery Lead | First review stage: removes comments and needless abstraction; never touches tests |
| Platform Engineer | Codex | Delivery Lead | Containers, IaC, CI/CD |
| Cloud Architect | Claude | Principal Architect | Cloud-native design review; reviews Platform work |
| Security·Codex, Security·Claude | Codex, Claude | Principal Architect | Independent threat models and reviews |
| DDD Reviewer | Claude | Delivery Lead | Bounded contexts, aggregates, ubiquitous language |
| QA Engineer | Claude | Delivery Lead | Acceptance criteria, edge cases, demo/runbook checks |
| Teacher | Claude | Principal Architect | Teaches Mario, on request only |

Review chains (set by the Delivery Lead on each issue): code — Refactorer → DDD Reviewer → QA →
Delivery Lead approval; infrastructure — Refactorer → Cloud Architect → Security·Claude →
Delivery Lead approval.

## Changing the team

1. Edit `src/agents/<slug>.md` or `src/team-rules.md`.
2. `bash paperclip/build.sh && bash paperclip/tests/build_test.sh`
3. Apply to the running company: Paperclip import into an existing company
   (`paperclipai company import paperclip/company --target existing -C <id> --collision replace`),
   then `bash paperclip/configure.sh`.

`configure.sh` is safe to re-run. It sets: experimental isolated workspaces (per-issue git
worktrees under `<repo>/.paperclip/worktrees/`), pinned skill sources (Superpowers, Azure, AWS,
Terraform), each agent's skills, its working directory (`~/.paperclip/agent-homes/<slug>`),
`ENABLE_CLAUDEAI_MCP_SERVERS=false` for Claude agents (so no agent sees Mario's Gmail, Drive and
other claude.ai connectors), concurrency (Claude 1, Codex 2), the Delivery Lead's daily heartbeat,
and the local `teacher` skill. To bump a skill repo, change its commit in `SOURCES`.

## One-time secrets

- **GitHub** — fine-grained token, resource owner `mariopavlov`, only the repos the team works
  on, permissions Contents RW, Pull requests RW, Metadata R, 90-day expiry:
  `GITHUB_TOKEN=github_pat_… bash paperclip/configure.sh`. Then, on each work project, add the
  project env `GH_TOKEN` → secret `GITHUB_TOKEN` (Project → Settings → Environment).
- **Notion** (CEO decision sync, Teacher records) — create an internal integration at
  notion.so/profile/integrations, share only the Perigee area, Study Assignments, Knowledge Checks
  and Check Attempts with it, then in Paperclip: Tools → Import MCP JSON with
  `{"mcpServers":{"notion":{"command":"npx","args":["-y","@notionhq/notion-mcp-server"],"env":{"NOTION_TOKEN":"<token>"}}}}`
  and grant it to Principal Architect and Teacher only.

## Starting work on a repo

Project → New: workspace = the local repo path (Linux filesystem), execution workspaces
**isolated**, strategy **git worktree**, base ref = the milestone branch (e.g. `m0`). Add
`.paperclip/` and `.claude/` to the repo's `.gitignore`.

## Your two gates

- **Front gate — Approvals page.** The Principal Architect submits each strategy for your
  approval; design changes found mid-flight also arrive here. Approve, reject, or request revision.
- **Back gate — the milestone PR on GitHub.** The Delivery Lead opens `m0 → main` with a demo
  checklist, runbooks and a review digest (every finding, who raised it, the fixing commit). You
  run the demo and rebase-merge. Only you can merge `main` (ruleset).
- **Blocked inbox.** Agents ask you questions only by blocking an issue with one question.

## Calling the Teacher

- **Learning a topic:** in any Claude Code session, say "teach me …" — the `teacher` skill runs
  live and records to Notion.
- **Understanding a proposal:** on the issue, create a child issue "Help me understand: …"
  assigned to Teacher (@-mentions wake the assignee, not the mentioned agent).

## Watching quota

Subscription runs cost 0 cents in Paperclip, so money budgets never stop an agent. Watch the real
windows with `paperclipai cost quota-windows -C <company-id>` (Claude 5-hour and weekly, Codex
5-hour) and pause agents in the UI when Claude runs hot.
