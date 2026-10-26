# Paperclip agent team

The agent company that runs on this machine's Paperclip (`http://localhost:3100`, installed and
configured by `setup-fedora-wsl/install.sh --paperclip`, which ends by running `configure.sh`). Design: `docs/superpowers/specs/2026-10-18-paperclip-agent-team-design.md`.
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
| `tests/team_test.sh` | Every agent in `src/agents/` is in each `configure.sh` map and `.paperclip.yaml`, and every `reportsTo` exists |

## The team

Five teams. Team leads report to the Principal Architect; members report to their lead
(`reportsTo` in each agent file). QA stays independent of whoever ships because QA writes the
tests and nobody else may change them.

| Team | Lead | Members |
|---|---|---|
| Leadership | Principal Architect | Research Scout, Cloud Architect Advisor, Teacher |
| Engineering | Delivery Lead | Developer 1, Developer 2, Platform Engineer, Refactorer, Delivery QA |
| Security | Security Lead | Security·Codex, Security·Claude, Security·DeepSeek, Red Team Engineer, Security QA |
| Review | Review Lead | Cloud Architect, DDD Reviewer, Bug Hunter·Claude, Bug Hunter·Open, Spec & Contract Critic, Maintainability Critic, First-Principles Critic, History Critic, Disprover·Claude, Disprover·Open, Critic·Sol |
| Chronicle | Chronicle Lead | Technical Writer, Audit Writer, Mentor |

| Agent | Runtime · model · effort | Role |
|---|---|---|
| Principal Architect (CEO) | Claude · Opus 5.5 · high | Picks up milestones from Notion, brainstorms with Mario in Keystone, writes spec + plan with a `Route:` line on every task, sizes the change, sends spec reviews to the Review Lead and, for auth, data, exposure or secrets, to the three security reviewers directly, gets Mario's approval, hands the build to the Delivery Lead, then the documents and the record to the Chronicle Lead, opens the milestone PR, keeps the milestone row's `Status`, runs retros; may offer Mario a Teacher session |
| Delivery Lead | Claude · Sonnet 5.5 · high | Runs the build of an approved milestone: has QA write each task's tests first, creates build issues, follows each task's route (Refactorer, then `Review:` and `Security review:`), runs fixes and acceptance, decides on it, runs the security round, merges each task into the milestone branch; keeps the build log and `review-digest` |
| Developer 1, 2 | Codex · gpt-6-astra · medium | Implement plan tasks, TDD |
| Platform Engineer | Codex · gpt-6-astra · medium | Containers, IaC, CI/CD |
| Refactorer | Codex · gpt-6-astra · low | Right after implementation: removes comments and needless abstraction; never touches tests |
| Delivery QA | Claude · Sonnet 5.5 · high | Owns the test framework and writes each task's acceptance, integration and deployment tests before the developer starts, plus a regression test for each correctness finding from review; after the review stages: tests unchanged, suite passes, requirements met, edge cases; PASS/FAIL. Also fact-checks every document. Does not judge code quality; the Review team does |
| Cloud Architect Advisor | Claude · Sonnet 5.5 · high | Answers Mario's design questions on a `Design questions: <milestone>` issue: short, sourced answers and possible defects for him to raise; read-only, separate from the Cloud Architect so reviews stay independent |
| Research Scout | OpenCode · Ollama deepseek-v4.1-flash · medium | Reads docs and code on request ("Research: …"), returns a sourced one-page brief |
| Teacher | Claude · Sonnet 5.5 · high | Teaches Mario, on request or after he says yes to an offer from the Principal or Claude |
| Security Lead | Codex · gpt-6.1 Sol · high | Leads the security agents: fans a review out (per task or per milestone), consolidates one verdict for whoever asked (surfacing dissent, never flattening it), owns the threat model and the Red Team's scope; the round ends at its verdict |
| Security·Codex, Security·Claude | Codex · gpt-6-astra · high; Claude · Sonnet 5.5 · high | Independent threat models of specs, plans and code, with Security·DeepSeek |
| Security·DeepSeek | OpenCode · Ollama deepseek-v4-pro · high | Third independent security reviewer (third model family) |
| Red Team Engineer | OpenCode · Ollama glm-5.3 · high | Stands a solution up in a throwaway local Docker sandbox and attacks the running deployment; confirms or refutes the reviewers' threats and finds new ones |
| Security QA | Claude · Sonnet 5.5 · high | Writes the tests that prove each security control holds and a regression test for every security finding to fix; security acceptance after the Refactorer |
| Review Lead | Claude · Opus 5.5 · high | Takes `Review: <KEY-n>` (code, per plan task) and `Review: spec <milestone>`; picks lenses (never drops one the route names), fans out to critics, sends each finding to a Disprover on another model family, consolidates one verdict, sends `Review fixes:` to the Delivery Lead and has the critics re-check; approves only with no critical or high finding open |
| Bug Hunter·Claude | Claude · Sonnet 5.5 · high | Correctness: logic, edge cases, races, swallowed errors; every "will break" names the input that breaks it. In the minimum review of any code task |
| Bug Hunter·Open | OpenCode · Ollama deepseek-v4-pro · high | Same angle on a second model family, for risky changes |
| Spec & Contract Critic | Claude · Sonnet 5.5 · high | Does what the spec says and nothing more; APIs, types, invariants, breaking changes; do the tests test behaviour. In the minimum review |
| Maintainability Critic | OpenCode · Ollama glm-5.3 · high | Standards, complexity, duplication, naming, waste, scoped to the changed code |
| First-Principles Critic | Claude · Opus 5.5 · high | Is the approach itself right; hidden assumptions; simpler alternatives |
| History Critic | OpenCode · Ollama deepseek-v4.1-flash · medium | Recurring bugs, drift from earlier decisions and ADRs, reverted fixes |
| Cloud Architect | Claude · Sonnet 5.5 · high | Reviews specs and code for cloud-native fit (8 skills); a Review lens |
| DDD Reviewer | Claude · Sonnet 5.5 · high | Reviews specs and code for the domain model; a Review lens |
| Disprover·Claude, Disprover·Open | Claude · Sonnet 5.5 · high; OpenCode · Ollama deepseek-v4-pro · high | Try to kill each finding (keep, drop or downgrade, with evidence; when unsure, keep). Never on the family of the critic whose finding they judge |
| Critic·Sol | Codex · gpt-6.1 Sol · high | The fallback: stands in for any Ollama role (critic or Disprover) when Ollama is down or out of credits |
| Chronicle Lead | Claude · Opus 5.5 · high | Twice per milestone: `Chronicle: <milestone>` (the documents, before the milestone PR) and `Chronicle record: <milestone>` (the Notion record and the Mentor's finished sync, after the merge). Fans out to the writers, has Delivery QA fact-check each document; writes nothing itself |
| Technical Writer | Claude · Opus 5.5 · high | Writes and edits every client document — solution architecture, migration plans, runbooks, handover guides — to one house standard; other agents supply the facts. The Delivery Lead still hands it client-document plan tasks during the build |
| Audit Writer | Claude · Opus 5.5 · high | Was Security Writer. After the build: `docs/security/<milestone>/` (internal test report, exposures, risks, client exposure report) and `docs/review/<milestone>/` (review audit: findings per task, outcomes, what was tracked, residual concerns) |
| Mentor | Claude · Opus 5.5 · high | After spec approval (a direct issue from the Principal) and, in the record round, after the merge: finds weak points in Mario's answers, creates Study Assignments, keeps the Mastery section and the project record in Notion |

## How work flows

Milestones start and end in **Notion** (🏁 Milestones in 1 - PROJECTS); the conversation and the
work happen in **Keystone**.

1. **A milestone is born** as a row with a rough title and description: you add it (Status
   `Idea`), the Principal creates it after you agree in a chat (`Idea`), or the Principal suggests
   one (`Proposed` — you move it to `Idea` or `Dropped`).
2. **Gate 1 — brainstorm.** Create a Keystone task for the Principal: "Pick up <milestone link> and
   clean up the requirements". It sets the row to `Designing` and asks all its questions in one
   card (issue `blocked`).
3. **Spec review.** Small changes skip it. Otherwise the Principal sends the spec and plan to the
   **Review Lead** (`Review: spec <milestone>`: spec-contract, first-principles, history, ddd and
   cloud-architect lenses, each finding checked by a Disprover) and, when the change touches auth,
   data, exposure or secrets, one review each to Security·Codex, Security·Claude and
   Security·DeepSeek. The Review Lead returns one verdict and no fix issue; the Principal resolves
   what it can by revising the documents.
4. **Gate 2 — spec.** One confirmation card with spec, plan, review summary and open questions.
   On approval the Principal rewrites the milestone's title, summary and done-when, fills its page
   (requirements, decisions, tasks, links, a first dated progress-log line) and sets it to `Building`. Every plan task ends with a
   route: `Route: Review(<lenses | lead picks>) → Security(review | none)`. `→` orders the stages,
   `∥` runs them in parallel; a Technical Writer task is `Route: none`. The Delivery Lead follows
   the route and never changes it; for unplanned work it asks the Principal for one.
5. **Build.** The Principal hands the approved plan to the Delivery Lead (`Build: <milestone>`).
   Each plan task: Delivery QA (and Security QA, for security controls) writes failing tests →
   Codex developer makes them pass → Refactorer → the route's stages: `Review: <KEY-n>` for the
   Review Lead and, when the route says so, `Security review: <KEY-n>` for the Security Lead →
   acceptance by the QAs (tests unchanged, suite passes, requirements met) → Delivery Lead decides
   (merge into the milestone branch or send fixes back).
   - **Review round:** the Review Lead picks the lenses (the minimum on any code task is Bug
     Hunter·Claude and the Spec & Contract Critic; a review spans at least two model families),
     each critic starts from "this change has defects", every finding needs file, line and quoted
     evidence, and a Disprover on another family tries to kill it. The Review Lead posts one
     verdict and sends the must-fix findings as `Review fixes:` to the Delivery Lead. For a
     correctness finding Delivery QA first writes a `Review regression:` test; then the developer
     fixes it and the critic that raised it re-checks. Approval needs no critical or high finding
     open.
   - **Fallback:** every Ollama role falls back to Critic·Sol (GPT-6.1-Sol), never to Claude. The
     verdict names the roles that ran on the fallback, and a finding a fallback Disprover dropped
     carries a note that Sol shares the developers' GPT family.
   - **Known limitation:** an Ollama agent whose provider is out of credits is retried silently by
     Paperclip and cannot wake the Review Lead. The review waits until credits return or someone
     comments on the Review issue.
   - Client documents are their own tasks: Technical Writer → Delivery QA (facts, runbook steps)
     → Delivery Lead decides. When the plan lists security controls, a security round follows the
     last merge and ends at the Security Lead's verdict.
6. **Chronicle: documents.** When the `Build:` issue is done, the Principal creates
   `Chronicle: <milestone>` with the brief (documents, audiences, sources). The Chronicle Lead has
   the Technical Writer and the Audit Writer write them (`docs/security/<milestone>/`,
   `docs/review/<milestone>/`, client documents), Delivery QA fact-checks each, and the Principal
   merges the document PRs into the milestone branch.
7. **Gate 3 — milestone PR on GitHub** (`m0 → main`): demo checklist, runbooks, review digest,
   links to the documents; the row is `In review`. You rebase-merge; only you can merge `main`.
   The row becomes `Done`.
8. **Chronicle: record.** The Principal creates `Chronicle record: <milestone>`; the Chronicle
   Lead writes the milestone's and project's Progress log, Links and Next steps in Notion and has
   the Mentor run its finish sync. The Principal keeps the row's `Status` and `Last update` true
   throughout.

Mid-build questions never come from developers directly: an agent that is stuck opens a
`Question:` child issue for the Delivery Lead, who answers implementation questions and sends the
rest to the Principal, who answers it, asks a specialist, or — only when it is yours to decide —
opens `Decision for Mario: …` under the milestone issue with one card in your
**Inbox**.

## Changing the team

1. Edit `src/agents/<slug>.md` or `src/team-rules.md`.
2. `bash paperclip/build.sh && bash paperclip/tests/build_test.sh && bash paperclip/tests/team_test.sh`
3. `bash paperclip/configure.sh` — pushes each agent's instructions to the running company (only
   when they changed), plus skills and runtime settings. Adding or removing an agent needs an
   import; Paperclip's import does not replace existing agents. To rename an agent, add its slug
   and previous name to `RENAMED`: configure.sh renames the live agent instead of importing a copy.

`configure.sh` is safe to re-run. It also sets run timeouts (45 min; 90 for the Principal and the
Mentor), Codex agents to `agent-full-access` (no guardian reviewer — the QAs and the Delivery Lead are the
gate), one-shot sessions for the Refactorer and Security·Codex.
It sets: experimental isolated workspaces (per-issue git
worktrees under `<repo>/.paperclip/worktrees/`), pinned skill sources (Superpowers, Azure, AWS,
Terraform), each agent's skills, its working directory (`~/.paperclip/agent-homes/<slug>`),
`ENABLE_CLAUDEAI_MCP_SERVERS=false` for Claude agents (so no agent sees Mario's Gmail, Drive and
other claude.ai connectors), concurrency (Claude 1, Codex 2), `OPENCODE_CONFIG_CONTENT` turning off the GitKraken MCP for OpenCode agents (it writes to Jira as Mario), Agent Chat,
the `teacher` skill (from this repo on GitHub, pinned like the other skill sources — push a change to `claude-skills/dot-claude/skills/teacher` and bump its commit to update it), every agent's instructions, and its model and reasoning effort (`MODEL`, `EFFORT` — pinned so upgrades cannot change them silently). New skill repos are added at the commit in `SOURCES`. Paperclip's API cannot move an existing source to another commit (delete only disables it), so to bump a pin change it in `SOURCES` *and* in the UI (Skills → sources); `configure.sh` warns while the two differ — except for a source that tracks its branch (like this repo's `teacher`), which Paperclip re-scans on its own: there it only checks that the scanned commit includes the configured one.

## Branding

- Company **Keystone**, issue prefix **`KEY`**. Paperclip derives the prefix from the company name
  once, at creation; it cannot be changed later.
- Logo: `branding/keystone-logo.svg` (source) and `.png` (uploaded by `configure.sh` when the
  company has none).
- Agent icons and avatar palettes are set by `configure.sh` (`ICON`, `PALETTE`), grouped by runtime:
  violet/blue palettes for Claude, warm for Codex, green for Ollama.

## Ollama agents

The Research Scout, Security·DeepSeek, Red Team Engineer, Bug Hunter·Open, Maintainability Critic, History Critic and Disprover·Open run in OpenCode on **Ollama Cloud** models
through the local Ollama daemon (`ollama signin` once per machine; provider config in
`dotfiles/dot_config/opencode/opencode.jsonc`). They draw on the Ollama Pro plan's $60/month
credits, not on Claude or Codex quota. When Ollama is unavailable, Critic·Sol (GPT-6.1-Sol) takes over their Review-team roles; see the fallback and its known limitation under "How work flows".

## Credentials

- **GitHub:** agents use **your `gh` login** (`~/.config/gh/hosts.yml`) — nothing to configure.
  Consequence: GitHub sees agents as you. The `main` ruleset blocks direct pushes, but an agent
  could still merge a PR into `main`; that is prevented only by the agents' instructions. The
  `paperclip/approval` check on the milestone branch is set by the Principal with the same login.
  A least-privilege token or a bot identity is a later step (not used now); such a token would
  need Contents, Pull requests and **Commit statuses** read/write.
- **Notion:** connect it once in Paperclip (Tools → App gallery → Notion). `configure.sh` then
  removes the gallery's all-agents profile and binds its own: **Notion · Design** (read, create and
  update pages, comments) → Principal Architect; **Notion · Records** (read, create and update
  pages) → Mentor, Teacher; **Notion · Read** → Research Scout. Every other agent gets no Notion
  tools, and no agent gets delete, move, schema, calendar or session tools.

## Starting work on a repo

1. `bash paperclip/setup-repo.sh <owner/repo> <milestone-branch> <local-path>` — rebase-only
   merges, the `main` ruleset, the milestone branch, and its `paperclip/approval` check. Add any
   `.gitignore` entries it reports (`.paperclip/`, `.claude/`).
2. Paperclip → Project → New: workspace = the local repo path (Linux filesystem), execution
   workspaces **isolated**, strategy **git worktree**, base ref = the milestone branch.

## Working with the team

- **Start work** with a task in the project, assigned to the Principal Architect (or Agent Chat
  with it). Describe the problem in your own words.
- **Your Inbox is what waits for you:** every question, confirmation and approval arrives there
  as a card. Issue status says what the agents are doing: `in_progress` working, `in_review` an
  agent is reviewing, `blocked` waiting on another issue or on you.
- **Questions** arrive as one card with all of them; answer them together and add anything else.
- **Gates 1 and 2** are cards in the Keystone task; the milestone row in Notion is the record.
  **Gate 3** is the milestone PR on GitHub
  (`m0 → main`), the only PR you merge. Task PRs are drafts the Principal merges.
- **Don't comment on an issue while its agent is running** — Paperclip cancels and restarts the
  run. Wait for its end-of-run comment.
- Agents use your `gh` login; their commits show the agent's name as author with your email (so they count on your contribution graph) and end with `Co-Authored-By: <agent> <marioppavlov@gmail.com>`.

## Calling the Teacher

- **Learning a topic:** in any Claude Code session, say "teach me …" — the `teacher` skill runs
  live and records to Notion.
- **Understanding a proposal:** on the issue, create a child issue "Help me understand: …"
  assigned to Teacher (@-mentions wake the assignee, not the mentioned agent). The Principal or
  Claude (the paperclip skill) may offer one when you struggle to follow; they wait for your yes,
  and the issue records who opened it and quotes the trigger.

## Watching quota

Subscription runs cost 0 cents in Paperclip, so money budgets never stop an agent. Watch the real
windows with `paperclipai cost quota-windows -C <company-id>` (Claude 5-hour and weekly, Codex
5-hour) and pause agents in the UI when Claude runs hot.
