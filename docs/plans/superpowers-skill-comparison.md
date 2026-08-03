# Superpowers vs. agent-craft: skill overlap and deviation

`obra/superpowers` (github.com/obra/superpowers) was added to Pi's `packages`
list this session (`git:github.com/obra/superpowers` in
`config/files/pi-agent/settings.json`) but not yet fetched/installed. Before
deciding whether to keep both skill sets, merge them, or prune, this compares
its 14 skills against the 4 skills authored into
`config/files/agent-craft/skills/` (`commit`, `execute-plan`, `finish-task`,
`software-design`).

## Coverage map

| Superpowers skill | Closest agent-craft skill | Relationship |
|---|---|---|
| `test-driven-development` | `execute-plan` (§3) | Overlap, different strictness |
| `writing-plans` | — | **Gap** (mine assume a plan already exists) |
| `executing-plans` | `execute-plan` | Overlap, different *layer* (session mechanics vs. methodology) |
| `verification-before-completion` | `finish-task` (§1) | Overlap, different scope (atomic gate vs. bundled checklist) |
| `systematic-debugging` | — | **Gap** |
| `subagent-driven-development` | — | **Gap** (complements the installed `pi-subagents` plugin) |
| `dispatching-parallel-agents` | — | **Gap** |
| `finishing-a-development-branch` | `commit` (§"Scope of action") | Overlap, superpowers far more complete |
| `requesting-code-review` | `finish-task` (§3, weakly) | **Gap** — mine is solo self-review, not subagent dispatch |
| `receiving-code-review` | — | **Gap** |
| `brainstorming` | — | **Gap** — upstream of everything I have |
| `using-git-worktrees` | — | **Gap** (partly covered by harness tooling already, e.g. `isolation: worktree`) |
| `writing-skills` | — | **Gap**, meta-level |
| `using-superpowers` | (none — see AGENTS.md) | Different enforcement philosophy, not a content overlap |

## Where they genuinely overlap

**`execute-plan` §3 vs. `test-driven-development`.** Both prescribe red-green-
refactor. Deviation: mine treats TDD as one ingredient in a larger synthesis
(agile slicing + DDD + TDD/BDD) and states it as a principle. Superpowers
devotes a whole skill to TDD alone, as an **absolute rule** — "Iron Law: NO
PRODUCTION CODE WITHOUT A FAILING TEST FIRST", explicit instruction to delete
and restart on violation, and a table of 13 named rationalizations with direct
rebuttals ("too simple to test", "I'll test after", etc.). Mine has no
enforcement mechanism or exception-handling; superpowers explicitly requires
human approval for the three exceptions it allows (prototypes, generated code,
config).

**`finish-task` §1 vs. `verification-before-completion`.** Same core idea
("don't claim done without evidence"), different granularity. Superpowers
keeps it as a standalone, narrow gate with a banned-phrase list ("should work
now", "probably passes", "I'm confident"). `finish-task` bundles verification
together with docs, self-review, follow-ups, and a commit offer into one
6-step checklist — broader scope, less atomic, easier to partially skip.

**`execute-plan` vs. `executing-plans`.** Naming collision worth flagging on
its own: same near-identical name, different job. Superpowers' version is
about *session/subagent mechanics* for working through an existing plan file
(worktree setup, todo-per-task, stop-and-ask discipline, handoff to
`finishing-a-development-branch`). Mine is about the *engineering methodology*
to apply within each slice (agile + DDD + TDD/BDD). They're complementary, not
duplicative — but if both load, expect confusion from the name alone.

**`commit` vs. `finishing-a-development-branch`.** `commit`'s "Scope of
action" section has one bullet on this ("don't push/PR/force-push unless
asked"). Superpowers has an entire 6-step skill for the branch-completion
decision: verify tests, detect environment (worktree/detached HEAD), confirm
base branch with the human, present a menu (merge / push+PR / keep-as-is),
execute the chosen path, clean up the worktree. This is a real, substantive
gap — my set has no equivalent for "the branch is done, now what."

## Clean gaps (no agent-craft equivalent at all)

- **`writing-plans`** — authoring a plan (bite-sized task sizing, a required
  metadata header, a self-review checklist for the plan itself). My
  `execute-plan` explicitly starts from "you have a plan."
- **`systematic-debugging`** — a rigorous four-phase root-cause process (read
  errors → reproduce → check recent changes → gather evidence at component
  boundaries; pattern analysis; single-hypothesis testing; fix the root cause,
  not the symptom; escalate to "question the architecture" after 3+ failed
  fixes). Nothing in agent-craft addresses debugging methodology.
- **`subagent-driven-development`** / **`dispatching-parallel-agents`** —
  orchestration methodology: per-task subagent isolation, mandatory review
  gates, a persistent ledger for compaction-safe recovery, escalating model
  capability on repeated fix failures. This is close to how *this dotfiles
  session itself* has been operating as an orchestrator, but it isn't written
  down anywhere as a skill. Complements the already-installed `pi-subagents`
  plugin (which provides the mechanics; this would be the methodology).
- **`requesting-code-review`** / **`receiving-code-review`** — a real, sharp
  gap. `finish-task` only has solo self-review; superpowers formalizes review
  as *dispatching a reviewer subagent with fresh context* (not burning the
  coordinator's own context window on the diff) and a separate, opinionated
  protocol for responding to feedback (verify before agreeing, no "you're
  absolutely right!" performative language, push back with technical
  reasoning when warranted).
- **`brainstorming`** — a hard gate before any code: explore context, ask one
  clarifying question at a time, propose 2–3 approaches, write and self-review
  a design doc, get explicit approval, *then* hand off to `writing-plans`.
  Nothing in agent-craft covers this — all four of my skills assume you
  already know what to build. Arguably the highest-value gap since it's
  upstream of everything else.
- **`using-git-worktrees`** — worktree creation/detection mechanics as their
  own skill. Partially moot here since the harness's own tooling
  (`isolation: worktree` on both Claude Code subagents and pi-subagents,
  confirmed compatible in the cross-harness investigation) already handles
  this at the tool-call level.
- **`writing-skills`** — a meta-skill for authoring skills, itself using
  RED-GREEN-REFACTOR: test a pressure scenario *without* the skill first,
  document the exact rationalization an agent uses, write the minimal skill
  that closes it, retest. No equivalent exists for how agent-craft's own
  skills were written.

## A concrete, actionable deviation: my skill descriptions likely violate superpowers' own tested guidance

`writing-skills` states a specific, evidence-based rule it calls Skill
Discovery Optimization: a skill's `description` frontmatter must contain
**only the triggering condition** ("Use when...") and never a summary of the
skill's contents — because testing showed agents follow the *description's*
workflow summary instead of reading the full skill body when both are
present.

All four agent-craft descriptions violate this:

- `commit`: "Use when creating a git commit. **Covers how to stage, split work
  into logical commits, write a lowercase...**" — summarizes content after the
  trigger.
- `execute-plan`: "...**A practical loop synthesizing agile/release-early-
  often..., domain-driven design..., and test-driven + behavior-driven
  development...**" — almost entirely a content summary.
- `finish-task`: "...**A definition-of-done checklist that verifies the
  change..., updates documentation, self-reviews the diff, records follow-
  ups...**" — same pattern.
- `software-design`: "...**Distills SOLID, DRY, KISS, YAGNI, the Law of
  Demeter...**" — same pattern.

If this claim holds (it's presented as tested, not asserted), it's a specific,
fixable defect: trim each description to the trigger condition alone and move
the summary into the skill body. Worth verifying the claim before doing a
blanket rewrite, but the mechanism (agents pattern-match the visible
description instead of loading the body) is plausible and cheap to test.

Related stylistic gap: superpowers targets **<150–200 words** for frequently-
loaded skills; `software-design` and `execute-plan` are both substantially
longer (more discursive, "why" explanations included). Not necessarily wrong
— but a real difference in philosophy: superpowers optimizes for minimum
token cost per load, agent-craft optimizes for a self-contained, readable
principle set.

## The bigger deviation: enforcement philosophy

`using-superpowers` (the meta-skill governing all the others) states a
**mandatory, non-optional invocation rule**: "If a skill applies, you do not
have a choice," with an explicit hierarchy — user instructions, then skill
protocols, then autonomous reasoning — and process skills (brainstorming,
debugging) must run before implementation skills.

This is the same problem this session already diagnosed with Pi's 122B model
not self-invoking advisory skills (see the commit/test-enforcement research
and the `pi-per` PER_TURN/PER_RUN work) — but superpowers' answer is
**rhetorical**: stronger, more absolute mandate language baked into the
meta-skill's own text, gambling that a harder tone changes model behavior.
agent-craft's answer so far is **mechanical**: `PER_TURN.md`/`PER_RUN.md`
injected reminders, with a planned extension-based test/commit gate
(`docs/plans/pi-agent-commit-test-enforcement.md`) that takes the model out of
the loop entirely. These aren't mutually exclusive — superpowers' harder
mandate language could reinforce the mechanical enforcement rather than
replace it.

## Other friction points

- **Plan storage path collision.** Superpowers' `writing-plans` stores plans
  at `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`. This repo's own
  convention is `docs/plans/<name>.md` (no date, no vendor subdirectory,
  pruned on completion rather than dated and kept). If `writing-plans` is
  used as-is in a project following this repo's conventions, expect it to
  create a parallel, differently-shaped plans directory.
- **Naming collision risk beyond `execute-plan`/`executing-plans`**: skill
  names are matched by filename/`name:` field; installing superpowers
  alongside agent-craft doesn't currently create a hard conflict (different
  directory namespaces), but the near-identical names are a footgun for
  whoever (human or model) is choosing which one to invoke.

## Facets in agent-craft with zero superpowers counterpart

Checked every facet of the 4 agent-craft skills against all 14 superpowers
skills. These have no analog anywhere in superpowers:

**`commit`:**
- Linting/formatting discipline before committing (run the linter/formatter;
  verify each split commit would independently pass) — no superpowers skill
  mentions lint/format; the closest analog (`finishing-a-development-branch`)
  only runs tests.
- Splitting unrelated changes into separate logical commits — superpowers'
  only granularity guidance is TDD's "commit" as one step in a 2–5 minute
  cycle, nothing about separating unrelated work.
- Git identity discipline (never override author via `-c user.*`/`--author`/
  `GIT_AUTHOR_*`) — a this-machine concern; superpowers is generic and never
  touches author identity.
- Secret-scanning the diff before staging — no superpowers skill screens for
  API keys/tokens/`.env` values before a commit.
- A specific commit-message style (lowercase `area: summary`, imperative,
  50/72 wrapping) — superpowers never prescribes a message format.
- "Branch first if on main before nontrivial changes" — `finishing-a-
  development-branch` assumes you're already on a feature branch when
  *finishing*; nothing addresses branching before starting.

**`execute-plan`:**
- Domain-Driven Design in full (ubiquitous language, bounded contexts,
  entities/value objects/aggregates, domain logic separated from
  infrastructure) — DDD terminology doesn't appear anywhere across all 14
  superpowers skills.
- BDD framing of tests (Given/When/Then behavior scenarios in the domain
  vocabulary) — `test-driven-development` is test-first but purely
  implementation-focused, never frames tests as behavior scenarios.
- Risk-first slice ordering (do the riskiest/most-uncertain slice early) —
  `writing-plans` addresses task *sizing*, not sequencing by risk.

**`finish-task`:**
- Documentation maintenance as a completion criterion (docstrings, README/
  usage text, changelogs) — `verification-before-completion` is narrowly
  evidence-before-claims; it says nothing about docs.
- Follow-up recording into a repo's backlog/todo file — no superpowers skill
  tracks this.
- A structured closing report format (what changed, how verified, what
  wasn't done, follow-ups) as a communication artifact — superpowers gates
  *process*, not the shape of the final report to the human.

**`software-design`:**
- The entire skill, as a category. None of superpowers' 14 skills touch
  general design/architecture principles at all — no SOLID, DRY, KISS,
  YAGNI, Law of Demeter, Unix philosophy, open-closed, Liskov substitution,
  dependency inversion, fail-fast/robustness, or the long-lived-systems laws
  (Conway's, Lehman's, Gall's, big ball of mud). Superpowers is entirely a
  *process* library (how to work); it has no analog for "how to reason about
  a design."

**Net:** `software-design` occupies a whole domain (principles vs. process)
superpowers doesn't touch at all, while `commit`/`finish-task`/`execute-plan`
each carry several smaller but concrete, machine- or repo-specific facets
(identity handling, secrets, lint discipline, follow-up tracking, DDD/BDD)
that superpowers' broader, more generic skills never get into.

## Recommendation (not yet decided)

Don't prune agent-craft's four skills — they cover ground superpowers
duplicates only partially (the DDD/agile-slicing synthesis in `execute-plan`
has no superpowers equivalent) and are already wired into both harnesses.
Superpowers' clean gaps (`brainstorming`, `systematic-debugging`,
`writing-plans`, the code-review pair, `finishing-a-development-branch`) are
worth adopting for the capability alone. The concrete next decisions:

1. Fetch/install superpowers (`pi install git:github.com/obra/superpowers`)
   and see it load for real before deciding anything else.
2. Decide whether to rename my `execute-plan` to reduce confusion with
   `executing-plans`, given they now coexist.
3. Test the Skill Discovery Optimization claim against agent-craft's
   descriptions and rewrite them if it holds.
4. Decide whether `using-superpowers`'s harder mandate language should be
   folded into `agent-craft/AGENTS.md`'s own framing.
