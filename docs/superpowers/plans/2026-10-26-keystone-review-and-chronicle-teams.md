# Keystone: Review and Chronicle Teams — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Review team (Review Lead, critic arsenal, disprovers, a GPT-6.1-Sol fallback) and a Chronicle team (Chronicle Lead, Technical Writer, Audit Writer, Mentor) to Keystone. The Principal routes each plan task, and the Principal or Claude can offer the Teacher.

**Architecture:** Agents are Markdown instruction files in `paperclip/src/agents/<slug>.md` (frontmatter `name`, `title`, `reportsTo`). `paperclip/build.sh` appends `paperclip/src/team-rules.md` to each one and writes `paperclip/company/agents/<slug>/AGENTS.md`. `paperclip/configure.sh` keeps the per-agent maps (name, model, effort, icon, palette, skills) and pushes them to the running company. `paperclip/company/.paperclip.yaml` carries each agent's role, adapter and permissions for import.

Each critic's method is written once in `paperclip/src/roles/<role>.md`. A new `build.sh` include directive pulls it into both the critic's own file and the Sol fallback critic's file, so the two never drift.

**Tech Stack:** Bash, jq, Markdown; Paperclip API at `http://127.0.0.1:3100/api`; adapters `claude_local`, `codex_local` and `opencode_local` (Ollama).

**Spec:** `docs/superpowers/specs/2026-10-26-keystone-review-and-chronicle-teams-design.md`

## Global Constraints

- **New agents** (slug · name · reports to · adapter · model · effort):
  - `review-lead` · Review Lead · `ceo-principal-architect` · claude_local · `claude-opus-5-5` · high
  - `bug-hunter-claude` · Bug Hunter·Claude · `review-lead` · claude_local · `claude-sonnet-5-5` · high
  - `bug-hunter-open` · Bug Hunter·Open · `review-lead` · opencode_local · `ollama/deepseek-v4-pro:0813-cloud` · high
  - `spec-contract-critic` · Spec & Contract Critic · `review-lead` · claude_local · `claude-sonnet-5-5` · high
  - `maintainability-critic` · Maintainability Critic · `review-lead` · opencode_local · `ollama/glm-5.3:cloud` · high
  - `first-principles-critic` · First-Principles Critic · `review-lead` · claude_local · `claude-opus-5-5` · high
  - `history-critic` · History Critic · `review-lead` · opencode_local · `ollama/deepseek-v4.1-flash:cloud` · medium
  - `disprover-claude` · Disprover·Claude · `review-lead` · claude_local · `claude-sonnet-5-5` · high
  - `disprover-open` · Disprover·Open · `review-lead` · opencode_local · `ollama/deepseek-v4-pro:0813-cloud` · high
  - `critic-sol` · Critic·Sol · `review-lead` · codex_local · `gpt-6.1-sol` · high
  - `chronicle-lead` · Chronicle Lead · `ceo-principal-architect` · claude_local · `claude-opus-5-5` · high
- **Moves:**
  - `cloud-architect` and `ddd-reviewer` now report to `review-lead`.
  - `technical-writer` and `mentor` now report to `chronicle-lead`.
  - `security-writer` is renamed to `audit-writer` (name "Audit Writer", title "Audit Writer") and reports to `chronicle-lead`; add `[audit-writer]="Security Writer"` to `RENAMED`.
- **Fallback:** every Ollama role falls back to `critic-sol` (`gpt-6.1-sol`), never to Claude. The verdict names which roles ran on the fallback. A finding that a fallback Disprover dropped is marked with the family-overlap note.
- **Issue names (new):**
  - `Review: <KEY-n>` and `Review: spec <milestone>` — to the Review Lead.
  - `Review fixes: <finding ids>` — from the Review Lead to the Delivery Lead.
  - `Review regression: <finding id>` — to Delivery QA.
  - `Security review: <KEY-n>` — to the Security Lead.
  - `Chronicle: <milestone>` and `Chronicle record: <milestone>` — to the Chronicle Lead.
  - `Help me understand: …` (existing) — gains an `Opened by:` line and a quoted trigger.
- **Route line** in every plan task, written by the Principal: `Route: Review(<lenses | lead picks>) → Security(review | none)`. `∥` means the stages run in parallel. `Route: none` is for Technical Writer tasks.
- **Finding tags and ids:** `[Bug Hunter·Claude] BUG-n`, `[Bug Hunter·Open] BUG-n`, `[Spec & Contract Critic] SPC-n`, `[Maintainability Critic] MNT-n`, `[First-Principles Critic] FPC-n`, `[History Critic] HST-n`, `[Critic·Sol] <role prefix>-n`, `[Review Lead]`, `[Chronicle Lead]`, `[Audit Writer]` (replaces `[Security Writer]`). Disprover verdicts are not findings: `[Disprover·Claude] keep|drop|downgrade <id>: …`.
- **Minimum review** on any code task: `bug-hunter-claude` plus `spec-contract-critic`. **Spec-review lenses:** spec-contract, first-principles, history, ddd, cloud-architect.
- **Audit output:** `docs/review/<milestone>/` (review audit) and `docs/security/<milestone>/` (unchanged) on the milestone branch.
- **Commits:**
  - Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - After any change under `paperclip/src/`, run `bash paperclip/build.sh` before committing; `paperclip/company/` is committed generated output.
  - Every task ends with `for t in paperclip/tests/*_test.sh; do bash $t; done` printing PASS for every test, and `bash -n paperclip/configure.sh`.

## Review Focus

- **The Delivery Lead creating issues for agents in other teams** (Review Lead, Security Lead, Technical Writer, Delivery QA via Review Lead): cross-team assignment works today (Delivery Lead → Security QA). The new leads need `tasks:assign` in `.paperclip.yaml` to fan out to their own members. Task 2 and Task 6 add it; Task 9 greps the yaml.
- **Renaming the live "Security Writer"**: if `RENAMED` is missing or wrong, `configure.sh` imports a duplicate Audit Writer. `team_test.sh` checks that `RENAMED` keys are known slugs (Task 6).
- **An include target that does not exist or is misspelled**: the build must fail loudly, not emit an agent missing its method (Task 1 test).
- **Stale references after the moves**: an agent still told "Delivery QA is the Claude review…", "Security Writer", the Security Lead creating `Security report:`, or the Principal writing the post-merge Notion record. Task 9 greps for each phrase and every hit is decided.
- **The disprove pass silently passing findings when Ollama is out**: the Review Lead's instructions must rerun on `critic-sol` and say so in the verdict. Task 3 states this, and Task 9's grep confirms `critic-sol` is named in `review-lead.md`.

---

### Task 1: Include directive in build.sh

**Files:**
- Modify: `paperclip/build.sh` (`render`)
- Test: `paperclip/tests/build_test.sh`

**Interfaces:**
- Produces: a line in a `src/agents/*.md` file that is exactly `<!-- include: <path> -->` is replaced by the contents of `$SRC/<path>`. A missing target prints `missing include: <path> (in <slug>)` to stderr, and `build.sh` exits 1 in both modes. Includes do not nest.

- [ ] **Step 1: Write the failing tests** in `build_test.sh`, in its temp tree:
  - Create `src/roles/gamma.md` containing `Gamma method.`
  - Give `alpha.md` a line `<!-- include: roles/gamma.md -->`.
  - Assert the output for alpha has the line `Gamma method.` and no `<!-- include:` line.
  - In a second copy, point the include at `roles/missing.md`. Assert `build.sh` exits non-zero and stderr contains `missing include: roles/missing.md (in alpha)`.
- [ ] **Step 2: Run** `bash paperclip/tests/build_test.sh` · Expected: FAIL (the include line is copied as-is).
- [ ] **Step 3: Implement** inside `render` in `build.sh`, with `awk` or a `while read` loop. Keep `--check` comparing the rendered output.
- [ ] **Step 4: Run** `bash paperclip/tests/build_test.sh` · Expected: `build_test.sh: PASS`.
- [ ] **Step 5: Commit** `paperclip: let agent sources include shared role files`.

### Task 2: Critic roles and the Review arsenal

**Files:**
- Create: `paperclip/src/roles/{critique-rules,bug-hunter,spec-contract,maintainability,first-principles,history,disprover}.md`
- Create: `paperclip/src/agents/{bug-hunter-claude,bug-hunter-open,spec-contract-critic,maintainability-critic,first-principles-critic,history-critic,disprover-claude,disprover-open,critic-sol}.md`
- Modify: `paperclip/configure.sh` (six maps, `ONE_SHOT`), `paperclip/company/.paperclip.yaml`

**Interfaces:**
- Consumes: the include directive from Task 1.
- Produces: the nine agent slugs above, all `reportsTo: "review-lead"`. Each critic takes a child issue from the Review Lead that names the build issue's workspace, the head SHA, the spec or plan section, and (for `critic-sol`) `Role: <bug-hunter|maintainability|history|disprover>`. Each critic ends by posting its findings on the PR and its issue, then sets the issue `done`.

- [ ] **Step 1: Write `roles/critique-rules.md`**, the rules every critic includes (spec §4.3):
  - The change has defects; find them. There is no default pass.
  - Each finding gives file:line, quoted evidence and a severity (critical, high, medium, low). A "will break" finding names the input or sequence that triggers it.
  - A finding without evidence is labelled `concern`.
  - Judge only what the change introduced. Pre-existing problems go in a "Tracked" list. Nothing a linter, compiler or test already catches.
  - End with a "Declined to judge" list.
  - In a disagreement, reply with exactly one of: agree; disagree with code evidence; concern without evidence.
  - Re-check mode (issue title starts `Re-check:`): verify only the fix commits for your own finding ids.
- [ ] **Step 2: Write each method file**, a short section in the style of `ddd-reviewer.md`:
  - `bug-hunter`: root-cause tracing; Five Whys on critical and high findings (adapted from CEK kaizen `why` and `root-cause-tracing`).
  - `spec-contract`: "spec silence is not permission"; checks that the change does nothing the spec doesn't ask for; APIs, types, invariants, breaking changes; whether the QA tests test behaviour.
  - `maintainability`: team clean-code rules plus a CEK code-quality checklist scoped to changed lines (complexity, duplication, naming, waste).
  - `first-principles`: FPF abduction → deduction → induction; states the hypotheses it considered and why each held or fell (adapted from CEK fpf `propose-hypotheses`).
  - `history`: `git log` and `git blame` on the changed lines, past findings in the Delivery Lead's `review-digest`, ADRs and D-decisions; flags reverted fixes and drift.
  - `disprover`: per finding, keep, drop or downgrade with evidence; when unsure, keep. One issue per critic's finding list.
  - Each method file names its finding prefix (BUG, SPC, MNT, FPC, HST).
  - Source material is in CEK at `NeoLabHQ/context-engineering-kit` (plugins `kaizen`, `fpf`, `reflexion`, `review`). Adapt the text; don't vendor it.
- [ ] **Step 3: Write the agent files.**
  - Each critic is frontmatter, one line saying who it is, `<!-- include: roles/critique-rules.md -->` (the Disprovers skip this one) and `<!-- include: roles/<method>.md -->`.
  - `bug-hunter-open` and `disprover-open` use the same method files as their Claude twins.
  - `critic-sol`: one paragraph saying it stands in for an open-model role when Ollama is down or out of credits; it does only the role its issue names and tags findings `[Critic·Sol]` with that role's prefix. Then the includes for critique-rules, bug-hunter, maintainability, history and disprover.
- [ ] **Step 4: Wire `configure.sh` and `.paperclip.yaml`.**
  - Maps: values from Global Constraints. Icons and palettes from those already in use (for example `bug`, `wand`, `lightbulb`, `git-branch`, `eye`, `shield`). `SKILLS` empty except `first-principles-critic="systematic-debugging"` and `bug-hunter-*="systematic-debugging"`.
  - Add all nine to `ONE_SHOT`.
  - yaml: role `general`, the adapter type from Global Constraints (opencode agents carry `config.model`), no permission grants.
- [ ] **Step 5: Build and test.** Run `bash paperclip/build.sh && for t in paperclip/tests/*_test.sh; do bash $t; done` · Expected: all PASS. `grep -c "Five Whys" paperclip/company/agents/critic-sol/AGENTS.md` prints `1`.
- [ ] **Step 6: Commit** `paperclip: add the Review team's critics, disprovers and Sol fallback`.

### Task 3: Review Lead, the moved reviewers, and review rules

**Files:**
- Create: `paperclip/src/agents/review-lead.md`
- Modify: `paperclip/src/agents/cloud-architect.md`, `paperclip/src/agents/ddd-reviewer.md` (`reportsTo: "review-lead"`; work comes from the Review Lead), `paperclip/src/team-rules.md` (**Reviews**), `paperclip/configure.sh`, `paperclip/company/.paperclip.yaml`

**Interfaces:**
- Consumes: critic slugs and the issue brief format from Task 2.
- Produces:
  - It handles `Review: <KEY-n>` (from the Delivery Lead, carrying the task's `Route:`) and `Review: spec <milestone>` (from the Principal).
  - It creates `Review fixes: <finding ids>` for the Delivery Lead, then `Re-check: <finding ids>` for each raising critic once fixes land, and a `Question:` to the Principal only to leave a critical or high finding open.

- [ ] **Step 1: Write `review-lead.md`** in the style of `security-lead.md`. It must say:
  - **Lenses:**
    - Take the route's lenses.
    - "lead picks": use the spec §4.2 guide, never less than the minimum review.
    - It may add a lens with a reason, and never drops a lens the route names.
    - On a spec review, only the five spec lenses.
    - Diversity rule: the critics span at least two model families, and a finding's Disprover is never on its critic's family.
  - **Fan out:** one child issue per lens in the build issue's workspace, in its own `blockedBy`.
  - **Disprove:** one Disprover issue per critic's finding list.
  - **Fallback:**
    - If an Ollama critic's or Disprover's run fails or reports exhausted credits, reissue the same brief to `critic-sol` with `Role:`.
    - Never pass findings through undisproved.
    - The verdict lists the roles that ran on the fallback, and adds the family-overlap note beside every finding a fallback Disprover dropped.
  - **Consolidate:** as the Security Lead does (dedupe, rank, must-fix vs tracked, surface splits, escalate minority critical or high).
  - **Code reviews:** `Review fixes:` to the Delivery Lead, then `Re-check:` issues.
  - **Spec reviews:** the verdict only, no fix issue.
  - **Disputes:**
    - It decides a developer's dispute of a finding.
    - Leaving a critical or high finding open goes to the Principal as a `Question:`.
  - **Approves** only when no critical or high finding is open.
  - Writes nothing to code and holds no credentials.
- [ ] **Step 2: Update the moved reviewers.** `cloud-architect.md` and `ddd-reviewer.md` take work from the Review Lead (spec and code), and both include `roles/critique-rules.md`.
- [ ] **Step 3: Rewrite team-rules **Reviews**.**
  - Specs and code are reviewed by the Review team as each plan task's route says.
  - Delivery QA and Security QA check acceptance against their tests.
  - Remove "Delivery QA is the Claude review of everything Codex agents produce".
  - Update the tag list per Global Constraints.
  - Add `fix(review)` with `Review-Finding:` for Review team ids (unchanged format).
- [ ] **Step 4: Wire `configure.sh` and the yaml** (role `pm`, claude_local, `permissionGrants: [tasks:assign]` like `security-lead`). `SKILLS[review-lead]="receiving-code-review"`.
- [ ] **Step 5: Build and test** as in Task 2 · Expected: all PASS.
- [ ] **Step 6: Commit** `paperclip: add the Review Lead and move the Cloud Architect and DDD Reviewer under it`.

### Task 4: Engineering — routes, Review stage, review fixes

**Files:**
- Modify: `paperclip/src/agents/delivery-lead.md` (sections 1–2, ad-hoc review, fix rounds, `review-digest`), `paperclip/src/agents/delivery-qa.md` (`Acceptance:` step 4, intro line, new `Review regression:`)

**Interfaces:**
- Consumes: `Review: <KEY-n>` and `Review fixes:` from Task 3; `Security review: <KEY-n>` from Task 5.
- Produces: `Review regression: <finding id>` for Delivery QA.

- [ ] **Step 1: Delivery Lead.**
  - After `Refactorer review:`, create the route's stages in its order: `Review: <KEY-n>` for the Review Lead and/or `Security review: <KEY-n>` for the Security Lead. `∥` creates both at once. `Acceptance:` is blocked by every stage.
  - Never change a route.
  - A task with no `Route:` line, or unplanned work, gets a `Question:` to the Principal for a route. Fix rounds reuse the task's route.
  - Handle `Review fixes:` like `Security fixes:`. A finding with a triggering input first gets `Review regression: <finding id>` for Delivery QA. The fix round goes back through `Acceptance:` and counts toward the third-round escalation.
  - Record review findings and outcomes in `review-digest`.
  - The ad-hoc "architectural, domain or security problem" review now goes to the Review Lead or the Security Lead.
- [ ] **Step 2: Delivery QA.**
  - Remove "You are the Claude review of everything the Codex agents produce."
  - `Acceptance:` step 4 becomes: nothing the Refactorer changed alters behaviour, proved by the suite. Spec and standards judgement moves out, and the code-review skill reference goes.
  - Add `Review regression: <finding id>`: the same shape as Security QA's `Security regression:`, a failing test under its own paths that reproduces the finding's input, with the tests commit SHA in the done comment.
  - In `configure.sh`, drop `code-review` from `SKILLS[delivery-qa]`.
- [ ] **Step 3: Build and test** · Expected: all PASS. Check that `grep -n "Claude review of everything" paperclip/src -r` prints nothing.
- [ ] **Step 4: Commit** `paperclip: route each task through the Review team and move code review off Delivery QA`.

### Task 5: Security — per-task review; the round ends at the verdict

**Files:**
- Modify: `paperclip/src/agents/security-lead.md`

**Interfaces:**
- Produces: `Security review: <KEY-n>` handling. The `Security round:` steps 4–6 (`Security report:` and its `Acceptance:`) are removed. The round ends at step 3, and the Security Lead marks its issue done with the verdict.

- [ ] **Step 1: Add `Security review: <KEY-n>`.**
  - Pick only the reviewers the change needs.
  - Fan out in the task's workspace and consolidate as in a round.
  - Send `Security fixes:` as today, then mark done with the verdict.
- [ ] **Step 2: Remove the Security Writer** from the intro and from steps 4–6. Add one line: the Chronicle team writes the round's reports from the verdict and findings on its issue, so the verdict carries every finding, its outcome and its regression test.
- [ ] **Step 3: Build and test** · Expected: all PASS.
- [ ] **Step 4: Commit** `paperclip: add per-task security reviews and hand security reports to Chronicle`.

### Task 6: Chronicle team

**Files:**
- Create: `paperclip/src/agents/chronicle-lead.md`
- Rename: `paperclip/src/agents/security-writer.md` → `paperclip/src/agents/audit-writer.md`
- Modify: `paperclip/src/agents/technical-writer.md`, `paperclip/src/agents/mentor.md`, `paperclip/src/agents/delivery-qa.md` (client-documents line: "an Audit Writer report"), `paperclip/configure.sh` (maps, `RENAMED`, `GITLAB_PUSHERS`, `NOTION_PROFILES`, `LONG_RUN_TIMEOUT_SEC`), `paperclip/company/.paperclip.yaml`
- Test: `paperclip/tests/team_test.sh` (every `RENAMED` key has a source file)

**Interfaces:**
- Consumes: the Security Lead's verdict issue (Task 5); `review-digest` (Task 4).
- Produces:
  - `Chronicle: <milestone>` (documents) and `Chronicle record: <milestone>` (Notion and the Mentor's "finished" sync).
  - Audit Writer issues: `Security report: <milestone>` and `Review audit: <milestone>`.

- [ ] **Step 1: Write the failing test.** `team_test.sh` fails with `RENAMED has <slug> but there is no src/agents/<slug>.md`. Add a temp-copy case for it. Run · Expected: PASS on the current tree; the broken copy prints the message.
- [ ] **Step 2: Write `chronicle-lead.md`** per spec §6.1:
  - **Documents round:**
    - Follow the brief from the Principal; context comes only from the brief, the repo and the issues it links.
    - Fan out to the Technical Writer and Audit Writer, each in its own worktree from the milestone branch.
    - Send each document to Delivery QA's `Acceptance:` fact check, with `Fix <ids>:` back to the writer on FAIL.
    - Mark done with the document PRs.
    - A Gate 3 revision reopens the affected writer.
  - **Record round:**
    - Write the milestone page's Progress log and Links, and the project page's Progress log and Next steps.
    - Create the Mentor's `Mentor: <milestone> — finished`.
    - Never touch `Status` or `Last update`.
- [ ] **Step 3: Rename the writer to `audit-writer.md`.**
  - Name and title "Audit Writer", `reportsTo: "chronicle-lead"`.
  - Work comes from the Chronicle Lead.
  - Add `Review audit: <milestone>`: from `review-digest`, write `docs/review/<milestone>/audit.md` (per task: findings, outcomes, tracked items, residual concerns) with the same sources-table discipline as the security reports.
  - In `configure.sh`, replace `[security-writer]` with `[audit-writer]` in every map and in `GITLAB_PUSHERS`, and add `[audit-writer]="Security Writer"` to `RENAMED`. Rename the yaml key.
- [ ] **Step 4: Update the members.**
  - `technical-writer.md`: `reportsTo: "chronicle-lead"`. Document plan tasks still come from the Delivery Lead during the build; milestone-end documents come from the Chronicle Lead.
  - `mentor.md`: `reportsTo: "chronicle-lead"`. "Spec approved" comes from the Principal; "finished" comes from the Chronicle Lead.
- [ ] **Step 5: Wire `chronicle-lead`.**
  - `configure.sh` maps per Global Constraints; `GITLAB_PUSHERS`.
  - Add it to the `keystone-notion-records` profile.
  - `LONG_RUN_TIMEOUT_SEC[chronicle-lead]=5400`.
  - yaml: role `pm`, claude_local, `tasks:assign`.
- [ ] **Step 6: Build and test** · Expected: all PASS. `company/agents/security-writer/` is gone and `audit-writer/` exists.
- [ ] **Step 7: Commit** `paperclip: add the Chronicle team with the writers and the Mentor`.

### Task 7: Principal — routes, spec reviews, Chronicle, record hand-off

**Files:**
- Modify: `paperclip/src/agents/ceo-principal-architect.md`

**Interfaces:**
- Consumes: `Review: spec <milestone>` (Task 3), `Chronicle:` and `Chronicle record:` (Task 6).

- [ ] **Step 1: Plan writing.** Every plan task gets a `Route:` line in the Global Constraints format. A Technical Writer task gets `Route: none`.
- [ ] **Step 2: Sizing (section 2).**
  - Replace the direct Cloud Architect and DDD Reviewer review issues with one `Review: spec <milestone>` for the Review Lead, naming the lenses the change needs.
  - The security reviewers are unchanged.
  - Resolve the Review Lead's verdict by revising the documents, as today.
- [ ] **Step 3: Answer route Questions.** A `Question:` asking for a route is answered inside the approved spec, so no card to Mario.
- [ ] **Step 4: Milestone end (sections 5 and Gate 3).**
  - When `Build:` is done, create `Chronicle: <milestone>`. The brief names the documents, audiences, sources and emphasis.
  - Merge its document PRs into the milestone branch and link them from the milestone PR.
  - After Mario merges, set `Status` `Done` and `Finished` yourself, then create `Chronicle record: <milestone>`.
  - Remove your own post-merge Progress log, Next steps and Mentor "finished" steps.
- [ ] **Step 5: Teacher.** When Mario's answers show he is missing context, offer a Teacher session in your next card and wait for his yes. On yes, create `Help me understand: <topic>` under the relevant issue, assigned to the Teacher, with `Opened by: Principal Architect` and the quoted answer that prompted it.
- [ ] **Step 6: Build and test** · Expected: all PASS.
- [ ] **Step 7: Commit** `paperclip: Principal routes tasks and hands milestone records to Chronicle`.

### Task 8: Teacher and Claude's offer

**Files:**
- Modify: `paperclip/src/agents/teacher.md`
- Create: `claude-skills/dot-claude/skills/paperclip-teacher-offer/SKILL.md`

**Interfaces:**
- Produces: a Claude skill. Its trigger is "Use when talking with Mario about Paperclip/Keystone work and he signals he does not follow a concept, a design or a proposal".
- [ ] **Step 1: Teacher.** "You take work only from Mario" becomes "from Mario, or from the Principal Architect or Claude after Mario agreed: the issue says who opened it (`Opened by:`) and quotes what prompted it. Start from that quote."
- [ ] **Step 2: Write the skill.**
  1. Offer in one line, naming the concept, and wait for an explicit yes. Never create the issue without it.
  2. On yes, use the paperclip skill to create a child issue `Help me understand: <topic>` under the Keystone issue being discussed (or ask Mario which one), assigned to the Teacher, with `Opened by: Claude`, the quoted moment and the context links.
  3. Reply with the issue link.

  Don't edit the vendored paperclip skill. `setup-*-wsl/packages/claude.sh` already links everything under `claude-skills/dot-claude/`.
- [ ] **Step 3: Verify.** `head -5 claude-skills/dot-claude/skills/paperclip-teacher-offer/SKILL.md` shows frontmatter with `name: paperclip-teacher-offer` and the description. Build and test · Expected: all PASS.
- [ ] **Step 4: Commit** `paperclip: let the Principal and Claude offer a Teacher session`.

### Task 9: README, stale-reference sweep, full check

**Files:**
- Modify: `paperclip/README.md` (team table and the flow description: the five teams, routes, review and Chronicle rounds, fallback); any file the sweep turns up.

- [ ] **Step 1: Update the README** to the five teams in spec §3 and the flow changes.
- [ ] **Step 2: Sweep.** Run each of these and decide every hit (fix it, or keep it with a reason in the commit message):
  - `grep -rn "Security Writer\|security-writer" paperclip/src paperclip/configure.sh paperclip/README.md paperclip/company/.paperclip.yaml`
  - `grep -rn "Security report:" paperclip/src`
  - `grep -rn "code-review skill\|Claude review" paperclip/src`
  - `grep -rn "reportsTo" paperclip/src/agents | sort`
  - `grep -n "critic-sol" paperclip/src/agents/review-lead.md`
  - `awk '/^  [a-z0-9-]+:$/{a=$1} /tasks:assign/{print a}' paperclip/company/.paperclip.yaml`

  Expected: no stale hits; `reportsTo` matches the Global Constraints; `review-lead.md` names `critic-sol`; `tasks:assign` covers the Principal, the Delivery, Security, Review and Chronicle Leads.
- [ ] **Step 3: Full check.** Run `bash paperclip/build.sh --check && for t in paperclip/tests/*_test.sh; do bash $t; done && bash -n paperclip/configure.sh` · Expected: all PASS, no output from `--check`.
- [ ] **Step 4: Commit** `paperclip: document the Review and Chronicle teams`.
- [ ] **Step 5: Hand to Mario.** Applying to the live company is his step: `bash paperclip/configure.sh`. Expected output: `renamed: Security Writer → Audit Writer`, and `imported:` listing the 11 new slugs.
