---
description: Triage docs/INBOX.md — file each item into docs/followups.md, then clear the inbox.
---

Drain `docs/INBOX.md` into the backlog `docs/followups.md`. This is
**triage-only**: file + clear. Do NOT start doing the tasks themselves — that's
`/work`.

Steps:

1. **Read `docs/INBOX.md`.** For each bullet under `## Items` (handle any
   `!`-prefixed urgent items first):
   - File it into `docs/followups.md` following the `/followup` conventions
     (see `.claude/commands/followup.md`): drop it into the best-fit `##`
     activity section (newest at the top of that section; only create a new
     section if it fits none), give it a **bold one-line title**, a
     `*(Complexity: Low/Medium/High.)*` tag estimated from scope, and the *why*
     if the item gives one. **Link it up** — reference any related
     `docs/plans/*` file and the specific repo-relative roles/files/paths
     involved, verifying paths exist before citing them. Preserve any facts,
     candidates, or decisions the item already contains.
   - Use the item's leading `[YYYY-MM-DD]` if present, else today, for any dated
     references.
   - **Unlike `/followup`, do NOT interview.** This is a non-interactive batch
     drain. If an item is genuinely ambiguous, file it anyway with a short
     `_Needs clarification: …_` note rather than stopping to ask.

2. **Clear the inbox.** Once every item is filed, remove all bullets under
   `## Items` in `docs/INBOX.md`, leaving the header/format guide intact and
   `## Items` empty with a placeholder: `_None — cleared <YYYY-MM-DD>._`

   > Invoking this command is your explicit authorization to write to
   > `docs/INBOX.md`. This is the ONLY situation in which you may edit or clear
   > it — outside this command (and the triage phase of `/work`) `INBOX.md` is
   > strictly read-only.

3. **Report** briefly: each item filed (title + section), any `!` urgent ones,
   anything flagged as needing clarification, and confirm the inbox was cleared.
