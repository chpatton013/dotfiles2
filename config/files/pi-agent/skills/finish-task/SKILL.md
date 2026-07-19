---
name: finish-task
description: Use before declaring a coding task complete. A definition-of-done checklist that verifies the change (build/typecheck/tests), updates documentation, self-reviews the diff, records follow-ups, and offers to commit. Load it whenever you are about to say a task is done, ready, or finished.
---

# Finish a task properly

Run this before you tell me a task is complete. Skipping a step is fine only if
you say which and why.

## 1. Verify it actually works

- Identify how this project builds and tests (look for `Makefile`, `justfile`,
  `package.json` scripts, `pyproject.toml`, `cargo`, `go test`, CI config, or a
  project `AGENTS.md` that names the commands).
- Build / typecheck, then run the tests covering the code you touched. Prefer a
  scoped run over the whole suite when the project is large.
- If there is no test path, exercise the change directly (run the CLI, hit the
  endpoint, call the function) and report what you observed.
- If you genuinely cannot verify it, say so plainly. Never imply tests passed
  when you did not run them.

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

- If the change is coherent and verified, load the `commit` skill and propose a
  commit (don't push or open a PR unless asked).

## 6. Report

Close with: what changed, how you verified it, what you did not do, and any
follow-ups.
