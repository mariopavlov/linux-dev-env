# Paperclip Agent Team on Fedora WSL — Design

**Date:** 2026-10-18 · **Status:** approved 2026-10-18 · **Author:** Mario + Claude (brainstorm)

## 1. Intent

Mario is a solutions architect. Today he drives every agent session by hand (Superpowers in
Claude Code), which makes him the bottleneck in the middle of every piece of work. He wants a
standing **team of AI agents** that takes approved requirements and delivers a good product
without him, while he keeps control of the two ends:

- **Front gate — requirements.** Nothing gets built until Mario approves what and why.
- **Back gate — final review.** Depending on the work: a live demo, runbooks for a client, and
  the merge to `main`.

Because Mario steps out of the middle, quality has to come from **review depth**: a bench of
domain specialists that review each other's work. This is a permanent working setup for all of
his work (personal and, later, client), not a one-off experiment.

Alongside the team he wants a **Teacher**: an agent he calls directly to learn a topic or to
understand something the team proposed. Previous attempts at teaching agents failed in specific
ways (see §7), and fixing those is the point.

The platform is **Paperclip** (`github.com/paperclipai/paperclip`, MIT, latest v2026.1012.0), run
on Mario's **Fedora WSL2** machine, reached from a Windows browser, using his existing **Claude**
and **ChatGPT/Codex subscriptions** (no API keys).

## 2. Goals, non-goals, anti-goals

**Goals**
- Paperclip installed on Fedora WSL, running persistently, reachable from Windows at `http://localhost:3100`.
- A Paperclip company with the roles in §5, using Claude Code and Codex on subscription logins.
- Every Codex-produced artifact is reviewed by at least one Claude agent before it reaches Mario.
- Mario's only mandatory touchpoints: approving requirements/strategy, approving decisions that
  change the design, merging to `main`, and the final demo/runbook review.
- A Teacher Mario can invoke at any time that teaches like a real mentor (§7).
- First workload: **Perigee** (personal project). First checkpoint: **Perigee M0** merged (§9).

**Non-goals (for now)**
- Client work (WKL) on this team. WKL stays hand-driven until the setup is proven.
- Cloud credentials for any agent. Nothing deploys during the pilot.
- Notifications (Slack/Discord). Mario polls the Approvals and Blocked inboxes.
- Quota optimisation (e.g. shifting more work to Codex). Measure first, optimise later.
- Exposing Paperclip beyond localhost.

**Anti-goals — failure even if it technically works**
- Mario is still pulled into routine back-and-forth mid-flight.
- Codex output reaches Mario (or `main`) without a Claude review.
- Any agent can push to or merge into `main`.
- A Teacher that assumes mastery after one answer, asks vague questions, or starts a plan in the
  middle of a topic.
- Quota burns out so fast that the team stalls for most of the week.
- Decisions made by agents that never land in the repo decision log.

## 3. Constraints

- **Host:** Fedora on WSL2 (`setup-fedora-wsl/`). Repos live on the Linux filesystem under
  `~/workspace/<host>/<path>` (ghq layout), never on `/mnt/c` (Paperclip issue #1684).
- **Runtime:** Node.js ≥ 24.11 (Paperclip's engines field). Node is managed by mise in this repo
  (`dotfiles/dot_config/mise/config.toml`); make sure the pinned version satisfies this.
  Paperclip ships embedded Postgres; no Docker needed.
- **Subscriptions only:** Claude Code uses Mario's Claude subscription login; Codex uses his
  ChatGPT login (`~/.codex/auth.json`, which Paperclip symlinks per agent). Codex is the more
  generous plan; Claude quota is the scarcer resource.
- **WSL DNS:** Paperclip issue #7373 reports WSL2 DNS failing under load and breaking
  `claude_local` runs; apply the fallback-nameserver fix if seen.
- **No secrets in this repo** (existing rule): tokens go through 1Password / `op run` or
  Paperclip company secrets.
- **Paperclip limits to design around:** one approval per review stage; no outbound webhooks;
  CEO is the mandatory org-chart root; Claude Code plugins/MCP are not configurable per agent
  through Paperclip (use a per-agent `cwd` with its own config); Codex MCP setup is undocumented;
  permission bypass defaults to on for both adapters.

## 4. Decisions made in the brainstorm

Mario's decisions:

1. **Platform:** Paperclip, on Fedora WSL, UI accessed from Windows.
2. **Mario's role:** owns requirements and final review (demo, runbooks); wants out of the middle.
3. **Specialist bench** per solutions-architecture domain, strong enough that review replaces him.
4. **Developers are Codex only**, using Superpowers.
5. **Runtime split:** Claude for judgment/coordination/review roles, Codex for production roles.
   Cloud skills (Azure/AWS) sit on a Claude agent.
6. **Rule: every Codex output gets at least one Claude reviewer.**
7. **Security is a pair:** one Codex, one Claude.
8. **Teacher:** invoked directly by Mario, both from inside work items and standalone (§7).
9. **Pilot on Perigee**, not WKL. First checkpoint is Perigee M0; the setup continues afterwards.
10. **Perigee must become cloud native** (Mario will scale and deploy it later). The approved spec
    and M0 plan must be reviewed and adapted before M0 is built — this is the team's first job.
11. **Git:** agents commit and push on task branches; **only Mario merges to `main`**.
12. **Beads is scrapped** in Perigee; Paperclip issues track all agent work.
13. **Knowledge:** the repo is the source of truth (D-numbered decision log); one agent — the
    CEO/Principal Architect — syncs approved decisions to Notion.

Claude's calls (Mario can override):

- **CEO = Principal Solutions Architect.** (Originally with a separate Delivery Lead; removed in
  flow v2 at Mario's request — the Principal plans and delivers.)
- **Teacher on Claude**, because teaching quality matters most and it runs rarely.
- **Quota fit for Claude Max 5x ($100) + Codex $100 (Mario's plans).** Keep the roster, but Claude
  review roles have no timer heartbeats (they wake only on assignment/review), Claude agents run
  at most one or two at a time, and each Claude agent gets a Paperclip budget. Mario's own
  hand-driven work shares the same Claude quota. If the pilot shows Claude stalling, merge QA +
  DDD Reviewer first.
- **Teacher writes to Notion learning databases** (Study Assignments, Knowledge Checks) directly —
  the one exception to "only the CEO touches Notion".
- **Paperclip runs in `local_trusted` mode** (loopback only, no login), as a systemd **user**
  service in Fedora, telemetry off.
- **`main` gate: enforced by GitHub *and* by agent instructions (Mario's decision).** Perigee
  is back at `mariopavlov/perigee` (private); Mario is buying GitHub Pro so private-repo rulesets
  are enforced. Ruleset on `main`: require a pull request, block direct pushes, force-pushes and
  deletion. Limit: agents act through a token in Mario's name, so GitHub cannot tell an agent's
  merge from Mario's — the ruleset stops direct pushes to `main`, and **merging stays forbidden
  by agent instructions** (and by not giving agents a merge workflow). A bot identity for agents
  would close this gap; deferred until client work.
- **Permission bypass accepted** inside per-agent worktrees for Perigee, because no agent holds
  cloud credentials. Revisit before any agent gets credentials.
- **Milestone integration branch.** Task branches merge into a per-milestone integration branch
  (e.g. `m0`) once the Principal Architect approves; Mario merges the integration branch to `main` at
  the back gate. This keeps Mario out of per-task merges and lets dependent tasks build on each
  other's approved work.
- **Review trail on GitHub (Mario's request, added during planning).** Each task branch reaches
  `m0` through its own PR. Reviewers mirror their findings onto that PR, tagged with their role;
  every fix is its own commit with a `Review-Finding:` trailer; nothing is squashed. The `m0 → main`
  PR carries a digest of all findings and fixes, so Mario sees what was found and fixed at the
  final review.
- **Clean code (Mario's decision, added during planning).** Code must be minimal and readable:
  no code comments, no complex or speculative abstractions. All agents follow it, and a
  Refactorer (Codex, reviewed by the Claude reviewers after it) cleans each task once its tests
  are green, without touching tests.
- **Scope split (Mario).** `linux-dev-env` sets up the machine and the team only. Perigee work —
  including its repo cleanup — is done by the team inside Paperclip.
- **Mid-flight design decisions block only their own issue.** The CEO judges whether a decision
  changes the design (anything that contradicts or extends the approved spec or a D-decision) or
  is an implementation detail. Implementation details: CEO approves, work continues. Design
  changes: the issue goes to a board approval for Mario and stays blocked; other work continues.
- **If Superpowers can't run under Codex in Paperclip, developers stay Codex** and the TDD /
  worktree discipline is written into their instructions instead. The spike is not a go/no-go
  gate for the whole setup.

## 5. The team

*Revised 2026-10-18 (flow v2, Mario): the Delivery Lead is removed; the Principal Architect
brainstorms with Mario, plans and delivers; specialists review specs, not code.*

| Role | Runtime | Responsibilities |
|---|---|---|
| **CEO / Principal Solutions Architect** | Claude | Brainstorms with Mario in Agent Chat; writes spec, D-decisions and plan; sizes the change and picks spec reviewers; submits the reviewed spec for Mario's approval with his open questions; creates build issues for developers; decides on QA outcomes; opens the milestone PR; syncs approved decisions to Notion |
| **Developers** (2) | Codex + Superpowers | Implement plan tasks on isolated worktree branches, TDD |
| **Platform/DevOps Engineer** | Codex + Superpowers, Terraform | Containers, IaC, CI/CD, observability scaffolding |
| **Refactorer** | Codex | After a task is implemented: removes code comments, dead code and needless abstractions; behaviour unchanged; **never touches tests** |
| **QA Engineer** | Claude | Reviews the refactored code against spec, plan and implementation; reports PASS/FAIL with findings — the Principal decides what happens next. QA is the Claude review of all Codex output |
| **Cloud Architect** | Claude + Azure/AWS/Terraform skills (8) | Reviews specs and plans for cloud-native fit; reviews code only when the Principal asks |
| **Security Engineer #1 / #2** | Codex / Claude | Independent threat models of specs and plans; code only when the Principal asks |
| **Data/Domain (DDD) Reviewer** | Claude | Reviews specs and plans for bounded contexts, aggregates, ubiquitous language; code only when the Principal asks |
| **Teacher** | Claude | See §7. Invoked by Mario only |

Skills reach agents only as Paperclip skill sources (plugins do not load inside issue worktrees —
`paperclip/FINDINGS.md` §2).

## 6. How work flows

```
Gate 1  Mario ⇄ Principal Architect in Agent Chat: brainstorm → spec + plan (+ D-decisions)
        Principal sizes the change:
          small    — one component, no design change, no new dependency → no spec review
          standard — anything else → spec + plan reviewed by only the specialists it needs
                     (Cloud Architect / DDD Reviewer / Security pair)
Gate 2  Board approval (Mario): reviewed spec + plan + review summary + questions only Mario
        can answer. Mario answers in the approval thread; "request revision" loops back.
        Nothing is built before this approval.
Build   per plan task: Codex Developer / Platform Engineer → Refactorer (same branch, tests
        untouched) → QA (on the refactored code; PASS/FAIL vs spec, plan, implementation)
        → Principal decides: accept and merge into the milestone branch / send fixes to the
        developer / ask a specialist to review the code
        Mid-build questions for Mario → issue blocked → Blocked inbox
Gate 3  Milestone PR (m0 → main) with demo checklist, runbooks, review digest → Mario merges
```

- Paperclip mechanics per build issue: execution policy `review` Refactorer → `review` QA →
  `approval` Principal Architect. QA never requests changes itself; it records PASS/FAIL so the
  Principal decides.
- Review trail on GitHub is unchanged: findings tagged with the reviewer's role, one
  `fix(review):` commit per finding with a `Review-Finding:` trailer, digest in the milestone PR.

## 7. The Teacher

**Build (Mario's decision): live chat + Paperclip.** Full lessons happen live in a Claude Code
session (the Teacher as a skill/agent Mario runs directly). A thin Paperclip Teacher agent handles
in-context "explain this issue" requests. Both share the same instructions and the same Notion
learning memory.

**Two ways Mario calls it:**
1. **In context** — on a Paperclip issue (a proposal, design, review comment) Mario doesn't fully
   understand: @-mention the Teacher or assign it a "help me understand" sub-issue. It reads the
   issue and its links and teaches just enough for Mario to judge the proposal. (Whether an
   @-mention alone wakes an agent is contradicted in Paperclip's docs — verify; fall back to
   assignment.)
2. **Standalone (live Claude Code session)** — "teach me this domain/technology" (e.g. a client's business domain being
   modelled, Keycloak, OIDC). Runs the full mentor loop below.

**What makes it a teacher (the bar previous attempts failed):**
- **Diagnose before planning.** Several concrete probes of rising difficulty before any plan;
  "I don't know" is data, not something to skip past. Never conclude mastery from one answer.
- **Map prerequisites and start at the first gap**, even two levels below the topic asked for.
  Show Mario the map.
- **Specific, not vague.** Questions name concrete scenarios and expect concrete answers.
- **Personal.** Examples and assignments come from Mario's real work (the issue at hand, Perigee,
  past client work), not textbook cases.
- **Progress is earned** through Recall → Explain → Apply (Mario's existing ladder). Move on only
  when he can explain and apply.
- **Real assignments and homework**, then tests; follow up on gaps with targeted study.
- **Remembers.** Writes Study Assignments and Knowledge Checks to the Notion learning databases
  and reads them back to resume where Mario left off.

## 8. Installation and access

- Install Paperclip in Fedora WSL as part of this repo's `setup-fedora-wsl` flow (fits the
  `--agents` step); Claude Code and Codex CLIs are already installed there.
- Mode `local_trusted`, bind loopback, port 3100. Windows reaches it via WSL localhost
  forwarding (or `networkingMode=mirrored`). Verify from a Windows browser.
- Run as a systemd user service (WSL systemd must be enabled) so it survives terminal exits.
- `PAPERCLIP_TELEMETRY_DISABLED=1`.
- Data lives in `~/.paperclip/instances/default/`; include it in whatever backup Mario uses.

## 9. First job: Perigee

Current state: spec approved (`docs/superpowers/specs/2026-10-08-perigee-mvp-design.md`),
decisions D1–D24 (`docs/design/brainstorm-log.md`), M0 plan written but not approved, no product
code. Stack: Go (DDD + hexagonal), React/TS.

1. **Repo prep:** remove Beads (`.beads/`, the `bd prime` SessionStart hook in `.claude/settings.json`,
   Codex/Cursor integrations, BEGIN/END BEADS blocks in AGENTS.md/CLAUDE.md, README section).
   Rewrite the Git Policy in AGENTS.md: agents commit/push on task branches, Mario alone merges
   `main`. Enable branch protection.
2. **Cloud-native review:** Mario gives the CEO the requirement — *Perigee must be cloud native,
   scalable and deployable later; target cloud open.* Specialists review the spec and M0 plan in
   their domains; the CEO proposes changes as D25+; Mario approves; the M0 plan is revised.
3. **Build M0** through the full flow in §6.
4. **Checkpoint:** M0 merged by Mario. Review what worked, quota burn per role (Claude especially),
   review quality, and how often Mario was pulled mid-flight. Then adjust roles and continue.

## 10. Left to the builder

- Company/agent definitions: where they live (suggest a separate repo exported/imported with
  Paperclip's markdown company packages so the team is reproducible), and each agent's
  instructions file.
- How the multi-specialist review is wired (chained stages vs. Lead-consolidated).
- Heartbeat schedules vs. event-only wakes per role, and per-agent budgets.
- Which concrete skills each agent gets, within §5.
- How the Teacher's Notion access is configured.

## 11. Risks to verify early

- Claude Code plugins + MCP on a Paperclip-spawned Claude agent (Cloud Architect).
- Superpowers working under Codex in Paperclip (skills via symlink).
- @-mention wake behaviour (Teacher in-context mode).
- Claude subscription quota under ~7 Claude agents.
- WSL DNS under parallel runs (#7373).
- Codex sandbox config can't be saved (#16224) — acceptable now, blocking before credentials.

## 11a. Flow v2 decisions (Mario, 2026-10-18)

Made after the first smoke run spent ~3.5M tokens and 14 % of Claude's 5-hour window on the
design review of a `/health` endpoint:

1. Brainstorm happens between Mario and the Principal Architect (Paperclip Agent Chat), not inside
   the Principal alone.
2. The Principal writes the plan and runs the implementation agents; no Delivery Lead.
3. Specialist reviews run on the spec and plan, not on the implementation.
4. After implementation: Refactorer (tests untouched), then QA on the refactored code against
   spec, plan and implementation; the Principal decides whether specialists review the code.
5. A spec-approval gate brings the specialists' open questions to Mario before anything is built.
6. The Principal sizes each change; small changes skip spec review.
7. The Cloud Architect carries 8 skills instead of 22.

## 11b. Smoke-test fixes (Mario, 2026-10-18)

- Issue status means one thing everywhere: `in_progress` working, `in_review` awaiting an agent's
  review, `blocked` awaiting Mario.
- The Principal asks all its questions in one card; Mario answers them together.
- Task PRs are drafts; the milestone branch requires the `paperclip/approval` status, set only by
  the Principal. Required approvals on `main` stay 0 — Mario reviews and merges milestone PRs.
- No bot identity. Agent commits keep Mario's email (contribution graph) with the agent's name as
  author and a `Co-Authored-By: <agent> <marioppavlov@gmail.com>` trailer.
- Build issues always get an isolated workspace; agents use `gh`, never Paperclip's GitHub
  connector.
- No Product Owner agent for now: Mario owns what and why; revisit with a multi-project backlog.

## 11c. Notion as the design home (Mario, 2026-10-18)

- Notion holds the design and the record; Keystone runs the sub-tasks; Todoist holds only Mario's
  real actions. No two-way sync of tasks.
- Milestones live in one shared Notion database, 🏁 Milestones (1 - PROJECTS), related to
  Projects. Each row's page is the milestone's Design page: Brief (Mario), Questions & answers,
  Decisions, Spec, Plan, Progress log. Its `Status` (Planned → Brief ready → Agent's turn ⇄ Your
  turn → Building → Done) and `Last update` are kept by the Principal. The Design page and the
  project's decision and term databases are the source of truth; the repo gets read-only copies
  of the approved spec and plan.
- Hand-over is manual and simple: the agent finishes reading and writing, comments the Notion
  link and sets the issue `blocked`; Mario answers in Notion and comments "done" (or "approved"
  at Gate 2) on the issue, which wakes the agent. No timers, no email.
- New agent: **Mentor** (Claude Opus, high). Goal: Mario's mastery (Robert Greene). After spec
  approval and after the milestone it finds weak points in his answers, creates or extends Study
  Assignments (Proposed, at most 2 per sync), keeps a Mastery section (weak points, owned, concepts
  exercised, stage per Topic with one next stretch) and, at finish, proposes Practice Library
  cards and Building Blocks.
- Notion tools per agent through Paperclip tool profiles: Design (Principal), Records (Mentor,
  Teacher), Read (Research Scout); none for the rest; no delete, move, schema, calendar or session
  tools for anyone.

## 11d. Keystone-first milestones (Mario, 2026-10-18, supersedes the Q&A parts of 11c)

- A milestone starts as a rough 🏁 Milestones row: Mario adds it (`Idea`), the Principal creates
  it after a Keystone chat agrees on it (`Idea`), or the Principal suggests a missing one
  (`Proposed`; only Mario accepts or drops it).
- Mario starts the work with a Keystone task to pick up the milestone and clean up the
  requirements. Brainstorm (one question card), spec reviews and Gate 2 (a confirmation card)
  happen in Keystone, as in §11a.
- After Gate 2 the Principal updates the row as the reference record: final title, summary and
  done-when; page body = requirements, decisions (recorded in the project's decision log and
  ADRs), tasks, links, progress log. The spec and plan live in the repo.
- Row statuses: Proposed → Idea → Designing → Building → In review → Done, or Dropped. The Mentor
  reads Mario's answers from the Keystone thread.

## 11e. Question routing, timeouts and Codex cost (Mario, 2026-10-19)

- Only the Principal, Mentor and Teacher create cards for Mario. Any other agent that needs a
  decision opens a `Question:` child issue assigned to the Principal and blocks on it. The
  Principal answers implementation details, asks a specialist for security calls, and escalates
  only Mario's decisions as `Decision for Mario: …` under the milestone issue.
- Runs time out (45 min; 90 for the Principal and the Mentor); the Coordinator sweeps hourly for
  stuck and hung work.
- Codex agents run in `agent-full-access` (no guardian reviewer); the Refactorer and
  Security·Codex run one-shot sessions.

## 12. Open

- **GitHub Pro purchase**, then create and verify the `main` ruleset (`gh api repos/mariopavlov/perigee/rulesets`).
