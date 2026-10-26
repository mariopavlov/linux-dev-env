# Keystone: Two QAs, QA-Written Tests and Security Reports — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reshape Keystone so QA writes the tests before developers implement, split QA into a Delivery QA and a Security QA, and add a Security Writer that turns each milestone's security round into Markdown reports.

**Architecture:** Agents are Markdown instruction files in `paperclip/src/agents/<slug>.md` (frontmatter `name`, `title`, `reportsTo`); `paperclip/build.sh` appends `paperclip/src/team-rules.md` to each and writes `paperclip/company/agents/<slug>/AGENTS.md`; `paperclip/configure.sh` pushes them to the running Paperclip company and keeps per-agent maps (name, model, effort, icon, palette, skills); `paperclip/company/.paperclip.yaml` carries role, adapter and permissions for import. A new consistency test guards the maps as agents are added and renamed.

**Tech Stack:** Bash, jq, Markdown; Paperclip API at `http://127.0.0.1:3100/api`; mise for tools (`dotfiles/dot_config/mise/config.toml`, applied with chezmoi).

**Spec:** `docs/superpowers/specs/2026-10-26-keystone-qa-and-security-reporting-design.md`

## Global Constraints

- New agents: Delivery QA (`delivery-qa`, today's `qa` renamed), Security QA (`security-qa`), Security Writer (`security-writer`). Delivery QA reports to `delivery-lead`; Security QA and Security Writer report to `security-lead`.
- Models: Delivery QA `claude-sonnet-5-5` effort `high`; Security QA `claude-sonnet-5-5` `high`; Security Writer `claude-opus-5-5` `high`.
- Locked test paths: `tests/acceptance/`, `tests/deploy/`, `tests/framework/` (Delivery QA) and `tests/security/` (Security QA), plus the Makefile or script targets, build tags and CI configuration that run them.
- Tests are Go: Terratest for the deployment suite, `terraform test` (plan, mock providers) for plan assertions. No unit tests for Terraform. Local environment: Docker plus `kind`.
- Agents never hold cloud credentials and never run `terraform apply` against a real account; Mario or a Graphwise colleague runs the suite against cloud test by hand.
- Issue names: `Test framework: <repo>`, `Tests: <task>`, `Security tests: <task>`, `Acceptance: <KEY-n>`, `Security acceptance: <KEY-n>`, `Security regression: <finding id>`, `Security fixes: <finding ids>`, `Security round: <milestone>`, `Security report: <milestone>`.
- Reports: `docs/security/<milestone>/internal/test-report.md`, `internal/exposures.md`, `internal/risks.md`, `client/exposure-report.md`, in the team's working repo on the milestone branch. The client report lists only each exposure, its severity and status **fixed** or **not addressed**.
- Finding tags: `[Delivery QA]` with ids `DQA-n`, `[Security QA]` with ids `SQA-n` (replace `[QA]`/`QA-n`).
- Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- After any change under `paperclip/src/`: `bash paperclip/build.sh` before committing; `paperclip/company/` is committed generated output.

## Review Focus

- **Renaming the live "QA Engineer":** `configure.sh` matches agents by name, so a rename it doesn't handle imports a duplicate QA. Task 2's rename must run before the import check and be idempotent on a second run.
- **An agent added to `src/agents/` but missed in one `configure.sh` map or `.paperclip.yaml`:** configure would push it with an empty model or icon. Task 1's test fails on any missing entry.
- **A `reportsTo` pointing at a slug that doesn't exist** (e.g. after renaming `qa`): Task 1's test fails.
- **Stale references to "QA" after the split** (an agent still told "QA reviews it next"): Task 7's grep step lists every remaining bare `QA` reference for a deliberate decision.
- **Delivery Lead unable to assign issues to Security QA** (outside its reporting subtree): Task 5 verifies against Paperclip's code and routes through the Security Lead if needed.

---

### Task 1: Team consistency test

**Files:**
- Create: `paperclip/tests/team_test.sh`
- Modify: `paperclip/README.md` (Layout table: add the test; "Changing the team" step 2: run it)

**Interfaces:**
- Produces: `bash paperclip/tests/team_test.sh [PAPERCLIP_DIR]` — exits 0 and prints `team_test.sh: PASS`, or prints `FAIL: <reason>` and exits 1. Defaults to the repo's `paperclip/`.

- [ ] **Step 1: Write the test.** For every `src/agents/<slug>.md` it asserts:
  - `configure.sh` has `[<slug>]=` in each of `NAME`, `MODEL`, `EFFORT`, `ICON`, `PALETTE`, `SKILLS` (`SKILLS` value may be empty);
  - the `NAME` value equals the frontmatter `name:`;
  - `company/.paperclip.yaml` has a top-level agent key `  <slug>:`;
  - frontmatter `reportsTo`, when present, names an existing `src/agents/<slug>.md`.
  And in reverse: every slug in `NAME` has a source file. Read the maps with `sed`/`grep` on `configure.sh` (no sourcing: it calls the API).
- [ ] **Step 2: Run it on the current tree.** Run: `bash paperclip/tests/team_test.sh` · Expected: `team_test.sh: PASS`.
- [ ] **Step 3: Prove it catches a gap.** Copy `paperclip/` to a temp dir, delete the `[teacher]=` line from `ICON` there, run `bash paperclip/tests/team_test.sh <tempdir>` · Expected: `FAIL: teacher missing from ICON`, exit 1. Then point a copy's `developer-1.md` at `reportsTo: "nobody"` · Expected: `FAIL: developer-1 reports to unknown nobody`. Add both checks to the test itself (same temp-copy pattern as `build_test.sh`) so they run every time.
- [ ] **Step 4: Run all paperclip tests.** Run: `for t in paperclip/tests/*_test.sh; do bash $t; done` · Expected: every test prints PASS.
- [ ] **Step 5: Commit** `paperclip: test that every agent is wired into configure.sh and the package`.

### Task 2: Delivery QA (rename and reshape today's QA)

**Files:**
- Rename: `paperclip/src/agents/qa.md` → `paperclip/src/agents/delivery-qa.md`
- Modify: `paperclip/configure.sh` (maps: slug `qa` → `delivery-qa`; add `RENAMED`), `paperclip/company/.paperclip.yaml` (key `qa` → `delivery-qa`), generated `paperclip/company/agents/`

**Interfaces:**
- Produces: agent `Delivery QA`, slug `delivery-qa`, title `Delivery QA Engineer`, `reportsTo: "delivery-lead"`; issue types it handles: `Test framework: <repo>`, `Tests: <task>`, `Acceptance: <KEY-n>`, plus today's client-document fact checks.
- Produces (configure.sh): `declare -A RENAMED=([delivery-qa]="QA Engineer")` — slug → previous live name.

- [ ] **Step 1: Rewrite the instructions** (`delivery-qa.md`), keeping the existing style. Must say:
  - **`Test framework: <repo>`:** build the framework under `tests/framework/` (fixtures, local environment on Docker plus `kind`, the commands that run each suite, configuration of the target environment through environment variables so the same suite runs against local, cloud test and live).
  - **`Tests: <task>`:** from the plan task, write failing acceptance and integration tests in Go under `tests/acceptance/` (and deployment checks under `tests/deploy/`, Terratest), commit them on the task branch, record the tests commit SHA on the issue, and end with a table mapping every acceptance criterion to its test. Never implement product code.
  - **`Acceptance: <KEY-n>`:** `git diff <tests commit>..HEAD` over the locked paths and their runners is empty; its tests pass when it runs them itself; every acceptance criterion is met; the code matches the spec and coding standards; nothing the Refactorer changed alters behaviour; exploratory edge cases (empty and oversized input, wrong methods, repeated requests, restart, missing configuration); the full suite passes. It is the Claude review of everything the Codex agents produce.
  - **Client documents:** keep today's step 5 (sources table, Research Scout claim checks) unchanged.
  - **Milestone end:** keep today's step 6 (follow the demo checklist and runbooks).
  - **Disputes:** when a developer's `Question:` about one of its tests is agreed, it changes the test and records a new tests commit SHA.
  - Findings `[Delivery QA] DQA-n`; verdict `[Delivery QA] Verdict: PASS|FAIL`; post on its own issue, set it `done`; never fixes product code.
- [ ] **Step 2: Update `configure.sh` maps**: replace every `[qa]=` with `[delivery-qa]=`; `NAME` `"Delivery QA"`; `EFFORT` `"high"`; keep model, icon `bug`, palette `arctic-blue`, skills `code-review verification-before-completion systematic-debugging`.
- [ ] **Step 3: Add rename support to `configure.sh`**, in the "Agents" section before the `missing=()` loop: for each slug in `RENAMED`, if no agent has `NAME[slug]` and one has `RENAMED[slug]`, `PATCH /agents/<id>` with `{name, title}` (title from the agent's frontmatter), print `  renamed: <old> → <new>`, and re-read `AGENTS`. A second run finds the new name and does nothing.
- [ ] **Step 4: Rename the yaml key** `qa:` → `delivery-qa:` (role `qa` unchanged).
- [ ] **Step 5: Build and test.** Run: `bash paperclip/build.sh && bash paperclip/tests/build_test.sh && bash paperclip/tests/team_test.sh && bash -n paperclip/configure.sh` · Expected: both tests PASS; `paperclip/company/agents/qa/` is gone and `delivery-qa/` exists.
- [ ] **Step 6: Commit** `paperclip: reshape QA into Delivery QA under the Delivery Lead`.

### Task 3: Security QA

**Files:**
- Create: `paperclip/src/agents/security-qa.md`
- Modify: `paperclip/configure.sh` (all six maps; `GITLAB_PUSHERS`), `paperclip/company/.paperclip.yaml`

**Interfaces:**
- Produces: agent `Security QA`, slug `security-qa`, title `Security QA Engineer`, `reportsTo: "security-lead"`; handles `Security tests: <task>`, `Security acceptance: <KEY-n>`, `Security regression: <finding id>`.

- [ ] **Step 1: Write the instructions.** Must say:
  - It writes the tests that prove the security controls hold, in Go and Terraform tests under `tests/security/`: scanner configuration (`tflint`, `trivy config` for IaC, `trivy image` for images and dependencies, `trivy` SBOM, `gitleaks` for secrets), `terraform test` plan assertions, refused requests (no sign-in, wrong role, expired token, admin paths from outside), and post-deploy security checks added to the deployment suite. Same local environment as Delivery QA's framework.
  - **`Security tests: <task>`:** failing tests for each security control the plan task lists; tests commit SHA on the issue; table mapping each control to its test.
  - **`Security acceptance: <KEY-n>`:** the same unchanged-tests `git diff` over `tests/security/`; its tests pass when it runs them; each control is proven.
  - **`Security regression: <finding id>`:** a failing test that reproduces the finding against code or the local system; for a finding that cannot be reproduced, say so and stop.
  - Disputes on its tests come from the Security Lead; agreed changes are its to make.
  - Findings `[Security QA] SQA-n`; verdict on its own issue, set `done`; never fixes product code; never touches a real cloud account.
- [ ] **Step 2: Wire it**: `NAME` `"Security QA"`, `MODEL` `"claude-sonnet-5-5"`, `EFFORT` `"high"`, `ICON` `"eye"`, `PALETTE` `"deep-tide"`, `SKILLS` `"verification-before-completion systematic-debugging terraform-test"`; add `security-qa` to `GITLAB_PUSHERS`; yaml entry role `qa`, adapter `claude_local`, no grants.
- [ ] **Step 3: Build and test.** Run: `bash paperclip/build.sh && bash paperclip/tests/team_test.sh` · Expected: PASS.
- [ ] **Step 4: Commit** `paperclip: add Security QA to the Security Team`.

### Task 4: Security Writer

**Files:**
- Create: `paperclip/src/agents/security-writer.md`
- Modify: `paperclip/configure.sh` (six maps; `GITLAB_PUSHERS`), `paperclip/company/.paperclip.yaml`

**Interfaces:**
- Produces: agent `Security Writer`, slug `security-writer`, title `Security Writer`, `reportsTo: "security-lead"`; handles `Security report: <milestone>`.

- [ ] **Step 1: Write the instructions.** Must say:
  - Runs once per milestone, on `Security report: <milestone>` from the Security Lead, after the verdict and the Principal's decisions; decides and invents nothing.
  - Sources: the Security Lead's consolidated verdict, the reviewers' and Red Team's findings with reproduction steps, Security QA's test results and regression tests, each fix's outcome. Keeps a `sources` issue document (one row per claim, as the Technical Writer does); a claim without a source comes out.
  - Writes the four files at the Global Constraints paths on its issue branch, from the milestone branch, then opens a draft PR into the milestone branch:
    - `internal/test-report.md`: what was tested, where (local; cloud test when a person recorded a run), how, results.
    - `internal/exposures.md`: per exposure — id, severity, how it was found (steps), impact, fix commit or reason left open, regression test.
    - `internal/risks.md`: residual risks — what remains, why accepted or not, owner.
    - `client/exposure-report.md`: per exposure — a plain description, severity, status **fixed** or **not addressed**; nothing else.
  - The client file follows the Technical Writer's style rules (no internal names, ids, agents, branches or attack steps).
  - Delivery QA checks the client file's facts like any client document.
- [ ] **Step 2: Wire it**: `NAME` `"Security Writer"`, `MODEL` `"claude-opus-5-5"`, `EFFORT` `"high"`, `ICON` `"file-code"`, `PALETTE` `"pink-lemonade"`, `SKILLS` `"verification-before-completion"`; add to `GITLAB_PUSHERS`; yaml role `general`, adapter `claude_local`, no grants.
- [ ] **Step 3: Build and test.** Run: `bash paperclip/build.sh && bash paperclip/tests/team_test.sh` · Expected: PASS.
- [ ] **Step 4: Commit** `paperclip: add Security Writer to the Security Team`.

### Task 5: Delivery Lead runs the tests-first flow

**Files:**
- Modify: `paperclip/src/agents/delivery-lead.md`, generated `paperclip/company/agents/`

**Interfaces:**
- Consumes: the issue names in Global Constraints; agents `delivery-qa`, `security-qa`, `security-lead`.

- [ ] **Step 1: Check cross-team assignment.** In the installed Paperclip server (`~/.paperclip/cli/installs/npm/*/node_modules/@paperclipai/server`), find how `tasks:assign_scope` (`subtreeRootAgentId`) is enforced when an agent creates an issue assigned to another agent. Record the answer in the commit message. If the Delivery Lead cannot assign to `security-qa`, Steps 2–3 route `Security tests:` and `Security acceptance:` through one issue for the Security Lead instead.
- [ ] **Step 2: Rewrite sections 1–3** of `delivery-lead.md`:
  - First use of the flow in a repo: `Test framework: <repo>` for Delivery QA before any `Tests:` issue.
  - Per plan task, before the build issue: `Tests: <task>` for Delivery QA and, when the plan task lists security controls, `Security tests: <task>` for Security QA, both in the task's workspace; the build issue is blocked by them. Before starting the developer, check each test issue's criterion-to-test table; a criterion with no test goes back to its QA.
  - After the developer: Refactorer (Technical Writer tasks skip it), then `Acceptance: <KEY-n>` for Delivery QA and, when there were security tests, `Security acceptance: <KEY-n>` for Security QA, both blocked by the Refactorer review. Decide on both verdicts as today.
  - Security fixes: a `Security fixes: <finding ids>` issue from the Security Lead is handled like a QA FAIL — a fix round (in the task's workspace if not merged, otherwise a new build issue from the milestone branch) followed by `Security acceptance:`.
  - Disputes about a test: Delivery QA tests → it decides; Security QA tests → pass the `Question:` to the Security Lead; requirement or spec changes → the Principal. If agreed, the owning QA changes the test.
  - Hand-back: when the plan lists security controls, after the last merge create `Security round: <milestone>` for the Security Lead and wait for it (and its fix rounds) before handing back; record the reports' paths in the `review-digest`.
- [ ] **Step 3: Replace** every `QA review:` and bare "QA" in the file with the names above. Run: `grep -n "QA review\|\bQA\b" paperclip/src/agents/delivery-lead.md` · Expected: only `Delivery QA`, `Security QA` matches.
- [ ] **Step 4: Build, test, commit** (`bash paperclip/build.sh && bash paperclip/tests/team_test.sh`) · `paperclip: Delivery Lead runs QA-written tests before implementation`.

### Task 6: Security Lead runs findings and the report round

**Files:**
- Modify: `paperclip/src/agents/security-lead.md`, `paperclip/src/agents/red-team-engineer.md`, `paperclip/src/agents/security-codex.md`, `security-claude.md`, `security-deepseek.md`

- [ ] **Step 1: Security Lead** gains: it leads Security QA and Security Writer too; disputes about Security QA tests come to it; for each finding that will be fixed and can be reproduced, `Security regression: <finding id>` for Security QA, then one `Security fixes: <finding ids>` for the Delivery Lead (each finding plus its regression test); accepted findings get no test and go to `risks.md`; spec-review findings become security controls of the task that builds them; on `Security round: <milestone>` it runs the round (reviewers, Red Team when deployable, Security QA results), then after its verdict and the Principal's decisions creates `Security report: <milestone>` for the Security Writer and closes the round when the report PR is merged. Still no resourcing.
- [ ] **Step 2: Red Team and the three reviewers:** each finding's reproduction steps are complete enough for Security QA to turn into a regression test (one sentence each).
- [ ] **Step 3: Build, test, commit** · `paperclip: Security Lead turns findings into regression tests and reports`.

### Task 7: Developers, Platform Engineer, Refactorer, Principal and the rest

**Files:**
- Modify: `paperclip/src/agents/developer-1.md`, `developer-2.md`, `platform-devops.md`, `refactorer.md`, `ceo-principal-architect.md`, `technical-writer.md`, `research-scout.md`

- [ ] **Step 1: Developers and Platform Engineer:** replace developer step 2 ("write the failing test…") with: implement until the tests from the `Tests:` and `Security tests:` issues pass; unit tests of your own are optional and never evidence; never create, edit, move or delete anything in the locked paths or their runners; if you believe a QA test is wrong, raise a `Question:` naming the test and why, and keep going on the rest. Handoff line: "Delivery QA and, when there were security tests, Security QA run acceptance next."
- [ ] **Step 2: Refactorer:** its test-file rule names the locked paths explicitly.
- [ ] **Step 3: Principal Architect:** each plan task lists its acceptance criteria and the security controls it implements; Gate 3 links `docs/security/<milestone>/` when there was a security round.
- [ ] **Step 4: Technical Writer, Research Scout:** "QA" → "Delivery QA".
- [ ] **Step 5: Sweep.** Run: `grep -rn "\bQA\b" paperclip/src --include=*.md | grep -v "Delivery QA\|Security QA"` · Expected: no output, or each remaining line deliberately left (note them in the commit).
- [ ] **Step 6: Build, test, commit** · `paperclip: developers implement against QA's tests`.

### Task 8: Team rules and README

**Files:**
- Modify: `paperclip/src/team-rules.md`, `paperclip/README.md`

- [ ] **Step 1: Team rules:** under **Reviews**, tags `[Delivery QA]`, `[Security QA]` replace `[QA]`; "Delivery QA is the Claude review of everything Codex agents produce". New **Tests** section: QA owns the locked paths and their runners (Global Constraints list); developers and the Refactorer never touch them; the dispute path (Delivery Lead / Security Lead / Principal; the owning QA makes agreed changes); agents never apply to a real cloud account, cloud runs are by a person.
- [ ] **Step 2: README:** team table (Delivery QA, Security QA, Security Writer rows; remove QA Engineer), reporting lines paragraph, "How work flows" step 5 (tests first → developer → Refactorer → acceptance), the security round and reports before Gate 3, and the `RENAMED` behaviour in "Changing the team".
- [ ] **Step 3: Build, test, commit** · `paperclip: team rules and README for the two QAs`.

### Task 9: Test tools in mise

**Files:**
- Modify: `dotfiles/dot_config/mise/config.toml`

- [ ] **Step 1: Add** to the CLI tools list, alphabetically: `gitleaks = "latest"`, `tflint = "latest"`, `trivy = "latest"`, with a comment above them: the Keystone QAs' security and Terraform checks. (`terraform`, `helm`, `kubectl` are system packages; `kind` is already listed.)
- [ ] **Step 2: Verify** Run: `mise ls --current 2>/dev/null | grep -E "gitleaks|tflint|trivy"` after `chezmoi apply --source=dotfiles ~/.config/mise/config.toml && mise install gitleaks tflint trivy` · Expected: all three listed with versions.
- [ ] **Step 3: Commit** `mise: add gitleaks, tflint and trivy for the Keystone QAs`.

### Task 10: Apply to Keystone and verify

- [ ] **Step 1: All tests.** Run: `bash paperclip/build.sh --check && for t in paperclip/tests/*_test.sh; do bash $t; done` · Expected: all PASS.
- [ ] **Step 2: Apply.** Confirm no agent is running (`GET /companies/<id>/agents`, all `idle`), then Run: `bash paperclip/configure.sh` · Expected: `renamed: QA Engineer → Delivery QA`, `imported: security-qa,security-writer` (any order), every agent `instructions=updated`, no error.
- [ ] **Step 3: Idempotence.** Run `bash paperclip/configure.sh` again · Expected: no `renamed`, no `imported`, every agent `instructions=current`.
- [ ] **Step 4: Live check.** For every agent, the live `AGENTS.md` body equals the package body (same comparison as before: `GET /agents/<id>/instructions-bundle/file?path=AGENTS.md`); reporting lines: Delivery QA → Delivery Lead, Security QA and Security Writer → Security Lead; exactly one agent with role `qa` under each lead.
- [ ] **Step 5: Push** only when Mario asks.
