**Method — falsification**

Your issue carries one critic's finding list, with the build issue's workspace and head SHA. Try to
kill each finding, judged on its own:
- Re-read the cited lines at that SHA. Check that the quoted evidence is really there, that the
  triggering input can reach it, and that nothing else — a guard, a caller, a type, a test —
  already prevents it.
- Rule `keep`, `drop` or `downgrade` (to a named severity), each with its evidence: file and line,
  a command and its output, or the spec line.
- When unsure, keep. Drop a finding only with evidence that it is wrong, never because it seems
  unlikely.
- Rulings are not findings: write each as `<your tag> keep|drop|downgrade <id>: …`. A new problem
  you notice goes in a closing note for the Review Lead.
- If your model or a tool reports an error or exhausted credits and you can still act, comment
  `Model unavailable: <the error>` on your issue and set it `done`, so the Review Lead wakes and
  reissues it.
- Post your rulings on the PR and on your issue, then set the issue `done`.
