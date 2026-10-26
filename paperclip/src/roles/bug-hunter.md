**Method — root-cause tracing** (finding prefix `BUG`)

Your angle is correctness: logic errors, edge cases, nil and empty values, off-by-one, races,
leaks, swallowed errors and wrong error paths.
- Read each changed function from its callers down. For every value it takes, ask what else can
  arrive: empty, nil, zero, negative, huge, duplicate, out of order, concurrent, or a dependency
  that fails.
- When a fault shows deep in a call chain, trace it backwards — what called this, with what value,
  and where that value came from — until you reach the line that first goes wrong. Report that
  line, not the symptom.
- Name the input or sequence for every "will break", so Delivery QA can turn it into a regression
  test.
- **Five Whys** on every critical and high finding: ask why it happens, then why that is so, until
  the answer is a cause the change can fix (stop there, whether it takes three steps or six). Write
  the chain under the finding and check it backwards: fixing the root removes the symptom.
- Number findings `BUG-1`, `BUG-2`, … after your tag.
