# Paperclip Agent Team Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Paperclip running persistently on Fedora WSL and reachable from Windows, hosting a reproducible agent company (§5 of the spec) plus a live Teacher skill, smoke-tested end to end and handed the Perigee cloud-native review as its first job.

**Architecture:** Paperclip is pinned in the shared mise manifest and installed/started by a new `--paperclip` step in `setup-fedora-wsl` as a systemd user service (loopback, `local_trusted`, telemetry off). The company is defined as a Paperclip markdown company package versioned in this repo under `paperclip/company/` and imported with the Paperclip CLI. The Teacher is a Claude Code skill in `claude-skills/` (live lessons) that the thin Paperclip Teacher agent also loads.

**Tech Stack:** Bash (existing setup scripts + mock-based tests), mise (`npm:` backend), systemd user units, Paperclip `paperclipai@2026.1012.0` (Node ≥ 24.11, embedded Postgres), Claude Code + Codex CLIs on subscription logins, GitHub (`gh`), Notion MCP.

**Spec:** `docs/superpowers/specs/2026-10-18-paperclip-agent-team-design.md`

## Global Constraints

- Paperclip version pinned: `paperclipai` `2026.1012.0`. Node from mise `lts` (currently 24.22.0, satisfies `>=24.11.0`).
- Deployment mode `local_trusted`, bind loopback, port `3100`. Never `--bind lan`/`tailnet`.
- `PAPERCLIP_TELEMETRY_DISABLED=1` in every way Paperclip is started.
- Subscription logins only: no `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` set for agents.
- Repos on the Linux filesystem (`~/workspace/...`), never `/mnt/c`.
- No secrets committed. The agents' GitHub token lives only as a Paperclip company secret `GITHUB_TOKEN`.
- Every Codex-produced artifact gets at least one Claude reviewer before Mario.
- Only Mario merges to Perigee `main` (ruleset 25333874 enforces PR-only, rebase-only, no force push, no deletion; agent instructions forbid merging to `main`).
- Task branches merge into a per-milestone integration branch (`m0`) after the Delivery Lead approves — **through a GitHub PR per task** (task branch → `m0`), so review history lives on GitHub.
- **Review trail visible to Mario on GitHub:** every reviewer's finding is posted on the task PR prefixed with its role (e.g. `[QA]`, `[DDD Reviewer]`, `[Security·Codex]`), because all agents share Mario's GitHub identity; each fix is a separate commit with a `Review-Finding:` trailer naming the reviewer and finding; nothing is squashed (rebase-only keeps fix commits on `m0` and `main`); the `m0 → main` PR description carries a review digest linking every task PR.
- Runtime split: Claude = CEO/Principal Architect, Delivery Lead, Cloud Architect, QA, DDD Reviewer, Security #2, Teacher. Codex = Developers ×2, Platform/DevOps, Security #1.
- Claude review roles: no timer heartbeats; per-agent budgets set. No agent gets cloud credentials.
- Existing repo style: scripts `set -euo pipefail`, source `lib/utils.sh`, use `log_*` helpers, idempotent with `log_skip`.

## Review Focus

1. **WSL restart (`wsl --shutdown`, Windows reboot)** — Paperclip must come back without Mario opening a terminal. Needs user lingering; Task 1 asserts `loginctl enable-linger` is called, Task 2 verifies after a real `wsl --shutdown`.
2. **Codex not logged in** (`~/.codex/auth.json` missing — true on this machine today) — Codex agents would fail every run. Task 1 warns when `codex login status` reports not logged in; Task 2 logs in and verifies.
3. **An agent trying to push to or merge `main`** — expected: GitHub rejects the push. Task 10 runs a deliberate push to `main` with the agents' token and expects rejection.
4. **Claude quota exhausted mid-run** — expected: the agent waits/pauses, the issue is not marked done or failed. Task 10 records what Paperclip does when a budget cap is hit (cap one agent low on purpose).
5. **Port 3100 already taken or server crashed** — Windows sees nothing. Task 1's unit uses `Restart=on-failure`; Task 2 checks from the Windows side with `curl.exe`.

---

## File structure

| Path | Responsibility |
|---|---|
| `dotfiles/dot_config/mise/config.toml` | Pin `npm:paperclipai` |
| `setup-fedora-wsl/packages/paperclip.sh` | Install check, onboard, write + enable systemd user unit, linger, Codex login warning |
| `setup-fedora-wsl/systemd/paperclip.service` | The user unit (template copied by `paperclip.sh`) |
| `setup-fedora-wsl/tests/paperclip_test.sh` | Mock-based test for `paperclip.sh` (style of `agents_test.sh`) |
| `setup-fedora-wsl/install.sh` | New `--paperclip` step, in `--all` after `--agents` |
| `setup-fedora-wsl/README.md` | Paperclip section: first-time logins, Windows access, DNS fix, troubleshooting |
| `paperclip/FINDINGS.md` | Spike results that decide per-agent config (Task 3) |
| `paperclip/company/` | Company package: company file, one folder per agent, shared rules |
| `paperclip/company/shared/team-rules.md` | Rules every agent's instructions include |
| `paperclip/README.md` | How to import/re-import the company, configure secrets, operate the gates |
| `claude-skills/dot-claude/skills/teacher/SKILL.md` | Live Teacher skill (symlinked to `~/.claude/skills` by `--claude`) |
| Perigee repo: `AGENTS.md`, `CLAUDE.md`, `README.md`, `.claude/settings.json`, `.beads/`, `.codex/`, `.cursor/`, `docs/design/session-state.md` | Beads removal, new git policy (Task 11) |

---

### Task 1: Install Paperclip as a pinned tool and a persistent user service

**Files:**
- Modify: `dotfiles/dot_config/mise/config.toml` (Agent tooling section)
- Create: `setup-fedora-wsl/packages/paperclip.sh`
- Create: `setup-fedora-wsl/systemd/paperclip.service`
- Create: `setup-fedora-wsl/tests/paperclip_test.sh`
- Modify: `setup-fedora-wsl/install.sh` (usage, arg parsing, `--all`, step, summary)

**Interfaces:**
- Produces: `bash install.sh --paperclip`; unit `paperclip.service` in `~/.config/systemd/user/`; Paperclip at `http://localhost:3100`; data in `~/.paperclip/instances/default/`.

- [ ] **Step 1: Pin Paperclip in mise.** Under `# ── Agent tooling`, add with a comment in the file's style (what it provides, why pinned):
  `"npm:paperclipai" = "2026.1012.0"` — provides `paperclipai`. Pinned, not `latest`: weekly releases, experimental features without compatibility guarantees.

- [ ] **Step 2: Confirm the real CLI surface before writing the unit.**
  Run: `mise install npm:paperclipai@2026.1012.0 && mise exec npm:paperclipai@2026.1012.0 -- paperclipai --help`
  Expected: subcommands include `onboard` and a server-start command. Record the exact start command (expected `paperclipai run`) and the non-interactive onboard flags (expected `onboard --yes`) — use them verbatim below and in the test.

- [ ] **Step 3: Write the failing test `tests/paperclip_test.sh`.** Same harness as `agents_test.sh`: temp `HOME`, mock bin dir first on `PATH`. Mocks: `paperclipai` (records args to `$HOME/.cache/pc-test/paperclipai.log`), `systemctl` (records args), `loginctl` (records args), `codex` (`login status` prints `Not logged in` unless `CODEX_LOGGED_IN=1`). Assertions:
  - `~/.config/systemd/user/paperclip.service` exists and contains `Environment=PAPERCLIP_TELEMETRY_DISABLED=1`, `Restart=on-failure`, and the start command from Step 2.
  - systemctl log contains `--user daemon-reload` and `--user enable --now paperclip.service`.
  - loginctl log contains `enable-linger`.
  - With `CODEX_LOGGED_IN` unset, stdout contains `codex login`; with `CODEX_LOGGED_IN=1` it does not.
  - Running `paperclip.sh` a second time does not call `paperclipai onboard` again when `~/.paperclip/instances/default` exists (idempotence).
  - `bash install.sh --paperclip` runs the same script (assert via the systemctl log).
  - Last line: `paperclip_test.sh: PASS`.

- [ ] **Step 4: Run it to see it fail.**
  Run: `bash setup-fedora-wsl/tests/paperclip_test.sh`
  Expected: FAIL — `packages/paperclip.sh` not found.

- [ ] **Step 5: Write `systemd/paperclip.service`.** `[Unit] Description=Paperclip agent orchestration (local_trusted, loopback)`; `[Service]` `ExecStart=%h/.local/share/mise/shims/paperclipai <start command>`, `Environment=PAPERCLIP_TELEMETRY_DISABLED=1`, `Environment=PATH=%h/.local/bin:%h/.local/share/mise/shims:/usr/bin:/bin` (so spawned `claude`/`codex` resolve), `Restart=on-failure`, `RestartSec=5`; `[Install] WantedBy=default.target`.

- [ ] **Step 6: Write `packages/paperclip.sh`.** Structure like `agents.sh`. Steps, each with `log_step`: ensure `paperclipai` on PATH via mise shims (error with "run --mise" otherwise); onboard once if `~/.paperclip/instances/default` is absent (`PAPERCLIP_TELEMETRY_DISABLED=1 paperclipai onboard --yes`); install unit with `install -m 0644`; `systemctl --user daemon-reload`; `systemctl --user enable --now paperclip.service`; `loginctl enable-linger "$USER"`; Codex check — if `codex login status` doesn't report logged in, `log_warn "Codex is not logged in — run 'codex login' (ChatGPT account) before starting Codex agents"`; finish with `log_info "Paperclip UI: http://localhost:3100 (also from Windows)"`.

- [ ] **Step 7: Wire into `install.sh`.** Add `--paperclip` to usage ("Paperclip agent orchestration as a systemd user service"), `RUN_PAPERCLIP` flag, include in `--all` after `--agents` (update the `--all` description), `run_step "Paperclip" bash "$SCRIPT_DIR/packages/paperclip.sh"`, and a summary line pointing at `http://localhost:3100`. `--update` needs nothing new (mise up covers the pin) — add a `log_info` that bumping Paperclip means editing the pin.

- [ ] **Step 8: Run both tests.**
  Run: `bash setup-fedora-wsl/tests/paperclip_test.sh && bash setup-fedora-wsl/tests/agents_test.sh`
  Expected: `paperclip_test.sh: PASS` and `agents_test.sh: PASS`.

- [ ] **Step 9: Commit.**
  `git add dotfiles/dot_config/mise/config.toml setup-fedora-wsl && git commit -m "setup-fedora-wsl: install Paperclip as a systemd user service"`

### Task 2: Bring Paperclip up on this machine and reach it from Windows

**Files:**
- Modify: `setup-fedora-wsl/README.md` (new "Paperclip" section)

**Interfaces:**
- Consumes: `install.sh --paperclip` (Task 1).
- Produces: a running, logged-in host; README runbook used by Tasks 9–12.

- [ ] **Step 1: Log in the provider CLIs (Mario, interactive).** `codex login` (ChatGPT account). Confirm Claude: `claude` then `/status` shows the Max subscription. Do not set API-key env vars.
  Verify: `codex login status` → logged in; `ls ~/.codex/auth.json` exists.

- [ ] **Step 2: Run the step for real.**
  Run: `mise install && bash setup-fedora-wsl/install.sh --paperclip`
  Expected: `Paperclip done`; `systemctl --user is-active paperclip.service` → `active`; `curl -s -o /dev/null -w '%{http_code}' http://localhost:3100` → `200`.

- [ ] **Step 3: Verify from Windows.**
  Run: `/mnt/c/Windows/System32/curl.exe -s -o NUL -w "%{http_code}" http://localhost:3100`
  Expected: `200`. If not, set `[wsl2] localhostForwarding=true` (or `networkingMode=mirrored`) in `%UserProfile%\.wslconfig`, `wsl --shutdown`, retry. Mario also opens it in a Windows browser.

- [ ] **Step 4: Verify it survives a WSL restart (Review Focus 1).** Mario runs `wsl --shutdown` from Windows, waits 10 s, then runs the Step 3 command from PowerShell (`curl.exe ...`) *before* opening a Fedora terminal.
  Expected: `200` (may need ~30 s for WSL to boot on first request; WSL boots on the next `wsl` invocation — if it doesn't start without one, document `wsl -d FedoraLinux-42 --exec true` as a Windows logon task in the README).

- [ ] **Step 5: Verify telemetry is off and mode is local_trusted.** Check Paperclip's settings/health page or `paperclipai --help` equivalent (`doctor`/`status`) for deployment mode `local_trusted` and telemetry disabled; check `ss -ltnp | grep 3100` shows `127.0.0.1` (or `::1`) only.

- [ ] **Step 6: Write the README section.** First-time logins, `--paperclip`, Windows access + `.wslconfig` fallback, restart behaviour, WSL DNS fix for Paperclip issue #7373 (`/etc/wsl.conf` `[network] generateResolvConf=false` + static `/etc/resolv.conf` with a fallback nameserver — apply only if `claude_local` runs fail with DNS errors), data location `~/.paperclip/instances/default/` for backups.

- [ ] **Step 7: Commit.** `git commit -am "setup-fedora-wsl: Paperclip runbook"`

### Task 3: Spike — settle the design's open risks

Throwaway: a scratch company and a local scratch repo (`~/workspace/scratch/paperclip-spike`, `git init`). Delete the scratch company at the end. Only `paperclip/FINDINGS.md` is kept.

**Files:**
- Create: `paperclip/FINDINGS.md`

**Interfaces:**
- Produces: decisions Tasks 5–9 follow — company package format, where per-agent plugins/MCP/skills are configured, how Codex gets Superpowers, wake-on-mention behaviour, review-stage wiring, available concurrency/budget controls.

Record each result in `FINDINGS.md` as **Question / What I did / Result / Decision**.

- [ ] **Step 1: Company package format.** `npx paperclipai test-drive` (or UI) to create a scratch company with a CEO; export it (`paperclipai company export` or UI). Record the exact file layout and the agent-file fields (adapter, model, cwd, instructions path, skills, heartbeat, budget).
- [ ] **Step 2: Claude agent loads plugins + Superpowers via its `cwd`.** Create a `claude_local` agent whose `cwd` is a dir with `.claude/settings.json` enabling `superpowers@claude-plugins-official` and `azure@claude-plugins-official`. Assign an issue: "List the skills and MCP servers you have; do nothing else." Result must name Superpowers skills and Azure tools. If not, try skills via Paperclip's skill attachment and MCP via a project `.mcp.json`; record what works.
- [ ] **Step 3: Codex agent runs Superpowers.** `codex_local` agent with Superpowers skills attached through Paperclip. Issue: "Which skills do you have? Use the brainstorming skill's first step on: add a /health endpoint." Pass = it names and follows Superpowers skills.
- [ ] **Step 4: Notion from a Claude agent.** Add the Notion MCP to the Claude agent's `cwd` `.mcp.json`; issue: "Fetch Notion page 3f334fd6f0938131abe4d325d80b6332 and print its title." Pass = title "Perigee". Record any interactive auth needed.
- [ ] **Step 5: Wake on @-mention.** Comment `@<agent>` on an issue assigned to someone else. Record whether the agent wakes. If not, the Teacher's in-context mode uses assignment of a sub-issue.
- [ ] **Step 6: Review stage routing.** On an issue executed by the Codex agent, set an execution policy with a review stage whose participant is the Claude agent, then an approval stage with Mario. Confirm the flow `in_progress → in_review (Claude) → changes requested → back to Codex → approved → Mario`. Record whether specialist comments + a single Lead approval is easier than chained stages; pick one for Task 9.
- [ ] **Step 7: Concurrency and budget controls.** Find whether Paperclip can cap concurrent runs (instance, company or adapter level). Set a tiny budget on one agent and confirm it auto-pauses. Record settings available.
- [ ] **Step 8: Worktree + branch push.** In the scratch repo (local path workspace, isolated execution workspace on), confirm a task gets its own worktree/branch and that a commit by the Codex agent appears on that branch.
- [ ] **Step 9: Clean up and commit.** Delete the scratch company. `git add paperclip/FINDINGS.md && git commit -m "paperclip: spike findings"`

**Gate:** if Step 2 fails in every variant, stop and tell Mario (Cloud Architect + plugins is a design assumption). Step 3 failing is not a stop (spec: developers stay Codex, discipline goes into instructions).

### Task 4: Teacher skill (live lessons)

Use **superpowers:writing-skills** — the skill is tested against baseline behaviour before and after.

**Files:**
- Create: `claude-skills/dot-claude/skills/teacher/SKILL.md`
- Create: `claude-skills/dot-claude/skills/teacher/notion.md` (Notion targets and record format)

**Interfaces:**
- Produces: skill `teacher` (description triggers on "teach me", "help me understand", "I don't get", "explain this proposal"); `notion.md` read by both the live skill and the Paperclip Teacher (Task 8).

- [ ] **Step 1: Baseline (RED).** Dispatch a fresh subagent without the skill: "Teach me Keycloak — I'll need it for SSO migration." Play the learner with two weak answers. Record failures against the spec's bar (§7): mastery assumed after one answer, vague questions, plan starting mid-topic, generic examples.
- [ ] **Step 2: Write `SKILL.md`.** Encode §7 as hard rules, each with what to do instead:
  - Diagnose first: at least 4 concrete probes of rising difficulty before any plan; one correct answer is never mastery; "I don't know" → probe one level lower.
  - Show a prerequisite map and start at the first gap.
  - Every question names a concrete scenario and asks for a concrete answer.
  - Examples from Mario's work (ask what he's working on; use the issue/repo in front of him).
  - Ladder Recall → Explain → Apply; advance only when Explain and Apply succeed.
  - Assignments/homework with a due check-in; tests that mix old and new material.
  - In-context mode: read the issue/proposal first, teach only what's needed to judge it, end by asking Mario to state his judgment of the proposal.
  - Persist and resume via `notion.md`.
- [ ] **Step 3: Write `notion.md`.** Study Assignments data source `collection://6c477727-ebf6-4e9b-bcad-1e04a3f189f5`, Knowledge Checks `collection://37f7136c-cebe-46b3-a5be-e14852d23e5c`. Fetch each schema first and record property names and allowed values used. At session start: query open assignments/checks for the topic; at end: write new ones and Grade every attempt (spec Perigee note: grades later import as FSRS reviews).
- [ ] **Step 4: Re-test (GREEN).** Same scenario as Step 1 with the skill loaded, plus two pressure tests: learner answers the first probe perfectly (skill must still probe further), learner says "just give me the plan" (skill keeps a short diagnostic). Pass = none of the Step 1 failures recur. Close loopholes found (REFACTOR) and re-run.
- [ ] **Step 5: Install and commit.** `bash setup-fedora-wsl/install.sh --claude`; confirm `~/.claude/skills/teacher/SKILL.md` resolves. `git add claude-skills/dot-claude/skills/teacher && git commit -m "claude-skills: teacher skill"`

### Task 5: Shared team rules and leadership agents

**Files (layout per FINDINGS Step 1; paths below assume one folder per agent):**
- Create: `paperclip/company/<company file>` — name "Mario Solutions Architecture", goal: deliver Mario's approved requirements as production-quality work with specialist review.
- Create: `paperclip/company/shared/team-rules.md`
- Create: `paperclip/company/agents/ceo-principal-architect/<agent file + instructions>`
- Create: `paperclip/company/agents/delivery-lead/<agent file + instructions>`

**Interfaces:**
- Produces: `team-rules.md` included by every agent; agent slugs used by Tasks 6–9: `ceo-principal-architect`, `delivery-lead`.

- [ ] **Step 1: Write `team-rules.md`.** Exactly these rules:
  - Git: commit and push only on your task branch; never push to, merge into, or open a merge into `main`; the executor opens a PR from the task branch into the milestone branch (`m0`) when the task first goes to review; the Delivery Lead rebase-merges it after approval; PRs to `main` are opened by the Delivery Lead for Mario and merged only by Mario; rebase, never merge commits, never squash.
  - Review trail on GitHub: reviewers post each finding on the task PR as a comment starting with their role tag (`[QA]`, `[DDD Reviewer]`, `[Cloud Architect]`, `[Security·Codex]`, `[Security·Claude]`, `[Delivery Lead]`) and a finding id (`QA-1`, `DDD-2`, …), and post their final verdict the same way. The same text goes in the Paperclip review comment.
  - Fixes: one commit per finding (or per closely related group), message `fix(review): <summary>` with trailer `Review-Finding: <finding id> (<role>)`; the executor replies on the PR to each finding with the fixing commit SHA.
  - Every Codex-produced change has a Claude reviewer before it moves on.
  - Decisions: write D-numbered decisions in the repo's decision log (`docs/design/brainstorm-log.md` for Perigee) with context, options, decision, consequences; flag the CEO. Design changes (contradict or extend the approved spec or a D-decision) block the issue and go to Mario via board approval; implementation details are CEO-approved.
  - Ask Mario only by setting the issue `blocked` with one specific question.
  - Every run ends with a comment: what was done, what's next, anything blocked.
  - No cloud credentials; never request them.
- [ ] **Step 2: CEO / Principal Solutions Architect.** Runtime per FINDINGS (`claude_local`), model Opus. Instructions: turn Mario's requirement into design + strategy; read the existing spec/decisions first; get specialist input by creating review sub-issues for Cloud Architect, DDD Reviewer, Security pair; submit strategy for board approval; owns the design-change vs implementation-detail call; after Mario approves decisions, sync them to Notion (Perigee Decisions data source `collection://8898ce19-e31c-422e-9e62-8d428d4ecf72`, area page `3f334fd6f0938131abe4d325d80b6332`). Notion MCP in its `cwd` per FINDINGS Step 4. Heartbeat: none (wakes on assignment/approval).
- [ ] **Step 3: Delivery Lead.** Runtime `claude_local` with Superpowers (writing-plans). Reports to CEO. Instructions: approved strategy → plan in repo (`docs/superpowers/plans/`) → Paperclip issues, one per plan task, with acceptance criteria and the reviewer chain from Task 9; assign Codex developers; collect specialist reviews and give the consolidated approval; rebase-merge approved task PRs into `m0`; open the `m0 → main` PR for Mario with a demo/runbook checklist and a **review digest**: per task — link to the task PR and Paperclip issue, each finding id with reviewer, outcome (fixed / won't fix + reason), and fixing commit SHA. Refuse to approve a task PR while any finding lacks a reply. Heartbeat: one daily check of stalled issues (only Claude agent with a timer).
- [ ] **Step 4: Validate the package parses.** Run the import dry-run/preview (`paperclipai company import` preview mode or UI preview, per FINDINGS). Expected: two agents listed with correct reports-to and adapters, no errors.
- [ ] **Step 5: Commit.** `git add paperclip/company && git commit -m "paperclip: team rules and leadership agents"`

### Task 6: Production and review agents

**Files:** one agent folder each under `paperclip/company/agents/`: `developer-1`, `developer-2`, `platform-devops`, `cloud-architect`, `security-codex`, `security-claude`, `ddd-reviewer`, `qa`.

**Interfaces:**
- Consumes: `team-rules.md`, `delivery-lead` slug (all report to it, except `cloud-architect` and the security pair which report to `ceo-principal-architect`).
- Produces: the slugs above for Task 9's review chain.

- [ ] **Step 1: Developers ×2** (`codex_local`, Superpowers if FINDINGS Step 3 passed, else instructions carry TDD + small commits + run tests before handing off). Implement only the assigned issue on its branch; red-green-refactor; hand off by marking done with test evidence in the comment.
- [ ] **Step 2: Platform/DevOps** (`codex_local`, Superpowers, HashiCorp Terraform skill). Containers, IaC, CI/CD, observability scaffolding; cloud-agnostic until a target cloud is decided; no `apply` against real clouds.
- [ ] **Step 3: Cloud Architect** (`claude_local`, `cwd` enabling Azure, AWS core, HashiCorp Terraform plugins + azure-well-architected skill, per FINDINGS Step 2). Reviews designs for cloud-native fit (12-factor, statelessness, config via env, health checks, horizontal scaling, managed-service options per cloud) and reviews all Platform/DevOps output.
- [ ] **Step 4: Security pair.** `security-codex` (`codex_local`) and `security-claude` (`claude_local`): threat model (STRIDE) for designs, code and IaC review, secrets handling, dependency risk. Each reviews the other's output; `security-claude` is the Claude reviewer for Codex security findings.
- [ ] **Step 5: DDD Reviewer** (`claude_local`). Reviews developer code against bounded contexts, aggregates, domain events and the ubiquitous language (`docs/design/ubiquitous-language.md` for Perigee); rejects leaks across contexts.
- [ ] **Step 6: QA** (`claude_local`, Superpowers verification skills). Tests against spec acceptance criteria, runs the suite, checks demo readiness and runbooks; rejects with a reproducible failing case.
- [ ] **Step 7: Budgets and heartbeats.** All Claude agents in this task: no timer heartbeat. Monthly budgets (cents) per FINDINGS Step 7 — starting point: Claude reviewers equal shares of a cap Mario sets; Codex agents uncapped by budget but paused when idle. Record the numbers in the agent files.
- [ ] **Step 8: Validate and commit.** Import preview shows 10 agents (2 from Task 5 + 8), correct reports-to tree. `git commit -am "paperclip: production and review agents"` (add new files first).

### Task 7: Paperclip Teacher agent (in-context mode)

**Files:**
- Create: `paperclip/company/agents/teacher/<agent file + instructions>`

**Interfaces:**
- Consumes: `claude-skills/dot-claude/skills/teacher/` (Task 4), FINDINGS Step 5 (wake mechanism).

- [ ] **Step 1: Write the agent.** `claude_local`, reports to CEO but takes work only from Mario. Skills: the `teacher` skill (attach the same directory — one source of truth). Instructions: in-context mode only (full lessons happen live in Claude Code); read the issue, its parent and linked docs; teach in comments; record to Notion per `notion.md`. Wake: per FINDINGS Step 5 (mention, or Mario assigns a "help me understand" sub-issue). No heartbeat.
- [ ] **Step 2: Validate and commit.** Import preview shows 11 agents. Commit.

### Task 8: Agents' GitHub token

- [ ] **Step 1 (Mario):** create a fine-grained PAT, resource owner `mariopavlov`, repository access only `mariopavlov/perigee` (plus the smoke repo from Task 10 if on GitHub), permissions Contents RW, Pull requests RW, Metadata R. 90-day expiry; set a Todoist reminder to rotate.
- [ ] **Step 2:** store it only as Paperclip company secret `GITHUB_TOKEN` (UI or CLI); bound at company scope.
  Verify: `gh api repos/mariopavlov/perigee/rulesets/25333874 -q .enforcement` → `active` (gate still on), and the secret is listed (name only) in Paperclip.

### Task 9: Import and configure the company

**Files:**
- Create: `paperclip/README.md`

**Interfaces:**
- Consumes: `paperclip/company/` (Tasks 5–7), FINDINGS, `GITHUB_TOKEN` (Task 8).
- Produces: live company in Paperclip; review chain configuration used by every delivery issue.

- [ ] **Step 1: Import.** `paperclipai company import <path to paperclip/company>` (exact form per FINDINGS). Expected: 11 agents, paused, timer heartbeats disabled (Paperclip's import default).
- [ ] **Step 2: Default review chain** (pattern chosen in FINDINGS Step 6). Developer issues: DDD Reviewer → QA → Delivery Lead approval. Platform/DevOps issues: Cloud Architect → Security-claude → Delivery Lead. Security-codex output: Security-claude. Design/strategy: Mario (board).
- [ ] **Step 3: Unpause agents** except none — all active, timers only on Delivery Lead.
- [ ] **Step 4: Write `paperclip/README.md`.** Re-import procedure, where each setting lives, the two gates (Approvals page = front gate, `m0 → main` PR = back gate), Blocked inbox, how to call the Teacher (live: `teacher` skill in Claude Code; in-context: per FINDINGS).
- [ ] **Step 5: Commit.** `git add paperclip/README.md && git commit -m "paperclip: operating guide"`

### Task 10: End-to-end smoke test on a throwaway repo

Repo: new private `mariopavlov/paperclip-smoke` (ask Mario before creating) with the same ruleset as Perigee, containing a minimal Go module with one test.

- [ ] **Step 1: Requirement → strategy.** Give the CEO: "Add a `/health` HTTP endpoint returning 200 and `{"status":"ok"}`, with a test." Expected: strategy lands on the Approvals page; Mario approves.
- [ ] **Step 2: Plan → tasks → build.** Expected: Delivery Lead creates issue(s), a Codex developer implements on a task branch, DDD Reviewer and QA review, Lead approves and merges into `m0`, then opens `m0 → main` PR.
- [ ] **Step 3: Review rule holds.** Check every Codex-executed issue shows a Claude review decision with a comment before approval. Fail = any Codex issue approved without one.
- [ ] **Step 3b: Review trail on GitHub.** Seed one deliberate defect in the requirement (e.g. ask QA to insist on a `Content-Type: application/json` check the developer is told to omit) so at least one finding is raised. Expected on the task PR: role-tagged finding comment, a `fix(review):` commit with `Review-Finding:` trailer, executor reply with the SHA; on the `m0 → main` PR: digest row for that finding; after Mario's rebase-merge, `git log main --format='%s%n%(trailers:key=Review-Finding)'` shows the fix commit and trailer.
- [ ] **Step 4: Main gate holds (Review Focus 3).** From a shell using the agents' token: `git push https://x-access-token:$TOKEN@github.com/mariopavlov/paperclip-smoke HEAD:main` → expected rejection (`GH013`/protected). Mario merges the PR himself with rebase.
- [ ] **Step 5: Budget cap behaviour (Review Focus 4).** Set QA's budget just above current spend, assign it a review; expected auto-pause, issue stays `in_review`, not done. Restore the budget.
- [ ] **Step 6: Teacher in-context.** Mario calls the Teacher on the `/health` issue ("why a separate readiness vs liveness check?"). Expected: it diagnoses first, answers in comments, writes a Knowledge Check to Notion.
- [ ] **Step 7: Record cost.** Note Claude vs Codex usage for the run in `paperclip/FINDINGS.md` (new "Smoke test" section). Commit.

### Task 11: Prepare the Perigee repo

Work on branch `chore/paperclip-team` in `~/workspace/github.com/mariopavlov/perigee`; Mario merges the PR.

- [ ] **Step 1: Remove Beads.** Delete `.beads/`; remove the `bd prime` SessionStart hook from `.claude/settings.json`; remove Beads integrations under `.codex/` and `.cursor/`; delete `BEGIN/END BEADS` blocks in `AGENTS.md` and `CLAUDE.md`; replace README's "Issue tracking: Beads" section with "Work tracking: Paperclip" (agents' issues live in Paperclip; Mario's checkpoints in Todoist). Unset `core.hooksPath` if it points at `.beads/hooks`.
  Verify: `grep -ri "beads\|\bbd " --exclude-dir=.git .` → only historical mentions in `docs/design/` decision log entries.
- [ ] **Step 2: Rewrite the Git Policy** in `AGENTS.md` and README "Git workflow": agents commit and push on task branches; Delivery Lead merges approved branches into milestone branch (`m0`); only Mario merges to `main`, via PR, rebase only.
- [ ] **Step 3: Update `docs/design/session-state.md`.** Next steps become: cloud-native review by the Paperclip team (D25+), then revise M0 plan, then build M0 via Paperclip. Remove the Beads issue-creation step.
- [ ] **Step 4: Create `m0`.** `git push origin main:refs/heads/m0` after the PR merges.
- [ ] **Step 5: PR.** Commit, push the branch, `gh pr create` to `main`; Mario reviews and rebase-merges.

### Task 12: Kick off Perigee

- [ ] **Step 1:** In Paperclip, create project "Perigee" with workspace = local path `~/workspace/github.com/mariopavlov/perigee`, isolated execution workspaces on.
- [ ] **Step 2: Mario gives the CEO the requirement** (draft for him to edit): *"Perigee must be cloud native: containerised, stateless services, config from the environment, health/readiness endpoints, horizontally scalable, observable; deployable later to Azure or AWS (target open). Review the approved spec and the M0 plan for this. Propose changes as decisions D25+, then a revised M0 plan."*
- [ ] **Step 3:** Expected: CEO creates review sub-issues (Cloud Architect, DDD, Security pair), proposes D25+, submits strategy to the Approvals page. Mario approves or requests revision. M0 then runs under the team; the checkpoint review (spec §9 step 4) happens when Mario merges `m0 → main`.
