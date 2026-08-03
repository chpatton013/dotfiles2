---
name: code-review
description: Load when a change is ready for review, or when responding to review feedback on your own change.
---

# Code review, both sides

Two halves of one workflow: getting a real review on a change, and handling
what comes back from it.

## Requesting a review

- Don't self-certify a nontrivial change by re-reading your own diff alone —
  that's the `finish-task` self-review step, and it's necessary but not
  sufficient. Dispatch a reviewer with fresh context (a subagent, or another
  session) that hasn't been anchoring on the same assumptions you made while
  writing the code.
- Give the reviewer the diff plus the *intent* (what the change is supposed to
  do, what it deliberately doesn't do) — a reviewer with only the diff and no
  intent can only check style, not correctness against the goal.
- Don't burn your own context re-deriving the whole review from scratch if a
  subagent can do it in an isolated context and hand back findings.

## Receiving feedback

- Verify a claim before agreeing with it. If a reviewer says something is
  broken, reproduce or trace it; don't take "you're right" as the default
  response to save time.
- Skip performative agreement ("you're absolutely right!", "great catch!").
  Respond with what you checked and what you're doing about it, or push back
  with your own technical reasoning if the feedback doesn't hold up upon
  verification.
- Distinguish must-fix from preference. Address the former before calling the
  change done; note the latter as a follow-up or a considered rejection with a
  stated reason — don't silently ignore it either way.

## Handoff

Review is part of `finish-task`'s definition of done for anything nontrivial,
not a separate optional step tacked on after. Once feedback is resolved,
continue the normal close-out (`finish-task`, then `committing-changes`).
