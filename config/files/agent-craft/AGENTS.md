# Engineering practices (global instructions)

These are my baseline working habits. They apply in every project unless that
project ships its own `AGENTS.md` that says otherwise (a project-level file wins
over this one). Keep them cheap to carry: follow the principles below, and only
load the named skill for the full step-by-step procedure when you are actually
about to do that thing.

## Skill loading is mandatory, not advisory

If a named skill applies to what you're about to do, load it and follow it —
that is not optional, and it is not satisfied by remembering the gist from a
previous read. "I already know what it says" is exactly the rationalization
that leads to skipping the step the skill exists to enforce.

When more than one skill could apply, prefer process order over jumping
straight to implementation: design/investigation skills (`brainstorming`,
`systematic-debugging`) come before methodology skills (`writing-plans`,
`writing-code`, `executing-plans`), which come before close-out skills
(`finish-task`, `committing-changes`, `finish-branch`, `code-review`). Don't
start writing code before the approach is settled, and don't declare
something done before its close-out skill has actually run.

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

Load the `finish-task` skill for the full checklist. For a nontrivial change,
that checklist includes getting a real review — load `code-review` for how to
request one and how to handle what comes back. When the whole feature branch
(not just this task) is done, load `finish-branch` for the merge/PR/keep
decision.

## Design & investigation

Before implementation starts: if the approach isn't already settled, load the
`brainstorming` skill to explore options and get it approved before writing a
plan or touching code. For multi-step work, load `writing-plans` to turn the
approved approach into a sized, ordered task list.

The moment something breaks — a bug, a failing test, unexpected behavior —
load the `systematic-debugging` skill before proposing a fix. A fix proposed
before the failure is understood is a guess.

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

Load the `committing-changes` skill before you commit.

## Code quality

- Prefer small, single-responsibility functions and modules; isolate side
  effects so logic stays unit-testable.
- Match the surrounding file's existing style, naming, and structure over any
  personal preference. Read a neighbor before you write.
- Don't gold-plate. Solve the task at hand; note larger refactors as
  follow-ups instead of expanding scope silently.

Load the `software-design` skill when making a nontrivial design/architecture
or refactoring decision, and the `writing-code` skill when writing the code
for a slice of work — test-first, one behavior at a time. Load
`executing-plans` alongside it for the session/subagent mechanics of working
through a multi-task plan, and `subagent-driven-development` when the work is
being orchestrated across dispatched subagents rather than done in this
session directly.

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

Full playbook: the `writing-docs` skill. Style detail: `ste-writing`. Prose
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
