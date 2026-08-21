---
name: subagent-driven-development
description: Load when orchestrating a multi-task plan by dispatching subagents rather than doing every task in the current session.
---

# Orchestrating work through subagents

This is the methodology for being the orchestrator: dispatching per-task
subagents, reviewing their output, and keeping the overall effort recoverable
across context resets. The harness (`isolation: worktree` and similar)
provides the mechanics; this is how to use it well.

## One subagent per task, isolated

- Give each dispatched subagent one task from the plan and enough context to
  execute it without re-deriving the whole plan (the specific files, the
  specific done-criteria, links to any design note). A subagent that has to
  guess at scope will guess wrong in both directions.
- Dispatch subagents in a backgrounded, non-blocking mode so as to remain
  responsive to prompts from the user. Never await subagent results in a
  blocking manner; instead use periodic monitoring checks to be able to respond
  to either agent completion or subsequent user prompts.
- Prefer separate worktree isolation for multiple subagents that touch files, so
  parallel or sequential subagents don't collide on the same working tree.

## Mandatory review gates

- Never fold a subagent's result in unreviewed. Treat its summary as a claim,
  not a fact — check the actual diff before reporting the work as done (see
  `code-review`).
- A subagent that reports success but whose diff doesn't match the claim is a
  signal to dispatch a fix, not to paper over the mismatch and move on.

## Keep a persistent ledger

- Track per-task status (not started / dispatched / reviewed / done) somewhere
  that survives your own context compaction — the plan document itself
  (`writing-plans`/`executing-plans`) or a todo list durable enough to
  reconstruct "what's left" without re-deriving it from scratch.

## Escalate capability on repeated failure

- If a dispatched subagent fails the same task two or more times, don't just
  redispatch the identical task a third time expecting a different result.
  Escalate: give it more context, a narrower scope, or a more capable
  model/agent type before trying again.

## Dispatching parallel agents

Parallel dispatch is the special case where two or more tasks are genuinely
independent — no shared files, no ordering dependency:

- Send all of them in a single message with multiple tool calls; don't
  serialize independent work for no reason.
- After dispatching in the background, you know nothing about the results
  yet. Don't narrate, summarize, or fabricate an outcome before the completion
  notification actually arrives — that applies to structured output as much as
  prose.
- If tasks turn out not to be truly independent (they'd touch the same file,
  or one's output feeds the next), don't force them into parallel dispatch —
  serialize instead.

## Handoff

Once every task is dispatched, reviewed, and marked done in the ledger, close
out the branch/plan the same as solo work would: `finish-task` per task,
`finish-branch` for the whole branch.
