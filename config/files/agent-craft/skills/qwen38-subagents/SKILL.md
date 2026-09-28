---
name: qwen38-subagents
description: Must load whenever dispatching a subagent that runs on the qwen38 model family (any model whose id contains qwen38, e.g. chiiiirs-litellm/qwen38-27b-instruct or chiiiirs-litellm/qwen38-27b-thinking). The local-model throughput rules here are different from the defaults of subagent-driven-development.
---

# Working with qwen38 subagents

qwen38 (27B, self-hosted) is competent but slow: roughly 2-3 minutes per
assistant turn, including every tool call. Budget is not the constraint —
wall-clock is nearly free. The constraint is that most of every run dies in
context loading, not implementation. Rules below are measured from live runs,
not guesses.

## Turn accounting

One "turn" = one model round-trip. Reading a file, running a command, and
writing code each cost turns. A 60-minute run therefore yields ~20-25 turns
total, and a run that burns 15 of them just reading context has no budget left
to implement. Size every task and timeout from this number.

## Task design

1. **One deliverable per subagent.** A task that needs "and" is two tasks.
   "Peer API routes AND remote target AND composition" timed out at 60 minutes
   with zero commits; the same work split into sequential phases made steady
   progress.
2. **Give an explicit reading list.** Name the exact files (and the specific
   functions or sections) to read first, and list what is already built so it
   does not re-derive architecture. Every file it reads on its own is a turn
   you paid for.
3. **State the definition of done in the task itself:** the exact tests that
   must pass, the verification commands, and the commit expectation.
4. **Serial, not parallel, for dependent work.** Each worker re-reads the
   same context; parallel runs of one model multiply the re-read cost. Use a
   workflowScript of sequential `runs.run` calls for dependent phases and pass
   the previous phase's tail summary into the next task.
5. **High timeouts, always.** 30-minute defaults are a trap: they look fast
   but guarantee a context-loading budget, not an implementation budget.
   Give each phase at least 4 hours (`timeoutMs: 14400000`) and the workflow
   several times that. The user has explicitly authorized multi-hour runs of
   this model family.

## Checkpoint discipline

A timed-out run loses nothing that was committed, and can lose a lot that
wasn't. In the task text, require the worker to:

- commit after every test-first slice (not at the end),
- write failing tests first (the red state is itself a durable checkpoint),
- run the full suite before each commit.

When a run times out, the first thing to check is `git status` + `git diff
--stat` + the test suite: a red test suite with a fresh implementation file is
a resumable position, not a failure.

## Recovery from a dead run

1. Read `subagent({action:"status", id, view:"transcript"})` to see the last
   activity.
2. Check the working tree and run the suite — partial work is usually there.
3. Dispatch a same-model continuation with the task: "the previous run
   stopped at X; the working tree has Y; finish it." Do not restart from
   scratch; that pays the context-loading tax twice.
4. After two failed attempts at the same task, narrow scope or raise the
   budget — same escalation rule as any subagent work.

## Supervision round-trips

Intercom (supervisor) questions from a qwen38 worker pause its run and cost
round-trips; the reply is the only thing that unblocks it. When a worker asks
a decision question:

- answer it inline, fully and decisively (it will not ask a follow-up cheaply),
- prefer answering from existing docs when the doc is authoritative,
- pin the decision in tests so it cannot come back.

Prevent most of them by resolving scope ambiguities in the task text up front
(role names, endpoint sets, file ownership). A worker that must guess will
guess, and asking later costs more than deciding now.

## Handoff

These rules override `subagent-driven-development`'s defaults only for the
qwen38 model family (timeout size, parallelism, checkpoint frequency). Its
mandatory review gates still apply: a qwen38 worker's summary is a claim, and
the diff plus a green suite are the fact.
