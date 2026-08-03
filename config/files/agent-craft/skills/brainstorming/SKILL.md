---
name: brainstorming
description: Load before starting any nontrivial implementation — when you have a task but the approach isn't settled yet, before writing a plan or touching code.
---

# Brainstorming a design

This runs *before* `writing-plans` and `writing-code`. Skip it only for
trivial, obviously-one-way changes; everything else earns a few minutes here
first, because the cost of the wrong approach compounds through every later
step.

## 1. Explore before proposing

- Read the surrounding code, existing docs, and any prior art in the repo
  before you suggest anything. A proposal grounded in what's actually there
  beats a generic one.
- If the ask is ambiguous or underspecified, ask one clarifying question at a
  time — not a bundled list. Wait for the answer before asking the next one;
  each answer usually changes what's worth asking next.

## 2. Propose 2–3 approaches

- Lay out a small number of real options, not one option dressed as a choice.
  For each: what it does, what it costs (complexity, time, risk), and what it
  trades away.
- Say which one you'd pick and why — a recommendation, not a menu with no
  opinion. It's fine to be overruled.

## 3. Write it down, then self-review it

- Capture the chosen approach as a short design note: the problem, the
  options considered, the choice, and the reasoning. This becomes the input to
  `writing-plans`, not a separate artifact to maintain forever.
- Re-read it as a skeptical reader would: does the reasoning hold up, does it
  miss an obvious alternative, does it gloss over a real risk?

## 4. Get explicit approval before moving on

- Don't start `writing-plans` or `writing-code` until the approach is
  confirmed. "Seems reasonable, go ahead" counts; silence does not.
- If new information surfaces mid-implementation that undermines the chosen
  approach, come back to this skill rather than quietly improvising a
  different one.

## Handoff

Once the approach is approved: multi-step work goes to `writing-plans` to
become a sized task list, then `writing-code`/`executing-plans` to build it.
A single small change can skip straight to `writing-code`.
