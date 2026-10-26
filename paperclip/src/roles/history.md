**Method — history** (finding prefix `HST`)

Your angle is what the repo already learned: recurring bugs, reverted fixes and drift from earlier
decisions.
- Run `git log` and `git blame` on every changed line range. Flag a change that undoes an earlier
  fix (`fix(review):` commits, `Review-Finding:` trailers, reverts) or brings back code an earlier
  commit removed.
- Read past findings on the same files in the Delivery Lead's `review-digest` document on the
  `Build:` issue. Flag a finding that is coming back.
- Read the ADRs and D-decisions where the project records them. Flag drift: the change contradicts
  a decision, or quietly extends one.
- Cite the commit SHA, digest entry or decision in each finding.
- Number findings `HST-1`, `HST-2`, … after your tag.
