# Keystone: Review and Chronicle teams — Design

**Date:** 2026-10-26 · **Status:** approved 2026-10-26 · **Author:** Mario + Claude (brainstorm)

Builds on `2026-10-18-paperclip-agent-team-design.md` and
`2026-10-26-keystone-qa-and-security-reporting-design.md`, and on the team as it stands at
`01f265b`. The team lives in `paperclip/`: agent instructions in `src/agents/*.md`, shared rules
in `src/team-rules.md`, the generated package in `company/`, models and skills in `configure.sh`.

## 1. Intent

Code review in Keystone today is effectively one agent. Delivery QA writes the tests, checks
acceptance, *and* judges the code (step 4 of `Acceptance:`, the code-review skill on the Standards
and Spec axes). The DDD Reviewer and Cloud Architect look at code only when someone asks. One
reviewer on one model sees one set of angles and shares that model's blind spots.

Mario wants more dimensions of review, done with a critique mindset: reviewers that assume the
change is flawed and try to prove it, each from a different angle, so he gets better visibility
into the code. The Security team already works this way (a lead fans out to reviewers on three
model families, consolidates, never flattens disagreement, and sends one fix issue back). He wants
the same shape for general review, and a separate team that turns finished work into documents
and records.

Research behind the choices below (CEK `code-reviewer`, `code-quality-reviewer`, reflexion
`critique`, CEK `review` plugin; Superpowers `requesting-code-review`; Anthropic `/code-review`
and security-review; Cursor Bugbot; OpenAI Codex review; arXiv 2608.18167, 2511.16708,
2510.21513, 2404.18796):
- Adding reviewers on the same model barely helps (1→2 same-model reviewers: no gain). Different
  **angles** and different **model families** do help; same-family reviewers make correlated
  errors, and judges favour their own family's output.
- The common winning pattern is not more reviewers but a **separate pass per finding that tries
  to disprove it**, plus evidence requirements. Pushing too far toward caution makes reviewers
  miss real bugs, so finders stay aggressive and the disprover filters.
- No source names an optimal reviewer count. Hence an arsenal of narrow roles from which the
  lead picks per change, rather than a fixed panel.

## 2. Goals, non-goals, anti-goals

**Goals**
- A **Review team** with a Review Lead and an arsenal of critic roles, each one angle and one
  critique method, spread over OpenAI, Anthropic and open (Ollama) models.
- Every finding carries evidence and survives a disprove pass before a developer sees it.
- The **Principal routes** each plan task (which teams, which lenses, which order) when it
  writes the plan; the Delivery Lead follows the route.
- A **Chronicle team** that produces the milestone's documents (security, audit, technical) and
  its Notion record, given work once per milestone by the Principal.
- The **Teacher** can be proposed by the Principal or by Claude (Mario's interface to Paperclip),
  not only by Mario.

**Non-goals (for now)**
- A per-milestone review round like the security round. Review is per plan task (and per spec).
- Changing how tests are written: Delivery QA and Security QA keep owning tests and acceptance.
- Changing the Security team's reviewers or the security round, beyond moving the Security
  Writer out and adding the per-task security review a route can ask for (§5).

**Anti-goals** — this fails even if it works if:
- Reviewers rubber-stamp, or the developer drowns in unverified, nit-level findings.
- The Principal is woken on every PR to decide its route.
- The Teacher is started without Mario's yes.
- A minority critical finding is voted away during consolidation.

## 3. Teams after the change

| Team | Lead | Members |
|---|---|---|
| Leadership | Principal Architect | Research Scout, Cloud Architect Advisor, Teacher |
| Engineering | Delivery Lead | Developer 1, Developer 2, Platform Engineer, Refactorer, Delivery QA |
| Security | Security Lead | Security·Codex, Security·Claude, Security·DeepSeek, Red Team Engineer, Security QA |
| Review (new) | Review Lead (new) | Cloud Architect and DDD Reviewer (moved), critics in §4.2 (new) |
| Chronicle (new) | Chronicle Lead (new) | Technical Writer (from Engineering), Security Writer (from Security), Mentor (from Leadership) |

Team leads report to the Principal; members report to their lead (`reportsTo` in each agent file).

## 4. Review team

### 4.1 Review Lead
Owns the review verdict, built like the Security Lead:
- **Takes work** from the Delivery Lead (`Review: <KEY-n>` per plan task, carrying the task's
  route) and from the Principal (`Review: spec <milestone>` for spec and plan reviews — these
  replace the Principal's direct review issues to the Cloud Architect and DDD Reviewer).
- **Picks lenses.** Uses the lenses the route names; when the route says only "Review", picks
  them from what the change touches. May add a lens the route left out and say why; never drops
  one the route names.
- **Fans out** one child issue per lens, assigned to that critic.
- **Disproves.** Sends each finding to a Disprover on a different model family from the critic
  that raised it (§4.3).
- **Consolidates** surviving findings into one verdict: deduplicated, ranked by severity, must-fix
  separated from tracked. Disagreement is surfaced with both positions and the lead's side; a
  minority critical or high finding is escalated, not voted away.
- **Sends fixes** as one `Review fixes: <finding ids>` issue to the Delivery Lead, mirroring
  `Security fixes:`, and blocks on it. When it is done, the critic that raised each finding
  re-checks its fix.
- **Approves** only when no critical or high finding is open.
- Model: Claude Opus (my call — a different family from the developers' GPT models, and from
  the Security Lead's).

### 4.2 The arsenal

| Role | Angle | Method it uses | Model (my call) |
|---|---|---|---|
| Bug Hunter·Claude | Correctness: logic, edge cases, nil/empty, races, leaks, swallowed errors | Root-cause tracing; Kaizen Five Whys for serious bugs; every "will break" names the input that breaks it | Claude Sonnet |
| Bug Hunter·Open | Same angle, second family, for risky changes | Same | Ollama DeepSeek pro |
| Spec & Contract Critic | Does what the spec says and nothing more; APIs, types, invariants, breaking changes; do the tests test behaviour | Superpowers rule "spec silence is not permission"; CEK SDD evidence-before-score | Claude Sonnet |
| Maintainability Critic | Team standards, complexity, duplication, naming, waste (Muda) | CEK code-quality checklist, scoped to changed code | Ollama GLM |
| First-Principles Critic | Is the approach itself right; hidden assumptions; simpler alternatives | CEK FPF: abduction → deduction → induction, auditable reasoning | Claude Opus |
| History Critic | Recurring bugs, drift from earlier decisions and ADRs, reverted fixes | git blame/log, past PR findings in `review-digest` | Ollama DeepSeek flash |
| DDD Reviewer (moved) | Domain model, boundaries, ubiquitous language | unchanged | unchanged |
| Cloud Architect (moved) | Deployment, scaling, cloud services, ops readiness, cost | unchanged | unchanged |
| Disprover·Claude / Disprover·Open | Tries to kill each finding (§4.3) | Falsification | Claude Sonnet / Ollama DeepSeek pro |

The Review Lead's guide for typical routes (my call): the minimum on any code task is Bug
Hunter·Claude and the Spec & Contract Critic (the spec-fit check Delivery QA gives up must never
disappear); a standard task gets one or two of Bug Hunter, Spec & Contract and Maintainability, plus
DDD when domain code changes and Cloud Architect when deployment or infrastructure changes;
First-Principles, History and Bug Hunter·Open are for risky or design-heavy changes.

### 4.3 Critique rules (all critics; in the Review team section of `team-rules.md`)
- Start from "this change has defects; find them". There is no default pass.
- Every finding: file and line, quoted evidence, severity, and for a "will break" finding the
  concrete input or sequence that triggers it. A finding without evidence is a *concern* and is
  labelled so.
- Judge only what the change introduced. Pre-existing problems go in a separate "tracked" list.
  Nothing a linter, compiler or test already catches.
- End with a "Declined to judge" list: what the critic did not check and why.
- Finding ids follow the existing convention: `[Bug Hunter·Claude] BUG-1: …`, etc.; tags added
  to `team-rules.md`.
- **Disprover:** one issue per critic's finding list; each finding judged on its own: keep /
  drop / downgrade, each with evidence. When unsure, the finding is kept. When its run fails, the
  Review Lead reruns it on the fallback model (§8); it never passes findings through
  undisproved silently.
- When two critics disagree, each replies with one of: agree; disagree with code evidence; or a
  concern without evidence. The lead decides and records why.

### 4.4 What changes for Delivery QA and the Delivery Lead
- Delivery QA's `Acceptance:` keeps steps 1–3 and 5 (tests unchanged, suite passes, criteria
  met, user-like probing), and keeps the check that the Refactorer changed no behaviour (it is
  verified by running the suite, not judged). The spec-fit and standards judgement of step 4 and
  the line "you are the Claude review of everything the Codex agents produce" move to the Review
  team.
- **Review fixes** (my call): a correctness finding (one with a triggering input) gets a Delivery
  QA regression test before the developer fixes it, as security findings get one from Security
  QA — tests still come from QA. Other findings are proven fixed by the raising critic's
  re-check. A review fix round goes back through `Acceptance:` (not the Refactorer) and counts
  toward the existing third-fix-round escalation.
- **Disputes and accepted risk** (my call, mirroring the Security Lead): the Review Lead settles
  a developer's dispute of a finding; only leaving a critical or high finding open goes to the
  Principal as a `Question:`.
- The Delivery Lead, after a build issue is done, creates `Refactorer review:` as today, then
  `Review:` for the Review Lead per the task's route (in the route's order relative to any
  security review), then `Acceptance:` blocked by them. It runs `Review fixes:` the same way it
  runs `Security fixes:`, and records review findings in `review-digest`.
- The Delivery Lead's ad-hoc "architectural, domain or security problem → review child issue for
  the Cloud Architect, DDD Reviewer or Security Lead" becomes Review Lead or Security Lead.

## 5. Routing

- When writing the plan, the Principal adds a **Route** line to every plan task:
  `Route: Review(<lenses or "lead picks">) → Security(review | none)` — the order of the arrows is
  the order of the stages; `Review ∥ Security` means in parallel. A Technical Writer task's route
  is `Route: none` (Delivery QA's fact check stays).
- The Delivery Lead follows the route and never changes it.
- `Security(review)` means a per-task `Security review: <KEY-n>` from the Delivery Lead to the
  Security Lead, who picks which of its reviewers the change needs (not necessarily all three),
  consolidates as it does in a round, and sends `Security fixes:` as today. `Security(none)`
  means only Security QA's existing per-task tests and acceptance, when the task lists controls.
- **Unplanned work** (a follow-up, a fix that grows scope, a task the plan lacks a route for):
  the Delivery Lead asks the Principal with a `Question:` for a route. Fix rounds on an existing
  task reuse its route.
- The Principal's sizing step (§2 of its file) also routes the spec review through the Review
  Lead and, as today, the security reviewers. **Spec reviews** (my call): lenses allowed are Spec
  & Contract, First-Principles, History (drift from ADRs and decisions), DDD and Cloud Architect;
  findings go through the Disprover; the Review Lead returns a consolidated verdict and the
  Principal resolves it by revising the documents, as today — no fix issue.

## 6. Chronicle team

### 6.1 Chronicle Lead
- **Takes work twice per milestone** from the Principal (my call: the record must reflect the
  merge, the documents must be in the PR):
  1. `Chronicle: <milestone>` — the documents, created after the `Build:` issue is done (so
     after the security round), before the milestone PR. A Gate 3 revision that changes what a
     document says reopens it for the relevant writer.
  2. `Chronicle record: <milestone>` — the Notion record and the Mentor's "finished" sync,
     created after Mario merges the milestone PR.
- **The documents round's issue is the brief:** which documents, which audiences, which sources, and anything the Principal wants
  emphasised. The Principal decides the context; the lead does not go looking beyond it except
  in the repo and the issues it links.
- **Fans out** to its writers (and, in the record round, the Mentor), each a child issue in its own workspace from the
  milestone branch, and runs each document through Delivery QA's `Acceptance:` fact check as
  today (cross-team; my call, because the fact-check already works).
- **Notion record** (the record round; moved from the Principal): the milestone page's Progress
  log and Links, the project page's Progress log and Next steps. The Principal keeps the live
  `Status` transitions and `Last update`, because they must be true at every moment and Chronicle
  runs only at the end (my call).
- Marks its issue done with the PR(s) of the documents; the Principal merges them into the
  milestone branch and links them from the milestone PR.

### 6.2 Members
- **Technical Writer:** unchanged role. During the build, the Delivery Lead still assigns client
  document plan tasks to it directly (my call: those are build deliverables with their own route,
  and waiting for the milestone end would block runbooks). At milestone end it writes what the
  Chronicle brief asks.
- **Security Writer:** renamed **Audit Writer** (my call), scope widened from security reports
  to audit reports: the security reports as today (`docs/security/<milestone>/`) plus a review
  audit (`docs/review/<milestone>/`: findings per task, outcomes, what was tracked, residual
  concerns) from `review-digest`. The Security Lead's step 4–6 (`Security report:`) moves into
  the Chronicle round; the security round ends at the verdict.
- **Mentor:** unchanged role. Its "finished" sync is part of the record round, after the merge; its "spec
  approved" sync stays a direct issue from the Principal (it must happen mid-milestone).

## 7. Teacher

- Stays outside Chronicle, reporting to the Principal. Its teaching behaviour is unchanged.
- It can be started three ways, always as a `Help me understand: …` issue under the issue it is
  about:
  1. Mario opens it, as today.
  2. The **Principal**, when Mario's answers in a thread show he is missing context.
  3. **Claude**, when Mario talks to Paperclip through Claude (the paperclip skill) and struggles
     to follow something.
- In cases 2 and 3 the agent **offers first and waits for Mario's yes**; it never opens the issue
  on its own. The issue records who opened it and quotes the moment that prompted it.
- The Teacher's "takes work only from Mario" line becomes "from Mario, or from the Principal or
  Claude with Mario's approval".
- Where Claude's rule lives is left to the builder, with one constraint: not in a vendored copy of
  the paperclip skill that an update would overwrite.

## 8. Models

Diversity rule for the Review Lead (and the Principal when it names lenses): on any change, the
chosen critics span at least two model families, and the Disprover for a finding is never on the
critic's family. Concrete models are in §4.2; developers stay on GPT, so the default critics are
Claude and open models.

**Fallback when Ollama is unavailable or out of credits** (Mario's decision): every Ollama role
falls back to **GPT-6.1-Sol**, not to Claude. Claude capacity is kept for the most important
work. The Review Lead says in its verdict which roles ran on the fallback. Known trade-off: Sol
shares a family with the developers' GPT models, so a fallback run is more likely to go easy on
GPT-written code; the Review Lead notes this next to any finding a fallback Disprover dropped.

## 9. Left to the builder

- Exact agent instructions, titles, icons, palettes, effort levels and skills per new agent (in
  the style of the existing files); which CEK plugin files to vendor or adapt for the critics'
  methods.
- Issue and finding-id naming beyond what is fixed above.
- Updates to `configure.sh`, `team-rules.md`, `README.md`, `FINDINGS.md`, the generated
  `company/` package and `tests/team_test.sh`.
