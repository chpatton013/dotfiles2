---
name: writing-plans
description: Load when authoring a plan document for a multi-step feature or task, before implementation starts.
---

# Writing a plan

This is for turning an approved approach (see `brainstorming`) into a
document you or another session can execute from. It assumes the *what* and
*why* are already decided — this is about shaping the *how* into sized,
ordered steps.

## Where the plan lives

Use the project's own plan-storage convention if it has one — check for an
existing `docs/plans/` (or equivalent) directory and its naming pattern first,
and match it. This repo, for example, keeps plans at `docs/plans/<name>.md`
(no date prefix, pruned once done) — follow that here.

If the project has no established convention, default to
`docs/plans/YYYY-MM-DD-<feature-name>.md`. The date prefix avoids collisions
and ambiguity in a project that hasn't settled this yet; don't invent a
different scheme.

## Required shape

- **A metadata header**: what this plan is for, the approach it implements
  (link back to the brainstorming note if one exists), and its current status.
- **Bite-sized tasks.** Each task should be independently completable and
  verifiable in one sitting — small enough that `writing-code`'s red-green-
  refactor loop covers it in a handful of cycles, not a whole subsystem in one
  step. If a task needs "and" to describe, split it.
- **Explicit ordering**, with the riskiest or most uncertain task placed early
  so a bad assumption surfaces before you've built on top of it.
- **A definition of done per task** — what observably changes, how it's
  verified — not just a description of the work.

## Self-review before handing it off

Re-read the plan as the person who has to execute it cold:

- Does every task stand alone, or does it silently depend on undocumented
  context?
- Is anything sized too large to finish and verify in one sitting?
- Does the ordering actually front-load risk, or did convenience order it
  instead?
- Is the metadata header enough for someone with no other context to know
  what this plan is trying to achieve?

## Handoff

Once the plan reads clean, hand off to `executing-plans` for the session/
subagent mechanics of working through it, and `writing-code` for the
engineering methodology within each task.
