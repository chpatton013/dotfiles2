---
name: execute-plan
description: Load when working through a multi-step plan, spec, or feature — how to actually execute software work, not what to build. A practical loop synthesizing agile/release-early-often (small increments, ship often), domain-driven design (model with a ubiquitous language), and test-driven + behavior-driven development (drive each change test-first, framed as behavior). Pairs with the software-design skill (principles) and the finish-task/commit skills (the per-change close-out).
---

# Executing a plan

You have a plan; this is how to work through it. The throughline is **small,
verified increments, each shipped and reviewed before the next** — never a big
bang. Build the smallest thing that works end-to-end, then grow it (Gall's law).

## 1. Slice the work small (agile + release-early-often)

- Break the plan into the smallest increments that each deliver a *working,
  testable* end-to-end slice — not horizontal layers you can't run. Prefer a
  thin vertical slice that does one real thing over a half-built subsystem.
- Order slices by value and risk: do the riskiest/most-uncertain slice early so
  you learn before you've built on a bad assumption.
- After each slice, get it to a shippable/mergeable state and stop to check in
  (the per-slice close-out is the `finish-task` + `commit` skills). Frequent
  small commits isolate failures and make progress real. "Working software is
  the primary measure of progress" — a running slice beats a big unmerged branch.
- Plan enough to start confidently, then expect to adapt. When a slice teaches
  you something, update the plan rather than plowing ahead on the stale one —
  surface the change, don't hide it.

## 2. Model the domain first (DDD)

- Before coding a slice, name its concepts in the domain's own words and use
  that **ubiquitous language** everywhere — class, function, and variable names
  should read like the business/problem does. Reuse the terms the code and any
  existing docs already establish; don't invent synonyms.
- Keep boundaries explicit: identify the bounded context you're working in and
  don't let its model leak into or entangle with a neighbor's. Distinguish
  entities (identity), value objects (immutable data), and aggregates (a root
  that guards its internals) when they clarify the model.
- Let the domain model drive the code structure, not the framework or the
  database. Keep domain logic separate from infrastructure/IO.

## 3. Drive each change test-first as behavior (BDD = TDD + DDD)

For every slice, work the red-green-refactor loop, but frame the tests as
*behavior* in the ubiquitous language rather than implementation detail:

1. **Red** — write one failing test that specifies the next behavior, phrased
   as a scenario: given some context, when an event happens, then an outcome.
   Describe *what* should happen, not *how* the internals do it. Watch it fail.
2. **Green** — write the minimal code to pass. No speculative extras (YAGNI).
3. **Refactor** — with the test green, clean up names, duplication, and
   coupling (apply the `software-design` skill). Re-run the tests.
4. Repeat for the next behavior.

This works outside-in: start from the observable behavior a user/caller wants
and let it pull the implementation into existence. The accumulating tests become
executable, living documentation of what the system does — and a safety net that
makes the frequent shipping in step 1 safe.

## 4. Close out and iterate

- When a slice's behaviors are green and refactored, run the `finish-task`
  checklist (full verify, docs, self-review, follow-ups) and, if coherent,
  `commit`.
- Then pick the next slice. Fold anything you learned back into the plan and the
  domain model. Keep the loop tight; keep the system working at every step.

## The loop in one line

Slice small → name the domain → red/green/refactor as behavior → finish-task +
commit → adapt the plan → next slice.
