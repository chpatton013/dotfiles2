---
name: ste-writing
description: Write technical text in Simplified Technical English (a controlled, ASD-STE100-style register) so instructions, error messages, and documentation read plainly and unambiguously. Use when authoring or tightening procedures, UI and error text, API docs, or any technical prose that must be clear on first read.
---

# ste-writing

Simplified Technical English (STE) is a controlled writing style: a small
vocabulary, short sentences, and active voice that make technical text
unambiguous on first read. It descends from the ASD-STE100 aerospace standard.
This skill applies its principles to software text: procedures, error and log
messages, UI strings, API references, and README prose.

Use this skill for *how a sentence reads*. For the judgment of *what deserves a
comment and where rationale belongs*, use the `documentarian` skill, which calls
this one for style. For removing AI-slop patterns from prose, use `humanizer`.

## Two modes

Pick the mode from the stakes of the text.

**Strict** governs procedures, safety text, error and warning messages, and any
text a reader acts on under pressure. Apply every rule below, including the hard
length caps.

**Flavored** governs comments, descriptions, and general technical prose. Keep
active voice, one name per thing, and plain words. Relax the hard word count,
but still split a runaway sentence.

## Rules

### Words

- Use one name for one thing. Do not call the same item by two names.
- Give each word one meaning in the document.
- Prefer short, common words: use over utilize, start over begin, help over
  facilitate, get over obtain, about over approximately, enough over sufficient.
- Reject marketing adjectives: seamless, robust, cutting-edge, powerful,
  blazing-fast, effortless.
- Use American spelling.

### Verbs

- Use active voice with a named actor: "the parser reads the file", not "the
  file is read".
- Use a verb for an action. Do not turn the verb into a noun ("perform a
  validation of" becomes "validate").
- Do not stack auxiliaries. Replace "it is important to note that this may help
  to" with the plain claim.
- Prefer a simple tense over an "-ing" main verb.

### Sentences

- Write one instruction per sentence.
- In strict mode, keep instructions to 20 words and descriptions to 25. Split a
  longer sentence.
- Use no contractions in strict mode. Keep the articles (a, an, the, this).

### Punctuation

- Use no semicolons. Write two sentences instead.

### Structure

- Keep one topic per paragraph, and at most six sentences.
- Write a procedure as a numbered vertical list, one action per step, in the
  imperative.
- Put the condition before the command: "If the load fails, lower the memory
  fraction", not "Lower the memory fraction if the load fails".

## Self-lint

Run this pass over the text:

1. A sentence runs past the mode's limit. Split it.
2. A semicolon joins two clauses. Make two sentences.
3. A contraction appears in strict text. Expand it.
4. Passive voice hides a known actor. Make it active.
5. A noun stands in for a verb, or a phrasal verb obscures the action. Use the
   plain verb.
6. One item carries two names. Unify them.
7. A marketing adjective or a stacked-auxiliary opener appears. Cut it.

## Credits

The rules restate the principles of ASD-STE100 Simplified Technical English,
maintained by the AeroSpace and Defence Industries Association of Europe. The
two-mode framing and this software-focused rendering draw on the
`ste-writing-skill` write-up by [woosal1337](https://github.com/woosal1337/blog/blob/main/videos/ep01-the-cure-for-ai-slop/ste-writing-skill.md)
(MIT). This is an independent rendering rather than a copy.
