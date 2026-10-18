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

| Agent | Runtime · model · effort | Role |
|---|---|---|
| Principal Architect (CEO) | Claude · Opus 5.5 · high | Brainstorms with Mario, writes spec + plan, sizes the change, runs spec reviews, gets Mario's approval, assigns builds, decides on QA, opens the milestone PR |
| Developer 1, 2 | Codex · gpt-6-astra · medium | Implement plan tasks, TDD |
| Platform Engineer | Codex · gpt-6-astra · medium | Containers, IaC, CI/CD |
| Refactorer | Codex · gpt-6-astra · low | Right after implementation: removes comments and needless abstraction; never touches tests |
| QA Engineer | Claude · Sonnet 5.5 · medium | Checks the refactored code against spec, plan and implementation; PASS/FAIL |
| Cloud Architect | Claude · Sonnet 5.5 · high | Reviews specs and plans for cloud-native fit (8 skills) |
| Security·Codex, Security·Claude | Codex · gpt-6-astra · high; Claude · Sonnet 5.5 · high | Independent threat models of specs and plans, with Security·DeepSeek |
| DDD Reviewer | Claude · Sonnet 5.5 · high | Reviews specs and plans for the domain model |
| Teacher | Claude · Sonnet 5.5 · high | Teaches Mario, on request only |
| Coordinator | OpenCode · Ollama nemotron-3-super · low | Daily sweep: nudges stalled issues, digest of what waits for Mario, escalates decisions |
| Research Scout | OpenCode · Ollama deepseek-v4.1-flash · medium | Reads docs and code on request ("Research: …"), returns a sourced one-page brief |
| Security·DeepSeek | OpenCode · Ollama deepseek-v4-pro · high | Third independent security reviewer (third model family) |

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
3. `bash paperclip/configure.sh` — pushes each agent's instructions to the running company (only
   when they changed), plus skills and runtime settings. Adding or removing an agent needs an
   import; Paperclip's import does not replace existing agents.

`configure.sh` is safe to re-run. It sets: experimental isolated workspaces (per-issue git
worktrees under `<repo>/.paperclip/worktrees/`), pinned skill sources (Superpowers, Azure, AWS,
Terraform), each agent's skills, its working directory (`~/.paperclip/agent-homes/<slug>`),
`ENABLE_CLAUDEAI_MCP_SERVERS=false` for Claude agents (so no agent sees Mario's Gmail, Drive and
other claude.ai connectors), concurrency (Claude 1, Codex 2), the Coordinator's daily heartbeat, Agent Chat,
the local `teacher` skill, every agent's instructions, and its model and reasoning effort (`MODEL`, `EFFORT` — pinned so upgrades cannot change them silently). New skill repos are added at the commit in `SOURCES`. Paperclip's API cannot move an existing source to another commit (delete only disables it), so to bump a pin change it in `SOURCES` *and* in the UI (Skills → sources); `configure.sh` warns while the two differ.

## Branding

- Company **Keystone**, issue prefix **`KEY`**. Paperclip derives the prefix from the company name
  once, at creation; it cannot be changed later.
- Logo: `branding/keystone-logo.svg` (source) and `.png` (uploaded by `configure.sh` when the
  company has none).
- Agent icons and avatar palettes are set by `configure.sh` (`ICON`, `PALETTE`), grouped by runtime:
  violet/blue palettes for Claude, warm for Codex, green for Ollama.

## Ollama agents

The Coordinator, Research Scout and Security·DeepSeek run in OpenCode on **Ollama Cloud** models
through the local Ollama daemon (`ollama signin` once per machine; provider config in
`dotfiles/dot_config/opencode/opencode.jsonc`). They draw on the Ollama Pro plan's $60/month
credits, not on Claude or Codex quota.

## Credentials

- **GitHub:** agents use **your `gh` login** (`~/.config/gh/hosts.yml`) — nothing to configure.
  Consequence: GitHub sees agents as you. The `main` ruleset blocks direct pushes, but an agent
  could still merge a PR into `main`; that is prevented only by the agents' instructions. The
  `paperclip/approval` check on the milestone branch is set by the Principal with the same login.
  A least-privilege token or a bot identity is a later step (not used now); such a token would
  need Contents, Pull requests and **Commit statuses** read/write.
- **Notion** (CEO decision sync, Teacher records) — create an internal integration at
  notion.so/profile/integrations, share only the Perigee area, Study Assignments, Knowledge Checks
  and Check Attempts with it, then in Paperclip: Tools → Import MCP JSON with
  `{"mcpServers":{"notion":{"command":"npx","args":["-y","@notionhq/notion-mcp-server"],"env":{"NOTION_TOKEN":"<token>"}}}}`
  and grant it to Principal Architect and Teacher only. (Unverified: the tool names this server
  exposes may differ from those in `teacher/notion.md`; check on the first run.)

## Starting work on a repo

1. `bash paperclip/setup-repo.sh <owner/repo> <milestone-branch> <local-path>` — rebase-only
   merges, the `main` ruleset, the milestone branch, and its `paperclip/approval` check. Add any
   `.gitignore` entries it reports (`.paperclip/`, `.claude/`).
2. Paperclip → Project → New: workspace = the local repo path (Linux filesystem), execution
   workspaces **isolated**, strategy **git worktree**, base ref = the milestone branch.

## Working with the team

- **Start work** with a task in the project, assigned to the Principal Architect (or Agent Chat
  with it). Describe the problem in your own words.
- **Status tells you who waits on whom:** `in_progress` an agent is working, `in_review` an agent
  is reviewing, `blocked` **it waits for you** — filter on `blocked` or use the Blocked inbox.
- **Questions** arrive as one card with all of them; answer them together and add anything else.
- **Gate 2** is a confirmation card in the task; **Gate 3** is the milestone PR on GitHub
  (`m0 → main`), the only PR you merge. Task PRs are drafts the Principal merges.
- **Don't comment on an issue while its agent is running** — Paperclip cancels and restarts the
  run. Wait for its end-of-run comment.
- Agents use your `gh` login; their commits show "<agent> (Paperclip)" as author with your email.

## Calling the Teacher

- **Learning a topic:** in any Claude Code session, say "teach me …" — the `teacher` skill runs
  live and records to Notion.
- **Understanding a proposal:** on the issue, create a child issue "Help me understand: …"
  assigned to Teacher (@-mentions wake the assignee, not the mentioned agent).

## Watching quota

Subscription runs cost 0 cents in Paperclip, so money budgets never stop an agent. Watch the real
windows with `paperclipai cost quota-windows -C <company-id>` (Claude 5-hour and weekly, Codex
5-hour) and pause agents in the UI when Claude runs hot.
