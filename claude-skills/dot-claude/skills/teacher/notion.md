# Teacher records in Notion

Three data sources. Use the Notion tools available in the session (`notion-query-data-sources`,
`notion-create-pages`, `notion-update-page`). Property names and values below are exact.

## Study Assignments — `collection://6c477727-ebf6-4e9b-bcad-1e04a3f189f5`

One row per study outcome.

| Property | Value |
|---|---|
| `Assignment` (title) | The outcome as a task: "Explain how Keycloak signs tokens and how GraphDB verifies them". Never a book name. |
| `Why` | The gap it closes, from the diagnostic ("Could not say where the issuer URL is checked"). |
| `Scope` | Per resource: chapters, sections, doc pages. |
| `Status` | `Proposed` → `In progress` → `Finished` / `Abandoned` |
| `Started`, `Finished` | Dates when they happen. |
| `Projects` | Relation to the project page when the topic serves one. |
| `Resource` | Relation to Learning Resources when the resource is there. |

## Knowledge Checks — `collection://37f7136c-cebe-46b3-a5be-e14852d23e5c`

One concept per check.

| Property | Value |
|---|---|
| `Prompt` (title) | The question, short form. |
| `Format` | `Recall` (one fact) / `Explain` (one mechanism in his words) / `Apply` (one decision in a scenario) |
| `Origin` | `AI-drafted` |
| `Status` | `Active` (or `Suspended` / `Retired` — never delete) |
| `Study` | Relation to the Study Assignment it came from. |
| `Projects` | Relation to the project page when relevant. |
| `Latest score`, `Interval (days)`, `Next review` | Set after each attempt (below). |

## Check Attempts — `collection://19c48e12-c9f8-4cf0-9bac-7fa522eb9656`

One row per answer Mario gives to a check.

| Property | Value |
|---|---|
| `Attempt` (title) | `<check prompt> — <YYYY-MM-DD>` |
| `Check` | Relation to the Knowledge Check. |
| `Date` | Today. |
| `Grade` | `Again` / `Hard` / `Good` / `Easy` — every attempt gets one. |
| `Score` | Again 0, Hard 5, Good 8, Easy 10. |
| `Gap type` | Zero or more of `Missing fact`, `Wrong mechanism`, `Imprecise`, `Missing why`, `Could not apply`. |
| `Studied before` | True when a linked Study Assignment was Finished before this attempt. |

After logging an attempt, update the check: `Latest score` = the score; `Interval (days)` =
1 for Again, previous × 1.2 (min 2) for Hard, previous × 2.5 (min 3) for Good, previous × 3.5
(min 5) for Easy; `Next review` = today + interval.

## Session routine

- **Start:** query Study Assignments with `Status` = `In progress` and Knowledge Checks whose
  `Next review` ≤ today for the topic. Open with due checks before new material.
- **End:** create checks for concepts taught (one per concept, mixed formats), log every attempt
  made in the session, and create or update the Study Assignment.
