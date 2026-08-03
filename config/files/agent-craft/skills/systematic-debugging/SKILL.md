---
name: systematic-debugging
description: Load the moment you hit a bug, test failure, or unexpected behavior — before proposing or writing any fix.
---

# Debug the cause, not the symptom

A fix proposed before the failure is understood is a guess. Guesses that
happen to make the symptom go away are how bugs come back later wearing a
different face. Investigate first, every time — including when the fix
"seems obvious."

## 1. Read the failure completely

- Read the whole error: message, type, stack trace, the actual assertion that
  failed and what it expected vs. got. Don't skim to the first familiar-looking
  line and start theorizing from there.

## 2. Reproduce it reliably

- Get a minimal, repeatable trigger before touching code. A fix you can't
  verify against a reproduction is a fix you can't confirm worked.
- If it won't reproduce, that inconsistency (timing, environment, ordering) is
  itself the first real clue — don't paper over it.

## 3. Gather evidence before hypothesizing

- Check what changed recently (git log/blame on the affected area) — most bugs
  are introduced, not ancient.
- Trace the failure to the boundary where actual behavior first diverges from
  expected, adding logging/prints/a debugger rather than guessing at the
  internals.
- Form a *single* hypothesis for the root cause from the evidence, state it
  explicitly, then test that specific hypothesis — don't shotgun multiple
  speculative changes at once and see what sticks.

## 4. Fix the root cause

- The fix should address the mechanism you traced, not just suppress its
  visible effect (don't catch-and-ignore the exception, don't special-case the
  symptomatic input, don't add a retry over a race you haven't explained).
- If the true fix is bigger than the immediate ask, say so rather than
  quietly patching the surface.

## 5. Escalate when fixes keep failing

- After roughly three failed fix attempts on the same issue, stop iterating on
  small variations. Step back and question the architecture or assumption
  underneath — the bug may be a symptom of a design that doesn't hold up, not
  a one-line mistake.

## Handoff

Once the root cause is understood, treat the fix like any other change: drive
it with `writing-code` (test-first), then `finish-task`.
