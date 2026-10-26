---
name: paperclip-teacher-offer
description: Use when talking with Mario about Paperclip/Keystone work and he signals he does not follow a concept, a design or a proposal, and you should offer him a Paperclip Teacher session rather than teach yourself. Skip it when Mario explicitly asks to be taught or to learn now; the `teacher` skill covers that.
---

# Paperclip Teacher Offer

## Overview

When Mario struggles to follow something in Paperclip/Keystone work, offer him a Teacher session.
The Teacher is a Paperclip agent that teaches from his real issue. Never start it without his yes.

## Steps

1. **Offer in one line**, naming the concept ("Want a Teacher session on <concept>?"), and wait for
   an explicit yes. If he answers "just explain it here" or declines, use the `teacher` skill in chat instead. Silence, "hm" or a follow-up question about something else is not a yes. Never
   create the issue without it.
2. **On yes**, use the `paperclip` skill (read it; do not edit it) to create a child issue
   (`POST /api/companies/{companyId}/issues` with `parentId`, and `assigneeAgentId` set to the
   Teacher):
   - Parent: the Keystone issue being discussed. If it is not clear which one, ask Mario.
   - Title: `Help me understand: <topic>`.
   - Assignee: the Teacher. Assign it; a mention does not wake an agent, an assigned child issue does.
   - Description:
     - `Opened by: Claude`
     - the moment that prompted it, quoted in Mario's own words
     - links to the parent issue and the documents or comments the concept comes from
3. **Reply with the issue link** and nothing more to explain; the Teacher takes it from there.
