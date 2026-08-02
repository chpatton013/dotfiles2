---
name: software-design
description: Load when making a nontrivial design or architecture decision, writing a new module/interface, or refactoring — for intuition on how to keep code simple, decoupled, and maintainable. Distills SOLID, DRY, KISS, YAGNI, the Law of Demeter, least astonishment, the Unix philosophy, fail-fast/robustness, and the realities of long-lived systems (Conway's / Lehman's laws, big ball of mud).
---

# Software design intuition

Principles, not rules. They frequently pull against each other; the skill is
knowing which one the situation is asking for. When two conflict, prefer the one
that keeps the code easiest to change *next*.

## Keep it small and honest

- **KISS — keep it simple.** The simplest design that fully solves the problem
  wins. Complexity must earn its place; if you can't justify it, remove it.
- **YAGNI — you aren't gonna need it.** Build for the requirements you have, not
  the ones you imagine. Speculative generality is a cost paid now for a benefit
  that usually never arrives.
- **Conservation of complexity.** A problem has an irreducible amount of
  complexity; you can move it (into the code, the interface, or onto the user)
  but not delete it. Put it where it does the least harm — usually hidden behind
  a clean interface so callers don't pay for it.
- **Principle of least astonishment.** Names, signatures, and behavior should
  match what a reader already expects. Surprise is a defect. If something must
  be surprising, make it loud and documented.

## One source of truth, no duplication

- **DRY / single source of truth.** Every piece of knowledge (a constant, a
  rule, a schema) should have exactly one authoritative home. Duplication rots
  because copies drift. Note: DRY is about *knowledge*, not incidental
  text-similarity — don't merge two things that merely look alike today but
  change for different reasons.

## Boundaries and coupling

- **Loose coupling, high cohesion.** Modules should know as little about each
  other as possible and depend on stable abstractions, not concrete internals.
  Things that change together belong together; things that change for different
  reasons belong apart.
- **Law of Demeter — "don't talk to strangers."** A unit should only call its
  direct collaborators, not reach through them (`a.getB().getC().do()` couples
  you to B's and C's internals). Ask a collaborator to do the work instead of
  fetching its guts.
- **Open–closed principle.** Design so behavior can be *extended* without
  editing existing, tested code — add a case/implementation rather than
  rewiring the core. Achieve it with seams (interfaces, injection), not
  premature abstraction (see YAGNI).
- **Unix philosophy.** Prefer small pieces that each do one thing well and
  compose through simple, well-defined interfaces (text/streams/clear
  contracts). Composability beats monoliths.

## SOLID (object/module design)

- **S — Single responsibility.** One reason to change per module. If you
  describe it with "and", consider splitting.
- **O — Open–closed.** (above)
- **L — Liskov substitution.** A subtype must be usable anywhere its base type
  is, without violating the base's contract (no strengthened preconditions,
  weakened postconditions, or surprise exceptions).
- **I — Interface segregation.** Many small, client-specific interfaces beat one
  fat interface that forces implementers to stub methods they don't need.
- **D — Dependency inversion.** High-level policy shouldn't depend on low-level
  detail; both depend on abstractions. Point dependencies at interfaces you own.

## Failure behavior

- **Fail fast.** Detect invalid state at the earliest point (validate inputs,
  assert invariants) and stop loudly, rather than propagating corruption that
  surfaces far away. Cheap, local failures are easy to debug.
- **Robustness principle ("be conservative in what you send, liberal in what
  you accept") — apply with care.** Emit strictly correct output; tolerate minor
  input variation *only at trusted, well-defined boundaries*. Over-liberal
  acceptance hides bugs and lets incompatibilities accumulate — inside your own
  system, prefer fail-fast over silent leniency.

## Living with long-lived systems

Design decisions age. These describe the forces you're actually fighting:

- **Lehman's laws of software evolution.** A system in real use must keep
  changing or it becomes progressively less useful; and as it changes its
  complexity grows unless deliberate work is spent reducing it. Budget for
  ongoing refactoring — entropy is the default, not a surprise.
- **Conway's law.** A system's structure tends to mirror the communication
  structure of the org that built it. Use it deliberately: draw module
  boundaries along team/ownership lines so interfaces match who actually
  coordinates.
- **Gall's law.** A complex system that works is invariably found to have
  evolved from a simple system that worked. A complex system designed from
  scratch never works and cannot be patched into working — you have to start
  over with a working simple system and grow it. Practical takeaway: don't
  build the grand design up front; get the smallest end-to-end thing working,
  then evolve it. (This is the design-level root of the incremental theme; the
  `execute-plan` skill turns it into a working loop.)
- **Big ball of mud.** The most common architecture is *no* architecture —
  structure erodes one expedient shortcut at a time. Resist it by keeping
  boundaries explicit, deleting dead code, and paying down complexity as you go
  rather than "later."

## Applying this

1. State the change in one sentence; if you need "and", you may be touching more
   than one responsibility.
2. Choose the smallest design that solves *today's* requirement (KISS/YAGNI).
3. Put each piece of knowledge in exactly one place (DRY).
4. Draw the boundary where change is likely; depend across it via a stable
   interface (coupling, DIP, open–closed).
5. Validate at the edges and fail fast on broken invariants.
6. Re-read it as a stranger: is anything astonishing, and is complexity where it
   does least harm? Leave the module a little tidier than you found it.
