# Keystone: two QAs, QA-written tests, and security reports — Design

**Date:** 2026-10-26 · **Status:** approved 2026-10-26 · **Author:** Mario + Claude (brainstorm)

Builds on `2026-10-18-paperclip-agent-team-design.md` and the team as it stands at `bbcab1d`
(Delivery Lead, Technical Writer and Cloud Architect Advisor included). The team lives in
`paperclip/`: agent instructions in `src/agents/*.md`, shared rules in `src/team-rules.md`,
generated package in `company/`, applied with `configure.sh`.

## 1. Intent

Today developers write their own tests and one QA reviews afterwards. A developer can write tests
that pass for the wrong reason, and nobody owns proving that security controls exist and keep
working. Security rounds also end with findings scattered across issues, with no document Mario
or the client can read.

Mario wants:

- **The tests to come from QA, not from the developers.** Developers write code that satisfies
  requirements and tests they didn't write and can't change.
- **Two QAs, each specialised for its team:** one in the Delivery Team that owns the test
  framework and checks the build against requirements and design; one in the Security Team that
  writes the tests proving the security controls hold, and keeps every security finding fixed.
- **Security reports as documents** at the end of a security round: separate Markdown documents
  for Mario, and a small one for the client.

## 2. Goals, non-goals, anti-goals

**Goals**
- QA writes the contract tests before implementation; developers implement until they pass.
- A second QA sweep after implementation proves the requirements are met and QA's tests were not
  modified to pass falsely.
- Every security control in the spec has a test; every security finding gets a regression test
  before its fix.
- A deployment test suite that stands up the whole system in a local environment and checks it
  works, which a person can also run against AWS.
- At the end of a security round: three internal documents for Mario and one client document.

**Non-goals (for now)**
- Automated runs against AWS, and a sandbox AWS account for agents. Mario or a Graphwise
  colleague runs the suite against cloud test by hand. Automation comes later.
- A detailed client security report (method, attack steps). Mario will refine the reports after
  reviewing a few.
- Unit tests for Terraform.

**Anti-goals** (failure even if it works)
- Developers able to change, skip or weaken QA's tests, by any route, without QA making the change.
- A QA that fixes product code: the tester must stay independent of whoever ships.
- Agents holding cloud credentials or running `terraform apply` against a real account.
- Reports that state anything not traceable to a finding, a verdict or a test result.

## 3. The team after the change

```
Mario (board)
└─ Principal Architect
   ├─ Delivery Lead
   │  ├─ Developer 1, Developer 2, Platform Engineer, Refactorer, Technical Writer
   │  └─ Delivery QA            ← today's QA Engineer, moved and reshaped
   ├─ Security Lead
   │  ├─ Security·Codex, Security·Claude, Security·DeepSeek, Red Team Engineer
   │  ├─ Security QA            ← new
   │  └─ Security Writer        ← new
   ├─ Cloud Architect, DDD Reviewer, Cloud Architect Advisor, Research Scout
   └─ Mentor, Teacher
```

Mario decided: Delivery QA moves to the Delivery Team; Security QA and Security Writer join the
Security Team. (This reverses the earlier choice to keep QA under the Principal for independence;
independence now comes from QA owning the tests and developers being unable to change them.)

| Agent | Runtime · model · effort (Claude's call) | Why |
|---|---|---|
| Delivery QA | Claude · Sonnet 5.5 · **high** (today medium) | It now writes test code and the framework |
| Security QA | Claude · Sonnet 5.5 · high | Claude-written tests for Codex-written code keeps two model families on every task |
| Security Writer | Claude · Opus 5.5 · high | Same quality bar as the Technical Writer; runs once per round |

## 4. Tests: who writes what

| Owner | Tests | Where (Claude's call) |
|---|---|---|
| Delivery QA | Test framework (fixtures, local environment setup, how tests run); acceptance and integration tests per plan task; the deployment test suite | `tests/acceptance/`, `tests/deploy/`, `tests/framework/` |
| Security QA | Security tests: scanner configuration, Terraform plan assertions, refused requests, post-deploy security checks; one regression test per security finding | `tests/security/` |
| Developers | Optional unit tests where they help (parsers, rules, calculations). Never evidence. | Next to the code, as the language expects |

- **Language:** Go. Terratest for the deployment suite; `terraform test` (plan, mock providers)
  for plan assertions. Mario decided: tests in Go, no unit tests for Terraform.
- **Terraform test levels:** static checks (`validate`, `fmt`, `tflint`; security scanners such as
  `checkov`, `trivy config`), plan tests, and deployment tests. No unit tests.
- **Locked tests:** developers and the Refactorer never create, edit, move or delete anything under
  `tests/acceptance/`, `tests/deploy/`, `tests/framework/` or `tests/security/`. The acceptance
  sweep checks this mechanically: `git diff <tests commit>..HEAD -- <those paths>` must be empty.
- **Security scanners and linters** the QAs need (`tflint`, `checkov` or `trivy`, `gitleaks`,
  `k3d` or `kind`, `helm`, `kubectl`) are installed through mise in `dotfiles/`. `kind` is already
  there. Which scanner set exactly is the builder's call.

## 5. Environments

| Environment | Who runs the suite | When |
|---|---|---|
| Local: Docker plus a local Kubernetes cluster (k3d or kind) | Agents: Delivery QA, Security QA | Every task, fix round and acceptance sweep |
| Cloud test (real AWS) | Mario or a Graphwise colleague, by hand, with his credentials | After each real apply |
| Live | The Graphwise operator | After go-live and each change |

The same suite runs everywhere; only the target changes (configuration through the environment).
Agents never hold cloud credentials and never apply to a real account (unchanged rule). Each run's
result is recorded on the relevant issue; a manual cloud run is recorded by whoever ran it.

## 6. The build flow per plan task

Mario decided steps 1–5; issue names and wiring are Claude's call, following today's Delivery Lead
conventions (each step its own issue, in the build issue's workspace).

1. **Tests first.** The Delivery Lead creates `Tests: <task>` for Delivery QA and, when the plan
   task lists security controls, `Security tests: <task>` for Security QA. Each writes failing
   tests from the plan task's requirements and commits them on the task branch. The tests commit
   SHA is recorded on the issue.
2. **Implementation.** The build issue (blocked by step 1) goes to a developer, who implements
   until QA's tests pass, plus any unit tests of their own.
3. **Refactorer**, unchanged.
4. **Acceptance sweep.** `Acceptance: <KEY-n>` for Delivery QA and, when step 1 had security tests,
   `Security acceptance: <KEY-n>` for Security QA. Each checks:
   - its tests are unchanged since the tests commit (the `git diff` above is empty);
   - its tests pass, run by itself, locally;
   - every requirement in the plan task is met, and the result matches the design (Delivery QA);
   - nothing else regressed: the full suite passes.
   Verdict PASS or FAIL on its own issue, as today.
   Delivery QA's sweep also keeps everything today's `QA review:` does: the code against the spec
   and coding standards, anything extra or behaviour-changing the Refactorer did, and exploratory
   edge cases (empty and oversized input, restarts, missing configuration). It remains the Claude
   review of everything the Codex agents produce. *(Claude's call.)*
5. **Delivery Lead decides**, as today: merge on PASS, fix round on FAIL.

**Before the developer starts** *(Claude's call)*: each `Tests:` and `Security tests:` issue ends
with a table mapping every acceptance criterion or security control to the test that covers it.
The Delivery Lead checks that table in the run where it would start the developer, so no extra
run is added; a criterion with no test goes back to the QA.

**What counts as QA's tests** *(Claude's call)*: the locked paths in §4 plus whatever decides how
they run: the Makefile or script targets that run them, their build tags, and CI configuration
for them. The acceptance sweep's `git diff` covers all of it. Protection is detection at the
sweep, as Mario described it ("validates that tests are not changed"); no hooks or protected
paths for now.

**Bootstrapping a repo** *(Claude's call)*: the first time a repo uses this flow, the Delivery
Lead creates one `Test framework: <repo>` issue for Delivery QA (framework, local environment,
how tests run) before any `Tests:` issue. Existing developer-written tests stay where they are as
unit tests.

**Security findings** (from reviewers or the Red Team, any time): the Security Lead creates
`Security regression: <finding id>` for Security QA, which writes a failing test reproducing the
finding; then the Delivery Lead runs the fix round; Security acceptance proves the test passes
for the right reason. *(Claude's calls:)*
- Only findings that will be fixed and can be reproduced against code or a running system get a
  regression test. Findings accepted as residual risk get none; they go into `risks.md`. A
  spec-review finding gets its test when the task that implements the control is built (it
  becomes one of that task's security controls).
- A finding on a task not yet merged is fixed in that task's workspace. A finding raised after
  the merge gets a new build issue from the milestone branch, created by the Delivery Lead.
- The Security Lead hands the findings to fix to the Delivery Lead as one issue
  `Security fixes: <finding ids>`, assigned to the Delivery Lead, with each finding and its
  regression test. The Security Lead still does no resourcing; the Delivery Lead does.

**When a developer believes a QA test is wrong** (Mario decided the shape):
- The developer raises a `Question:` naming the test and the reason, and never touches the test.
- It goes to the Delivery Lead for Delivery QA tests, to the Security Lead for Security QA tests,
  and to the Principal Architect when it means changing a requirement, the spec, or a
  security-versus-feature decision. (The routing between the leads is Claude's reading of
  Mario's "Lead or Principal".)
- If they agree the test is wrong, the QA that owns it changes it, with a new tests commit SHA.
  If not, the developer makes it pass as written.

**Plans** (Principal Architect): each plan task lists its acceptance criteria and the security
controls it implements, so the Delivery Lead knows which test issues to create.

## 7. Security reports

**When** *(Claude's calls)*: one build-time security round per milestone that has security scope
(the plan lists security controls). The Delivery Lead asks the Security Lead for it after the
last plan task is merged and before it hands the build back, and the hand-back waits for the
round (including its fix rounds). Spec-only reviews produce no reports. One report set per
milestone.

At the end of that round, after the Security Lead's consolidated verdict and the Principal's
decisions, the Security Lead creates `Security report: <milestone>` for the Security Writer.

**Sources:** the Security Lead's verdict; the reviewers' and Red Team's findings with reproduction
steps; Security QA's test results and regression tests; each fix's outcome. Every statement
traces to one of them (a sources table, as the Technical Writer keeps). The writer decides and
invents nothing.

**Where** (Mario decided): in the same repo the team works in, under `docs/`. That repo is Mario's
own lab repo, not a client repo; he creates the product repo from it later. The files go under
`docs/security/<milestone>/` *(path Claude's call)* on the milestone branch, and Gate 3 links
them. The Security Writer commits on its own issue branch like any writer, and needs the same
push access as the Technical Writer.

**Documents, separate Markdown files** (Mario decided: separate, Markdown; file names Claude's
call):

| File | Reader | Content |
|---|---|---|
| `internal/test-report.md` | Mario | What was tested, where (local, cloud test by hand), how, and the results |
| `internal/exposures.md` | Mario | Each exposure: id, severity, **how it was found** (steps), impact, fix or reason left open, regression test |
| `internal/risks.md` | Mario | Residual risks: what remains, why accepted or not, owner |
| `client/exposure-report.md` | Client | Each exposure, severity, and status: **fixed** or **not addressed**. Nothing else for now. |

The client document follows the Technical Writer's house style (no internal names, ids, agents or
attack steps). QA checks the client document's facts as it does any client document today.

## 8. What changes in `paperclip/`

- **New agents:** `security-qa.md`, `security-writer.md` (both `reportsTo: "security-lead"`).
- **QA → Delivery QA:** rewrite `qa.md` for the new role (tests first, framework, acceptance
  sweep, client-document fact checks kept), `reportsTo: "delivery-lead"`, name and title changed.
- **Developers and Platform Engineer:** implement against QA's tests; never touch locked test
  paths; unit tests optional; disputes as in §6. Developer step 2 (write your own failing test)
  goes.
- **Refactorer:** its "never touch a test file" rule also covers the locked paths (already does).
- **Delivery Lead:** the §6 flow and issue names.
- **Security Lead:** two new reports; regression-test issues for findings; the report round.
- **Principal Architect:** plan tasks list acceptance criteria and security controls; Gate 3
  links the security reports when there was a security round.
- **Team rules:** locked test paths; the dispute path; QA tags (`[Delivery QA]`, `[Security QA]`).
- **`configure.sh`, `.paperclip.yaml`, README:** new agents, the renamed QA, reporting lines.
- **`dotfiles/`:** the mise tools in §4.

## 9. Constraints for the builder

- `configure.sh` finds agents **by name**. Renaming "QA Engineer" to "Delivery QA" in the package
  alone would make it look missing and import a duplicate: rename the live agent first (or teach
  `configure.sh` the rename), then apply.
- The Delivery Lead must be able to assign `Security tests:` and `Security acceptance:` issues to
  Security QA, outside its own reporting subtree. Verify Paperclip allows it (agents already
  assign `Question:` issues across the tree); if not, route those through the Security Lead.
- **Rollout** (Mario decided): build and apply the new agents first. Then the first use is a
  security round with a report and analysis on the existing work, so Mario sees the reports and
  can refine them. In-flight issues are not re-planned; the new build flow applies to tasks
  planned after the change.
- **Test framework location** (Mario decided): in the same repo as the code it tests, under
  `tests/` (§4).

## 10. Left to the builder

- Exact scanner set and versions; Terratest layout; how the local environment is created per
  project (scripts, Makefile targets).
- Wording of every agent's instructions, in the style of the existing ones.
- Order of the changes and how to stage them safely.
