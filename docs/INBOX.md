# Inbox

A write-only drop box for queuing tasks/notes **without interrupting an
in-progress agent session** and without colliding with agent edits to the
backlog (`docs/followups.md`).

**Contract:**
- **The user** appends new items here, any time — you are the only writer to
  this file, so it never conflicts with in-progress agent work.
- **The agent** only *reads* this file, except during `/inbox` (or the triage
  phase of `/work`), which moves each item into `docs/followups.md` and clears
  it here in the same step. Outside that triage, `INBOX.md` is strictly
  read-only.
- The agent drains this at the start of a `/work` session and at natural
  stopping points.

**Format:** one item per bullet, optionally date-prefixed. Prefix with `!` for
anything urgent enough to interrupt current work.

```
- [YYYY-MM-DD] <task or note>
- [YYYY-MM-DD] ! <urgent task or note>
```

## Items

_None — cleared 2026-07-17._
