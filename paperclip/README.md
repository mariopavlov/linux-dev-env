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

| Agent | Runtime | Role |
|---|---|---|
| Principal Architect (CEO) | Claude | Brainstorms with Mario, writes spec + plan, sizes the change, runs spec reviews, gets Mario's approval, assigns builds, decides on QA, opens the milestone PR |
| Developer 1, 2 | Codex | Implement plan tasks, TDD |
| Platform Engineer | Codex | Containers, IaC, CI/CD |
| Refactorer | Codex | Right after implementation: removes comments and needless abstraction; never touches tests |
| QA Engineer | Claude | Checks the refactored code against spec, plan and implementation; PASS/FAIL |
| Cloud Architect | Claude | Reviews specs and plans for cloud-native fit (8 skills) |
| Security·Codex, Security·Claude | Codex, Claude | Independent threat models of specs and plans |
| DDD Reviewer | Claude | Reviews specs and plans for the domain model |
| Teacher | Claude | Teaches Mario, on request only |

Everyone reports to the Principal Architect. Specialists review code only when the Principal asks.

## How work flows

1. **Gate 1 — brainstorm.** Open **Agent Chat** with the Principal Architect and describe what you
   want. It asks you questions one at a time, then writes spec, decisions and plan in the repo.
2. **Spec review.** Small changes skip it. Otherwise the Principal sends the spec and plan to the
   specialists the change needs and resolves what it can.
3. **Gate 2 — Approvals page.** The reviewed spec, plan, review summary and the questions only you
   can answer. Answer in the thread; request revision to loop back. Nothing is built before this.
4. **Build.** Each plan task: Codex developer → Refactorer → QA → Principal decides (merge into the
   milestone branch, send fixes back, or ask a specialist to review the code).
5. **Gate 3 — milestone PR on GitHub** (`m0 → main`): demo checklist, runbooks, review digest.
   You rebase-merge; only you can merge `main`.

Mid-build questions reach you as blocked issues in the **Blocked inbox**.

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
other claude.ai connectors), concurrency (Claude 1, Codex 2), the Principal Architect's daily heartbeat, Agent Chat,
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

## Calling the Teacher

- **Learning a topic:** in any Claude Code session, say "teach me …" — the `teacher` skill runs
  live and records to Notion.
- **Understanding a proposal:** on the issue, create a child issue "Help me understand: …"
  assigned to Teacher (@-mentions wake the assignee, not the mentioned agent).

## Watching quota

Subscription runs cost 0 cents in Paperclip, so money budgets never stop an agent. Watch the real
windows with `paperclipai cost quota-windows -C <company-id>` (Claude 5-hour and weekly, Codex
5-hour) and pause agents in the UI when Claude runs hot.
