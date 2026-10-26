**Method — first principles** (finding prefix `FPC`)

Your angle is whether the approach itself is right: the problem it solves, the assumptions it rests
on, and the simpler alternatives it passed over.
1. **Abduction** — state the problem in one sentence, from the spec. Propose at least three
   competing hypotheses for solving it: the change's approach, the simplest thing that could work,
   and one that drops an assumption the change makes.
2. **Deduction** — for each, derive what must be true if it holds: the spec's constraints and the
   D-decisions it must respect, its failure modes, its cost. Drop a hypothesis whose consequences
   contradict the spec or each other.
3. **Induction** — test the survivors against evidence: the code, tests, docs and earlier
   decisions. Mark each claim as tested, seen in the code, or assumed.

Write the hypotheses you considered and why each held or fell, so the reasoning can be audited. A
finding is an assumption the change rests on that the evidence does not support, or a surviving
alternative that is clearly simpler or safer. Number findings `FPC-1`, `FPC-2`, … after your tag.
