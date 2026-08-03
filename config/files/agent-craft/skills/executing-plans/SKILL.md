---
name: executing-plans
description: Load when starting a session (or subagent) that works through an existing plan document, before beginning its first task.
---

# Executing a plan across a session

This is the session/subagent *mechanics* of working an existing plan file:
how the work gets tracked, checkpointed, and handed off. For the engineering
methodology inside each task — TDD, DDD, slicing — see `writing-code`; the two
are complementary, not overlapping.

## Set up isolation

- If the harness offers `isolation: worktree` (subagent dispatch) or you're
  working a feature branch directly, confirm you're on isolated work before
  starting, so this plan's changes don't collide with unrelated in-flight
  work.

## One task, one todo, at a time

- Track the plan's tasks in the todo tool as you go — mark the current one in
  progress, mark it done only once it's actually verified, not just coded.
- Work one task fully (code, verify, close out via `finish-task`) before
  starting the next. Don't open several tasks concurrently in one session;
  that's what `subagent-driven-development` is for when tasks are genuinely
  independent.

## Stop and ask when the plan breaks down

- If a task turns out to be bigger, smaller, or different than the plan
  assumed, stop before improvising past it. Update the plan document to
  reflect what you learned, then continue — don't silently diverge and leave
  the plan lying about what actually happened.
- If you're genuinely blocked (a decision only a human can make, missing
  access, an assumption the plan got wrong), say so rather than guessing and
  hoping the guess was right.

## Handoff at the end

- When every task in the plan is done and verified, the plan document itself
  is done — prune it per this repo's convention (or whatever the project's
  plan-storage convention specifies; see `writing-plans`).
- If the work was on a dedicated branch, hand off to `finish-branch` for the
  branch-completion decision. Subagent-dispatched work under
  `isolation: worktree` already gets its worktree lifecycle handled by the
  harness — `finish-branch` is for the foreground/manual case, not this one.
