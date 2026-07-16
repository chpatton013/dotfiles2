---
description: Record a follow-up item in docs/followups.md
argument-hint: <what to defer for later>
---

The user wants to record a follow-up item so it is not forgotten. Their
description of the item:

$ARGUMENTS

Record it in `docs/followups.md`. Follow these rules:

## Scope: record, don't solve

The goal right now is only to **capture** the item well enough that a future
session can pick it up cold. Do **not** start doing the work, and do **not**
deep-dive the investigation now — defer thorough research until someone actually
starts the item. A little cheap lookup to make the entry concrete and correctly
linked is fine (e.g. `grep` for the files/symbols involved, glancing at a
relevant plan); a full analysis is not.

## Interview only if needed

If the description is already clear enough to write an actionable entry, just
write it — do not interrogate the user. Ask a brief clarifying question **only**
when a genuine ambiguity would change what gets recorded (e.g. which of two
subsystems they mean, or the intended outcome is unclear). Prefer one focused
round of questions over many.

## Write the entry

- `docs/followups.md` is grouped into `##` activity sections (e.g. Provisioning
  & setup, Neovim, Terminal & theming, Repo hygiene & tooling). File the item
  under the section it best fits, newest at the top of that section. Only add a
  new section if the item genuinely fits none — prefer an existing one.
- Match the existing bullet style: a bold one-line title, then supporting detail
  as needed.
- Tag the item with a complexity estimate right after the title, matching the
  legend at the top of the file: `*(Complexity: Low.)*` / `*(Complexity:
  Medium.)*` / `*(Complexity: High.)*` (add a short qualifier when useful, e.g.
  "High — may warrant its own plan"). Estimate from scope: Low = one role/file;
  Medium = a few files or up-front investigation; High = real design work, many
  files, or its own `docs/plans/` doc.
- State the item as a concrete task, not just a topic. Capture the *why* if the
  user gave one — it is often the part that is hard to reconstruct later.
- **Link it up.** This is important for making the item actionable later:
  - If it relates to an existing plan in `docs/plans/`, reference that file by
    path.
  - Reference the specific source files/roles/paths involved (repo-relative),
    so the future session knows where to start. Verify paths you cite actually
    exist before writing them.
  - If it depends on or relates to another item already in the queue, mention
    that.
- If the description embeds facts, candidates, or decisions the user already
  worked out, preserve them in the entry so that thinking is not lost.
- Convert any relative dates ("next week") to absolute dates.

After writing, show the user the exact entry you added and where, in one short
message. Do not restate these instructions.
