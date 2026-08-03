---
name: writing-skills
description: Load when authoring a new SKILL.md or editing an existing one.
---

# Writing a skill

A skill is only as good as the failure it prevents. Write it against a real
lapse, not a topic you think deserves documentation.

## Red-green-refactor for skill authoring

Before writing the skill, reproduce the gap it's meant to close:

1. **Red** — run the pressure scenario *without* the skill loaded and watch
   what actually goes wrong. Write down the exact rationalization used (the
   specific sentence an agent tells itself to skip the right behavior — "this
   is too simple to need a test," "I'll fix that after," etc.).
2. **Green** — write the minimal skill content that closes that specific gap.
   Not a general essay on the topic; the smallest instruction that would have
   stopped the exact rationalization you just observed.
3. **Refactor** — retest the same pressure scenario with the skill loaded.
   If the rationalization still slips through, the skill's wording, not the
   scenario, is wrong — tighten it and retest.

Skills that are never pressure-tested against a real failure tend to read
well and do nothing.

## Skill Discovery Optimization

The `description` frontmatter field must contain **only the triggering
condition** — when to load this skill — and never a summary of what's inside.
An agent that sees a content summary in the description tends to act on that
summary instead of loading and reading the full body, which defeats having a
skill at all. "Use when X" is correct; "Use when X. Covers A, B, and C" is not.
This applies to every skill in this directory, not just newly written ones —
if you're touching a `SKILL.md` for any reason, fix its description while
you're in there.

## Voice and length

- Match the voice already established in this skill directory: direct,
  plain "you"/"I", second person, no marketing language. Read a neighboring
  skill before writing a new one.
- Default to a calm, principle-based register. Reserve harder framing (an
  explicit "Iron Law," a named rule you're forbidden to rationalize around)
  for the small number of cases where a model reliably talks itself out of the
  right behavior otherwise — most content doesn't need it, and blanket
  ALL-CAPS urgency stops meaning anything once every skill uses it.
- Keep it as short as the content allows. A skill that's loaded often should
  be scannable in well under a minute; put the "why" in only where it changes
  what the reader does, not as background color.

## Structure

- Frontmatter: `name` (matches the directory), `description` (trigger only).
- A short framing line or two explaining what the skill is for and where it
  sits relative to neighboring skills.
- Numbered or heading-based sections for the actual steps/principles.
- A `Handoff` section when this skill's output feeds into another skill —
  name it explicitly rather than leaving the reader to guess what's next.
