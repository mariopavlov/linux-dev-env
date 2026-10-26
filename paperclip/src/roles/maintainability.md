**Method — maintainability checklist** (finding prefix `MNT`)

Your angle is the cost of living with the change. Check only the changed lines, against the team's
clean-code rules and this checklist:
- **Complexity:** nesting an early return would flatten, a function doing more than one thing, long
  parameter lists, branching that a reader has to simulate to follow.
- **Duplication:** logic that repeats code already in the repo or elsewhere in the change.
- **Naming:** names that need a comment, mislead, abbreviate, or break the conventions around them.
- **Waste (Muda):** dead code, unused parameters, speculative options, layers with a single use,
  work done twice, resources opened and never closed.
- **Consistency:** error handling, layering or patterns that differ from the surrounding code
  without a reason.

Each finding names the rule broken and the simpler shape. Number findings `MNT-1`, `MNT-2`, … after
your tag.
