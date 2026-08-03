---
name: organizing-workspace
description: Use when a project has no established place to queue tasks, track a backlog, or persist agent-facing notes, and one is needed — sets up and maintains .agents/workspace/.
---

# Organizing workspace

Defines the `.agents/workspace/` convention: a project-local, agent-managed
place to queue tasks, track a backlog, and persist durable notes, for projects
that don't already have their own way of doing this.

## When this applies

Check for an existing convention first. If the project already has its own
backlog/task system — a `docs/followups.md`, an issue tracker, a project
management tool — use that instead. This skill exists for the common case
where neither the project nor its `AGENTS.md` says anything about where this
kind of state lives, and one is needed. Don't migrate an existing, working
convention to this one just because this skill exists.

## The convention

```
.agents/workspace/
├── README.md    # what this directory is, and the write-ownership contract below
├── INBOX.md     # user-owned drop box for new tasks/notes
├── TODO.md      # agent-owned task list
├── MEMORY.md    # durable facts about developing in this repo
└── plans/       # plan documents for larger development tasks
```

Write ownership is split so the user and the agent never collide on the same
file:

- **`INBOX.md`** — only the user appends here, any time. The agent only reads
  it, and only writes to it (to clear processed items) from inside the
  `/inbox` or `/work` commands — never otherwise.
- **`TODO.md`** — agent-owned. New items arrive by copying them out of
  `INBOX.md`; the agent updates status here freely as work progresses.
- **`MEMORY.md`** — agent-owned, kept short: a quick-reference for
  conventions and decisions worth remembering, not an archive of everything
  that happened.
- **`plans/`** — one file per larger task, following whatever plan format the
  project's own skills (e.g. `writing-plans`) specify.

Commit meaningful workspace intermediates with messages that explain the
reasoning — the git log doubles as a record of past decisions.

## Bootstrapping it

If `.agents/workspace/` doesn't exist yet and is needed, create it with these
four files:

**`README.md`**
```markdown
# Workspace

This directory is the agent's workspace: anything that supports development
in this repo but isn't part of the shipped project — task tracking, notes,
plans, scratch analysis — lives here rather than in the repo root.

## What belongs here
- `TODO.md` — the agent-owned development task list
- `INBOX.md` — user-owned drop box for new tasks/notes (agent reads, moves
  into `TODO.md`). See both files' headers for the write-ownership split.
- `MEMORY.md` — durable facts about development in this repository worth
  remembering (conventions, decisions, etc). Keep it short; it's a
  quick-reference, not an archive.
- `plans/` — plan documents for larger development tasks
- Scratch drafts, intermediate analyses, and experimental results that inform
  some work but aren't the work itself.

## Persisting workspace content
Prefer committing meaningful intermediates with a message explaining the idea
behind them, so the git log stays a useful record of reasoning across time.
```

**`INBOX.md`**
```markdown
# Inbox

A write-only drop box for the user to queue up new tasks/notes without
colliding with edits to `TODO.md` (which lives alongside this file at
`.agents/workspace/TODO.md`).

**Contract:**
- **The user** appends new items here, any time — the only writer to this
  file.
- **The agent** only reads it; items are moved into `.agents/workspace/TODO.md`
  via the `/inbox` and `/work` commands (the only sanctioned writes to this
  file).

**Format:** one item per bullet, optionally timestamped. Prefix with `!` for
anything urgent enough to interrupt current work.

\```
- [YYYY-MM-DD] <task or note>
- [YYYY-MM-DD] ! <urgent task or note>
\```

## Items

_None._
```

**`TODO.md`**
```markdown
# TODO

Agent-owned task list. New items arrive via `.agents/workspace/INBOX.md`
(user-owned) and get copied here (INBOX is read-only for the agent outside
`/inbox` and `/work`).

## Active

## Completed

## Follow-up
```

**`MEMORY.md`**
```markdown
# MEMORY

Agent-owned list of reference memories. Durable facts about developing in
this repo worth remembering. Used for quick-reference, not as an archive.

## Facts
_None yet._
```

Create `plans/` empty; the first plan populates it.

## Used by

The `/inbox` and `/work` commands (`agent-craft/commands/`) both assume this
convention and bootstrap it via this skill on first use if it isn't there yet.
