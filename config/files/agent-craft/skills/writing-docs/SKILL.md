---
name: writing-docs
description: Use when authoring or cleaning up comments and documentation, or reviewing a diff for comment and doc quality.
---

# Writing docs

Standards for code comments and technical documentation. The goal: a reader who
has never seen the change history or the conversation that produced the code
understands every comment and doc as a statement about the code as it is now.

Scope: code comments, docstrings, READMEs, design docs, and error and log
messages. For general prose de-slopping (blogs, essays, marketing-flavored
text), use the companion `humanizer` skill. This skill owns the engineering
judgment about what deserves a comment and where rationale belongs. `humanizer`
owns surface prose patterns (filler phrases, tone, punctuation, AI tells). When
a document has prose sections, apply this skill first, then hand off to
`humanizer`.

## Core principles

### 1. Timeless

The artifact keeps no memory of its own history or the session that wrote it.

- Remove change narration: "was X, now Y", "used to", "previously", "refactored
  to", "as requested", "we implemented the plan", "for posterity", session
  dates, debugging trails, and references to a chat or an agent memory note.
- Keep the current fact. If the reason a value changed still constrains the
  code, state the constraint, not the change.
- History lives in commit messages, changelogs, and design docs, not in the
  artifact.

Do: `# util 0.85: the 128 GB pool is shared with the OS, so higher values OOM the host.`
Don't: `# bumped util from 0.7 to 0.85 after we saw negative KV last run.`

### 2. Why, not what

Comment the reason the code is non-obvious, not the mechanics the code already
shows.

- The code states what it does. A comment that restates it adds noise and rots
  out of sync.
- Comment the non-obvious: a constraint, a gotcha, a chosen tradeoff, a link to
  an issue, or the reason the naive approach fails.

Do: `# Retry twice: the link drops the first SYN after a cold boot.`
Don't: `# increment the counter`

### 3. A comment is the last resort

Prefer a clearer name or structure over a comment.

- If a comment explains what a variable or function is, rename it and delete the
  comment.
- If a comment explains a confusing block, extract a well-named function.
- A comment that apologizes for the code ("hacky", "fix later") is either a TODO
  with an owner and a reason or a refactor, not a permanent decoration.
- Keep the comment only when the reason cannot live in the code itself.

## Style: Simplified Technical English

Write technical text in Simplified Technical English, in two modes. Use strict
mode for procedures, error and warning messages, and anything a reader acts on
under pressure. Use flavored mode for comments and general prose. The rules this
skill leans on most:

- Active voice with a named actor: "the parser reads the file", not "the file is
  read".
- One name for one thing. Do not cycle synonyms for the same item.
- Plain words over long ones: use, start, help, get.
- Short sentences. In strict mode, cap an instruction at 20 words and put the
  condition before the command: "If the load fails, lower util."
- No semicolons, and no marketing adjectives (seamless, robust, cutting-edge).

For the full standard, the length caps, and a self-lint pass, use the
`ste-writing` skill.

## Comment hygiene

- Do not restate the code or the signature. A docstring that repeats the
  parameter names adds nothing.
- Match the surrounding density and style. Do not drop a paragraph into a file
  that comments sparingly.
- Delete commented-out code. Version control remembers it.
- Add no decorative banners, emoji, or box-drawing unless the file already uses
  them.
- State one reason per comment. If a line needs three caveats, the code likely
  needs to be split.
- Keep a comment next to what it explains. A comment that drifts from its code
  misleads.

## Documentation structure

- Lead with the point. State the conclusion or the instruction first, then
  support it.
- Write for the reader who arrives cold. Name the audience and the prerequisite,
  not the backstory.
- Keep one topic per section. A heading followed by a one-line restatement of
  the heading is filler; delete the restatement.
- Keep status and history out of the artifact. "Status: IMPLEMENTED", "TODO(you)",
  and "as of this session" belong in a commit, an issue, or a changelog. Update
  a doc that describes a finished plan to describe the result, or delete it.
- Link, do not duplicate. Point to the canonical source instead of copying facts
  that will drift.

## Review pass

Run this checklist over a diff or a file:

1. A comment narrates a change or the conversation. Rewrite it to the current
   fact, or delete it.
2. A comment restates the code. Delete it, or rename the code so no comment is
   needed.
3. A "what" comment stands where a better name would do. Rename.
4. Passive voice hides a known actor. Make it active.
5. A sentence exceeds the mode's limit, or a strict passage has a semicolon or a
   contraction. Split or replace.
6. One thing carries two names. Unify.
7. Commented-out code, a dead TODO, a decorative banner, or an emoji is present.
   Remove it.
8. A doc section describes a finished plan or carries a status stamp. Move it to
   history or delete it.
9. A marketing adjective or a filler opener ("Let's dive in", "It is important to
   note") is present. Cut it.

For prose-heavy documents, hand off to `humanizer` after this pass.
