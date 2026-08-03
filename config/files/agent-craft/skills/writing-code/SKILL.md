---
name: writing-code
description: Load when writing the code for a slice of work, from a plan or otherwise — before you start editing.
---

# Writing code

You have a plan; this is how to work through it. The throughline is **small,
verified increments, each shipped and reviewed before the next** — never a big
bang. Build the smallest thing that works end-to-end, then grow it (Gall's law).

This is the engineering methodology *within* a slice. For the session/subagent
mechanics of working through a multi-task plan — worktree setup, tracking
todo-per-task, when to stop and ask — see `executing-plans`; the two are
complementary, not overlapping.

## 1. Slice the work small (agile + release-early-often)

- Break the plan into the smallest increments that each deliver a *working,
  testable* end-to-end slice — not horizontal layers you can't run. Prefer a
  thin vertical slice that does one real thing over a half-built subsystem.
- Order slices by value and risk: do the riskiest/most-uncertain slice early so
  you learn before you've built on a bad assumption.
- After each slice, get it to a shippable/mergeable state and stop to check in
  (the per-slice close-out is the `finish-task` + `committing-changes`
  skills). Frequent
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

**Iron Law: no production code without a failing test that requires it
first.** This is not a style preference — it's the only reliable way for this
skill to know a behavior is actually needed and actually works, rather than
being asserted. If you catch yourself about to write implementation code with
no failing test driving it, stop and write the test first.

For every slice, work the red-green-refactor loop, but frame the tests as
*behavior* in the ubiquitous language rather than implementation detail:

1. **Red** — write one failing test that specifies the next behavior, phrased
   as a scenario: given some context, when an event happens, then an outcome.
   Describe *what* should happen, not *how* the internals do it. Watch it fail
   for the reason you expect (a missing behavior, not a typo).
2. **Green** — write the minimal code to pass. No speculative extras (YAGNI).
3. **Refactor** — with the test green, clean up names, duplication, and
   coupling (apply the `software-design` skill). Re-run the tests.
4. Repeat for the next behavior.

This works outside-in: start from the observable behavior a user/caller wants
and let it pull the implementation into existence. The accumulating tests become
executable, living documentation of what the system does — and a safety net that
makes the frequent shipping in step 1 safe.

**Rationalizations to reject, not accept, when they show up in your own
reasoning:**

- "This is too simple to need a test" — simple code still breaks; the test is
  cheap precisely because the code is simple.
- "I'll write the test after, it's basically the same thing" — it isn't: a
  test written after the fact is confirming what the code does, not
  specifying what it must do, and it silently forgives whatever the code
  already got wrong.
- "I'm just prototyping/exploring" — fine, but say so explicitly and treat the
  result as disposable; don't let exploratory code quietly become the shipped
  implementation without ever getting a test-first pass.
- "This is generated/config, not logic" — genuinely generated code and pure
  declarative config are legitimate exceptions; confirm that's actually what
  this is before waving the rule off, and call out the exception when you take
  it rather than letting it pass silently.

## 4. Close out and iterate

- When a slice's behaviors are green and refactored, run the `finish-task`
  checklist (full verify, docs, self-review, follow-ups) and, if coherent,
  `committing-changes`.
- Then pick the next slice. Fold anything you learned back into the plan and the
  domain model. Keep the loop tight; keep the system working at every step.

## The loop in one line

Slice small → name the domain → red/green/refactor as behavior → finish-task +
commit → adapt the plan → next slice.
