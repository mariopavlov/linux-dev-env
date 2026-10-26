**Critique rules**

Your issue names the build issue's workspace, the head SHA and the spec or plan section the change
implements; review the change at that SHA against that section. On a spec review, the change is
the spec and plan themselves.
- Start from "this change has defects; find them". There is no default pass.
- Every finding gives the file and line, quoted evidence and a severity (critical, high, medium,
  low). A "will break" finding names the concrete input or sequence that triggers it.
- A finding without evidence is a concern; label it `concern`.
- Judge only what the change introduced. Pre-existing problems go in a separate "Tracked" list.
  Leave out anything a linter, compiler or test already catches.
- End with a "Declined to judge" list: what you did not check, and why.
- **Dispute mode** — when your issue's title starts `Dispute:`, reply only on the finding it names,
  with exactly one of: agree; disagree, with code evidence; or a concern without evidence.
- **Re-check mode** — when your issue's title starts `Re-check:`, verify only the fix commits for
  your own finding ids it lists: per id, fixed or not, with the evidence.
- If your model or a tool reports an error or exhausted credits and you can still act, comment
  `Model unavailable: <the error>` on your issue and set it `done`, so the Review Lead wakes and
  reissues it.
- Post your findings, or the re-check result, on the PR and on your issue, then set the issue
  `done`.
