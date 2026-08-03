---
name: finish-branch
description: Load when a whole feature branch (not just the current commit) is done and needs a merge/PR/keep decision, in a foreground session working the branch directly.
---

# Finish a branch

This is a separate decision from "this commit is done" (`committing-changes`)
and "this task is verified" (`finish-task`) — it's "the whole feature this
branch was for is done, now what happens to the branch." Load it once the
last task on the branch has passed `finish-task`, not before.

## Scope: foreground, manual branch work only

This skill assumes *this session* is working a feature branch directly in the
main working tree — detecting whether you're on a branch, confirming which
branch is the merge target, deciding what happens to it. It does not apply to
subagent-dispatched work under `isolation: worktree`: the harness already
creates, tracks, and tears down that worktree/branch lifecycle automatically,
so re-describing that mechanism here would just be redundant hand-holding.
Use `executing-plans` for that case instead.

## 1. Confirm everything on the branch is actually verified

- Every task/commit on the branch should already have gone through
  `finish-task`. If anything was left partially verified, do that now — don't
  let branch-completion be the first time the whole branch gets tested
  together.
- Run the full test suite (not just the scoped subset from individual
  commits) if the project has one.

## 2. Detect the environment

- Confirm you're actually on a feature branch, not `main`/`master` or a
  detached HEAD. If you're not where you think you are, stop and sort that out
  before doing anything destructive.

## 3. Confirm the base/target branch

- Identify what this branch is meant to land on (usually `main`, but check —
  don't assume). If it's ambiguous, ask rather than guessing.

## 4. Present the disposition options

Don't unilaterally pick one — confirm which applies:

- **Merge locally** (no PR): appropriate for solo work landing straight to the
  base branch.
- **Push and open a PR**: appropriate when review or CI gating is expected.
- **Keep as-is**: the branch isn't actually done, or is intentionally left for
  later — say so explicitly rather than leaving it in limbo unlabeled.

Never push, force-push, merge, or open a PR without this confirmation — the
repo-wide rule (don't push/PR unless asked) still applies here; this skill is
about recognizing the decision point, not overriding that default.

## 5. Execute and clean up

- Carry out the confirmed path.
- If a worktree was used for this branch, clean it up once the branch's
  content is safely merged/pushed/recorded — don't leave it orphaned.
