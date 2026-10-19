# Teacher records in Notion

Mario owns the rules in his Operating Manual
(https://app.notion.com/p/3ea34fd6f09381c38f0fe423541d0b1a, sections *Knowledge Checks* and
*Where things live*); this file is the Teacher's working copy of them. Use the Notion tools in the
session (`notion-fetch`, `notion-query-data-sources`, `notion-create-pages`, `notion-update-page`).
Property names and values below are exact. Never delete or move a page and never change a
database's schema.

**Read with view mode** — the SQL quota is shared and runs out:
- Due now `view://3f934fd6-f093-81e6-8c8f-000c891013ea`
- All active checks `view://3f934fd6-f093-81f9-9861-000c21d126bf`
- Recent attempts `view://3f934fd6-f093-8156-af3e-000c8861b5b2`
- All study assignments `view://3f934fd6-f093-81c2-a387-000cf14c3522`

## What goes where

- **What you taught in the session → Knowledge Checks + Check Attempts.** Never a Study
  Assignment, even when the session closed a gap.
- **Reading Mario still has to do → a Study Assignment.** Only when a gap needs reading beyond the
  session (Wrong mechanism, Missing why, a leech), and only for material outside the session: book
  chapters, doc pages, course lessons.

## Study Assignments — `collection://6c477727-ebf6-4e9b-bcad-1e04a3f189f5`

One row = targeted reading that closes a gap: an outcome, the Library resource and the parts of it
to read, and why. Before creating one, look for an open assignment on the same resource and scope:
extend it and link the check to it instead.

| Property | Value |
|---|---|
| `Assignment` (title) | The outcome as a task: "Explain how Keycloak signs tokens and how GraphDB verifies them". Never a book name. |
| `Why` | The gap it closes, quoting the answer that exposed it ("Could not say where the issuer URL is checked"). |
| `Scope` | Per resource: chapters, sections, doc pages. Read the parts that matter, not whole books. |
| `Resource` | Relation to Learning Resources (`collection://4b04f22d-4daf-491f-af72-2f9fffb192d6`). Add the book or course to the Library first if it is missing. |
| `Status` | `Proposed` on creation. Mario moves it (`In progress` → `Finished` / `Abandoned`); you never do. |
| `Started`, `Finished` | Leave empty. Mario sets them when he starts and finishes the reading. |
| `Projects` | Relation to the project page when the topic serves one. |
| `Checks` | The checks this reading should close. |

Page (icon 📖), as in the existing assignments:
1. One line: targeted reading in <resource mention>, only the parts below; progress is tracked here.
2. **Reading plan** — to-dos, one per chapter or section, each with **Focus**, **Helps answer**
   (question numbers) and **Closes** (check mentions). Missing base knowledge becomes an optional
   prerequisite gated by a self-test ("if you can explain X without the book, skip it").
   End with "Answer the questions below without the book open" and **Done when:** every box is
   checked → Status Finished with the date.
3. **Questions to answer** — numbered, tied to his real work.
4. **Reading notes** — per chapter **Notes**, **References**, **Confusions & gaps**, left empty for
   him (his own notes live on the resource's Roam page; link it when it exists).
5. **My answers** — empty numbered list. **Session log** — empty, one line per session.

## Knowledge Checks — `collection://37f7136c-cebe-46b3-a5be-e14852d23e5c`

One row = one question he answers from memory, **one concept only**. If the answer has two parts
he could forget independently, it is two checks — no "and why", no "name the two…", no lists.
Test understanding, not commands: never ask for CLI syntax, flags or log lines; ask what to
inspect, what a result means or which decision follows.

| Property | Value |
|---|---|
| `Prompt` (title) | The question, short form. |
| `Format` | `Recall` (one fact) / `Explain` (one mechanism in his words) / `Apply` (one decision in a scenario). |
| `Origin` | `AI-drafted` |
| `Status` | `Active`. Revise, `Suspended` or `Retired` — never delete. |
| `Projects` | The project page when relevant. |
| `Topics` | Subjects from the Topics database (`collection://596f916d-971c-47ce-b9d1-8ceac5652ab2`). |
| `Sources` | The Learning Resources the answer comes from, when there is one. |
| `Practices` | The Practice Library card it exercises, when there is one. |
| `Study` | The Study Assignment whose reading it checks; empty for checks on what you taught. |
| `Latest score`, `Interval (days)`, `Next review` | Set when an attempt is logged (below). |

Page (icon ⚡): `**Context:** <one line: client or project, where it came from>`, then the answer
in a toggle titled `🔑 Answer`.

## Check Attempts — `collection://19c48e12-c9f8-4cf0-9bac-7fa522eb9656`

One row = one answer Mario gives to a check.

| Property | Value |
|---|---|
| `Attempt` (title) | `<check prompt> — <YYYY-MM-DD>` |
| `Check` | Relation to the Knowledge Check. |
| `Date` | Today. |
| `Grade` | `Again` / `Hard` / `Good` / `Easy` — every attempt gets one. |
| `Score` | Again 0, Hard 5, Good 8, Easy 10. |
| `Gap type` | Zero or more of `Missing fact`, `Wrong mechanism`, `Imprecise`, `Missing why`, `Could not apply`. |
| `Studied before` | True only when a linked Study Assignment was already `Finished` by Mario. |

Page: his verbatim answer, then your feedback (link any study with a page mention).

**Grade the mental model, generously:** the right model in his own words is Good even with details
missing; precision gaps get one short note, not a lower grade.

**Schedule** — then set `Latest score`, `Interval (days)`, `Next review` = today + interval:

| Grade | First review | Later reviews |
|---|---|---|
| Again | 1 day | reset to 1 day |
| Hard | 2 days | interval × 1.2 (at least +1 day) |
| Good | 4 days | interval × 2.5 |
| Easy | 7 days | interval × 3.5 |

Cap 180 days. **Leech:** 4+ attempts with the latest still Again → split or rewrite it and propose
study; don't just repeat it.

## Comments on his pages

Your notes on his pages are gray callouts with a 🤖 icon, placed right under the note they answer.
Never edit his own text.

## Session routine

- **Start:** read Due now and the open Study Assignments for the topic (view mode). Open with due
  checks before new material.
- **End:** create checks for the concepts you taught (one concept each, mixed formats, with Context
  and Answer), log every attempt with its page, and update each check's schedule. Propose a Study
  Assignment only for reading he still has to do, or extend the open one. Close with the links to
  what you created.
