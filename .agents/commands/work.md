---
description: Triage the inbox (like /inbox), then work ready items in docs/followups.md until blocked.
---

Do two phases in order.

## Phase 1 — drain the inbox

Perform the `/inbox` steps (see `.claude/commands/inbox.md`): read
`docs/INBOX.md` and file each item under `## Items` into the best-fit section of
`docs/followups.md` (bold title, `*(Complexity: …)*` tag, the *why*, and links
to related `docs/plans/*` and repo-relative paths), handling `!`-urgent items
first and **without interviewing**. Then clear `## Items` to
`_None — cleared <YYYY-MM-DD>._`

> Invoking this command authorizes that one inbox write. Outside this triage
> step `docs/INBOX.md` stays read-only.

## Phase 2 — work the backlog

Then work `docs/followups.md`. Do any `!`-urgent items from this drain first;
otherwise go section-by-section, top to bottom. For each item:

- **Respect the Status tag.** Work `Status: Ready` items first; skip
  `Status: Blocked` ones unless their named blocker has since cleared (if it has,
  re-mark the item `Ready` and proceed). Then: if a plan exists in
  `docs/plans/`, follow it; if the item is small and unambiguous, just do it. If
  while working you hit a design decision, a missing plan, or interactive
  validation you can't safely default (e.g. something only the user can visually
  confirm), **STOP and ask** rather than guess — set the item's Status to
  `Blocked — on <what>` and move on to the next ready item.
- Follow `AGENTS.md` conventions (two-phase setup/config model, role structure,
  shellrc load ordering). **Never override git identity on the CLI** — no
  `git -c user.email=…`, `--author`, or `GIT_AUTHOR_*`/`GIT_COMMITTER_*`; the
  layered gitconfig resolves the right identity. Delegate heavy or parallelizable
  sub-work to subagents, then verify their output. Where a change has a runtime
  surface (a role apply, a shell reload, a `:checkhealth`), verify it.
- As each item completes: **remove it** from `docs/followups.md` (the file's
  convention is to delete done items — git history keeps the record) and
  **commit** in logical steps with descriptive messages (`area: summary`, ending
  with the `Co-Authored-By: Claude Code` trailer per `AGENTS.md`). If a
  `docs/plans/` doc covered it, update or delete that plan under the same
  done-convention. Never stage the inbox content beyond the Phase-1 clear, and
  don't sweep unrelated uncommitted changes into a commit.
- Track multi-step work with the task list.

Keep going until every ready item is done **or** you hit something that needs
the user — then stop. Give a short note as each item finishes and a summary at
the end: what's done, what's in progress, and anything awaiting the user.
