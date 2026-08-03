---
name: finish-task
description: Use before declaring a coding task complete — whenever you are about to say a task is done, ready, or finished.
---

# Finish a task properly

Run this before you tell me a task is complete. Skipping a step is fine only if
you say which and why. This is for "this task is verified" — for "the whole
branch is done, now what happens to it," see `finish-branch` instead.

## 1. Verify it actually works

**Evidence before claims.** "Done" is a statement about what you observed, not
what you expect. If you haven't run it, you don't know it works — say that,
don't imply otherwise.

- Identify how this project builds and tests (look for `Makefile`, `justfile`,
  `package.json` scripts, `pyproject.toml`, `cargo`, `go test`, CI config, or a
  project `AGENTS.md` that names the commands).
- Build / typecheck, then run the tests covering the code you touched. Prefer a
  scoped run over the whole suite when the project is large.
- If there is no test path, exercise the change directly (run the CLI, hit the
  endpoint, call the function) and report what you observed.
- If you genuinely cannot verify it, say so plainly. Never imply tests passed
  when you did not run them.
- Ban these phrases unless you have the evidence to back them at the moment
  you write them: "should work now," "this probably passes," "I'm confident
  this fixes it." Each one is a claim standing in for a test you didn't run —
  run the test, then state the result instead.
- For anything nontrivial, verification includes review, not just your own
  read of the diff — see `code-review` for dispatching one.

## 2. Update documentation

- Add/refresh docstrings on functions and types you changed.
- Update README / usage / help text and inline comments your change made stale.
- If the project keeps design docs or a changelog, note whether they need an
  update.

## 3. Self-review the diff

- Re-read the full diff. Remove debug prints, commented-out experiments, dead
  code, and TODOs you don't intend to leave.
- Check error/edge-case handling and that names/style match the surrounding
  code.

## 4. Record follow-ups

- Anything you deliberately deferred goes into the todo tool and your closing
  summary. In repos with a follow-up/backlog/todo file, append it there too.

## 5. Offer to commit

- If the change is coherent and verified, load the `committing-changes` skill
  and propose a commit (don't push or open a PR unless asked).

## 6. Report

Close with: what changed, how you verified it, what you did not do, and any
follow-ups.
