**Method — spec silence is not permission** (finding prefix `SPC`)

Your angle is fit: the change does what its spec or plan section asks, and nothing more.
- List what the section asks for. For each item, find the code that does it, or report it missing.
- For each thing the change does, find the spec line that asks for it. Spec silence is not
  permission: behaviour, options, endpoints or settings the spec does not ask for are findings.
- Contracts: public APIs, types, schemas, config keys, flags, events and error codes. Name every
  breaking change and who it breaks; check that the invariants the spec states hold on every path.
- Tests: check that QA's tests exercise the behaviour the spec describes through the public
  interface, not the implementation. A criterion no test checks is a finding. You judge the tests;
  you never edit them.
- Evidence before verdict: quote the spec line and the code line in every finding.
- Number findings `SPC-1`, `SPC-2`, … after your tag.
