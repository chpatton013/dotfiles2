# Engineering practices (global instructions)

These are my baseline working habits. They apply in every project unless that
project ships its own `AGENTS.md` that says otherwise (a project-level file wins
over this one). Keep them cheap to carry: follow the principles below, and only
load the named skill for the full step-by-step procedure when you are actually
about to do that thing.

## Definition of done

A change is not finished when the code compiles — it is finished when it is
verified, documented, and recorded. Before you tell me a task is complete:

1. Build / typecheck, then run the project's tests for the code you touched.
   If you cannot determine how to test it, say so explicitly rather than
   implying it passed.
2. Update the documentation your change invalidated: docstrings on functions
   you changed, README / usage text, and any comment that is now wrong.
3. Re-read your own diff and remove leftovers — debug prints, commented-out
   experiments, dead code, stray TODOs.
4. Record anything you deliberately left undone as a follow-up (see below) so
   it is not silently lost.

Load the `finish-task` skill for the full checklist.

## Version control

- Commit at logical checkpoints, not as one giant dump at the end. Each commit
  should build on its own and group one coherent change.
- Subject style: lowercase `area: summary`, imperative mood, no trailing
  period (e.g. `parser: handle empty input`). Explain *why* in the body when
  it is not obvious.
- Never fabricate or override the git author identity on the command line
  (no `-c user.*`, no `--author`, no `GIT_AUTHOR_*`/`GIT_COMMITTER_*`). The
  machine's layered gitconfig already resolves the correct identity per repo;
  let git pick it.
- Never commit secrets (API keys, tokens, `.env` values). If you spot one
  about to be staged, stop and flag it.
- Do not `git push`, force-push, or open PRs unless I ask. Committing to the
  local branch is fine and encouraged.

Load the `commit` skill before you commit.

## Code quality

- Prefer small, single-responsibility functions and modules; isolate side
  effects so logic stays unit-testable.
- Match the surrounding file's existing style, naming, and structure over any
  personal preference. Read a neighbor before you write.
- Don't gold-plate. Solve the task at hand; note larger refactors as
  follow-ups instead of expanding scope silently.

Load the `software-design` skill when making a nontrivial design/architecture
or refactoring decision, and the `execute-plan` skill when working through a
multi-step plan or feature.

### Comments & documentation

Apply these whenever you write or edit comments, docstrings, or documentation.
You still change code freely; these shape only how you write *about* it.

- **Timeless.** The artifact keeps no memory of its own history or this
  conversation. Drop "was X, now Y", "used to", "as requested", "for now",
  session dates, and change narration. State the current fact. History goes in
  the commit message, not the code.
- **Why, not what.** Comment the non-obvious reason: a constraint, a gotcha, a
  tradeoff, an issue link. Do not restate what the code already shows.
- **Prefer a name over a comment.** If a comment explains what something is,
  rename it. Keep the comment only when the reason cannot live in the code.
- **Plain, active, one name per thing.** Active voice with a named actor. Short
  sentences. No marketing adjectives (seamless, robust, cutting-edge). Match the
  file's existing comment density.
- **Docs lead with the point** and keep status and plans out of the artifact
  (those go in a commit or an issue). Link canonical sources instead of copying
  facts that will drift.

Full playbook: the `documentarian` skill. Style detail: `ste-writing`. Prose
de-slopping: `humanizer`.

## Follow-up management

- Use the todo tool for tasks within the current session.
- For work you are intentionally deferring beyond this session, surface it
  explicitly in your closing summary (and, in repos that keep one, append it
  to their follow-up/backlog/todo file) rather than dropping it.

## Review before finishing

Before declaring done, do a quick self-review pass as if reviewing someone
else's PR: does the diff do what was asked, is it consistent, are edge cases
and errors handled, and is anything now untested or undocumented?
