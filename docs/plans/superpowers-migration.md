# Migrating superpowers content into agent-craft

Decision made (see `docs/plans/superpowers-skill-comparison.md`): vendor and
adapt superpowers' content into `config/files/agent-craft/`, rather than keep
`obra/superpowers` as a live plugin. A live plugin only reaches Pi (Claude
Code would need its own separate marketplace install, reintroducing the
per-harness divergence agent-craft exists to eliminate), and it's all-or-
nothing — it can't be pruned to avoid the bloat/duplication already found.
This plan is the concrete migration: what to adopt, what to merge into
existing skills, what to skip, and in what order.

## Per-skill disposition (all 14)

**Adopt as new skills** (adapted to agent-craft's voice and conventions):

| New file | From | Rename reason |
|---|---|---|
| `agent-craft/skills/brainstorming/SKILL.md` | `brainstorming` | none |
| `agent-craft/skills/systematic-debugging/SKILL.md` | `systematic-debugging` | none |
| `agent-craft/skills/writing-plans/SKILL.md` | `writing-plans` | none |
| `agent-craft/skills/code-review/SKILL.md` | `requesting-code-review` + `receiving-code-review` | merged: two halves of one workflow, avoids two near-identical files |
| `agent-craft/skills/finish-branch/SKILL.md` | `finishing-a-development-branch` | renamed to match the `finish-task` naming family |
| `agent-craft/skills/executing-plans/SKILL.md` | `executing-plans` | none — this covers session/subagent *mechanics* (worktree, todo-per-task, stop-and-ask, handoff). No collision: my existing `execute-plan` (engineering *methodology* — agile/DDD/TDD-BDD) is being renamed to `writing-code` instead (see below), so the incoming skill keeps its original name unchanged. Complementary, not duplicate — cross-link both directions. |
| `agent-craft/skills/subagent-driven-development/SKILL.md` | `subagent-driven-development` (+ `dispatching-parallel-agents` folded in as a subsection) | merged: parallel dispatch is a special case of subagent-driven work, not a separate concern |
| `agent-craft/skills/writing-skills/SKILL.md` | `writing-skills` | none — meta-skill, governs how this whole migration's new skills get authored |

Also renaming an existing agent-craft skill as part of this migration:
`execute-plan` → `writing-code` (gerund form, matching the naming convention
the adopted superpowers skills use — `brainstorming`, `executing-plans`,
`writing-plans`, `writing-skills`). This frees up the collision with the
incoming `executing-plans` skill, so that one is adopted verbatim under its
original name instead of being renamed itself.

**Merge into an existing skill instead of adding a new file** (the overlap
found in the comparison doc was real duplication, not complementary layers):

- `test-driven-development` → fold its "Iron Law" framing (no production code
  without a failing test) and a condensed rationalization-rejection list into
  `writing-code` §3, in place. Don't create a second, competing TDD skill.
- `verification-before-completion` → fold its "evidence before claims" framing
  and a condensed banned-phrases callout ("should work now", "probably
  passes") into `finish-task` §1, in place.

**Explicitly not adopting** (with reason):

- `using-git-worktrees` — redundant here. Both Claude Code subagents and
  `pi-subagents` natively support `isolation: worktree` (confirmed compatible
  in the cross-harness investigation), so the harness already automates the
  create/detect/cleanup mechanics this skill exists to hand-hold. A skill
  duplicating built-in tool behavior would only add bloat.
- `using-superpowers` — this is superpowers' own meta-framework, written
  around its brand (`superpowers:<name>` cross-references that won't exist in
  my skill set). Don't adopt as a file. Instead, fold its actual insight —
  mandatory, non-optional skill invocation, and a process-skills-before-
  implementation-skills hierarchy — into `agent-craft/AGENTS.md` itself (see
  below). That insight is exactly the fix for the self-invocation problem
  this session already diagnosed with Pi's 122B model; it belongs in the
  always-loaded instructions, not a skill that has to be self-invoked to take
  effect.

## Required adaptations (not a verbatim copy-paste)

1. **Plan storage path.** Superpowers' `writing-plans` hardcodes
   `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`. Agent-craft skills
   run across every project I work in, not just this dotfiles repo, so the
   adapted skill should say: use the project's existing plan-storage
   convention if one exists (e.g. this repo's own `docs/plans/<name>.md`, no
   date, pruned on completion), otherwise default to a date-prefixed path —
   `docs/plans/YYYY-MM-DD-<name>.md` — since encouraging the date prefix as
   the fallback recommendation avoids ambiguity/collisions in projects that
   haven't settled on their own convention yet. Don't hardcode a
   superpowers-branded path.
2. **Voice.** Superpowers addresses "your human partner" throughout. Rewrite
   to match agent-craft's existing direct voice (plain "you"/"I", the way
   `commit` and `finish-task` already read).
3. **Tone, case by case.** Superpowers leans on ALL-CAPS "Iron Law"/"STOP"
   framing everywhere. Keep that harder register where it's earned — the two
   merges above (TDD, verification) are exactly the safety-critical,
   easy-to-rationalize-away cases where forceful language helps a model that
   doesn't reliably self-enforce. Don't blanket-apply it to judgment-based
   content like `brainstorming` or `software-design`, which read better in
   agent-craft's calmer, principle-based register. Spot-check each adopted
   skill individually rather than deciding this globally up front.
4. **`finish-branch` scope.** Superpowers' `finishing-a-development-branch`
   assumes a manual, foreground workflow (detect worktree/detached HEAD,
   confirm base branch, present a menu). That's for when *the main session*
   is working a feature branch directly — subagent-dispatched work already
   gets its worktree lifecycle automated by `isolation: worktree`. State this
   scope explicitly in the adapted skill so it doesn't redundantly describe
   mechanics the harness already automates for subagent dispatch.
5. **Skill Discovery Optimization.** Per `writing-skills`' own (tested) claim,
   every skill's `description:` frontmatter should contain only the trigger
   condition, never a content summary. Apply this to **every** skill in
   `agent-craft` while touching them — the original 4 (`committing-changes`,
   `writing-code`, `finish-task`, `software-design` all currently violate it,
   per the comparison doc, under their pre-rename names) and all
   newly-adopted ones. This is a global pass, not optional per-file polish.

## Edits to existing agent-craft files (in place)

- **`execute-plan/` → `writing-code/SKILL.md`** — rename the directory/file
  as part of this pass (frees up the name for the incoming `executing-plans`
  skill, which is now adopted unchanged under its original name — see
  above); strengthen §3 per the TDD merge above; add a cross-reference to the
  new `executing-plans` skill for session/subagent mechanics (so the
  methodology-vs-mechanics split is explicit, not just implied by two
  similarly-named files existing).
- **`finish-task/SKILL.md`** — strengthen §1 per the verification merge above;
  cross-reference the new `finish-branch` skill for the "whole branch is
  done" scenario (distinct from "this commit is done").
- **`commit/` → `committing-changes/SKILL.md`** — rename the directory/file:
  "commit" reads ambiguously as a bare noun/verb, and the gerund form is
  explicit about the action while matching the convention established by
  `writing-code` and the adopted superpowers skills; add a cross-reference to
  `finish-branch` in its "Scope of action" section.
- **`software-design/SKILL.md`** — no content change (confirmed zero overlap
  with superpowers); only touch it for the description-format pass.
- **`AGENTS.md`** — two changes:
  1. Fold in `using-superpowers`'s core insight: make skill loading mandatory
     rather than advisory ("if a skill applies, load it — that's not
     optional"), and state a process-before-implementation order (design/
     investigation skills — `brainstorming`, `systematic-debugging` — before
     methodology skills — `writing-plans`, `writing-code`, `executing-
     plans` — before close-out skills — `finish-task`, `committing-changes`,
     `finish-branch`, `code-review`).
  2. Add pointers to every newly-adopted skill in the right section (a new
     "Design & investigation" area for `brainstorming`/`systematic-debugging`,
     a "Code review" mention alongside `finish-task`, etc.) — mirroring how
     the four originals are already referenced today.
- **`PER_RUN.md`** — add a `brainstorming` pointer, ordered *before* the
  existing `writing-code` mention (brainstorming is upstream: it's the
  design/approval gate before planning execution starts).
- **`PER_TURN.md`** — add a `systematic-debugging` pointer ("hit a bug or test
  failure → this skill before proposing a fix"), since "propose a fix without
  investigating" is exactly the kind of per-turn lapse this file exists to
  catch — the same reasoning that put `committing-changes`/`finish-task`
  there.

## Not touching

- No changes to `config/roles/claude-code` or `config/roles/pi-agent` — both
  already symlink the whole `agent-craft/skills/` directory, so new skill
  subdirectories appear automatically with no role/task edits.
- Remove `git:github.com/obra/superpowers` from `config/files/pi-agent/
  settings.json`'s `packages` list once the content is vendored — it was
  never installed/fetched, so this is a clean revert, not an uninstall.

## Sequencing

This is naturally parallelizable — each adopted/merged skill is close to
independent. Recommended batches when this is greenlit:

1. **Batch A (new files, low interdependency):** `brainstorming`,
   `systematic-debugging`, `writing-plans`, `code-review`, `writing-skills`.
2. **Batch B (naming/scope-sensitive, do together):** the `execute-plan` →
   `writing-code` rename and `commit` → `committing-changes` rename (so the
   `execute-plan` name is free before `executing-plans` lands), `executing-
   plans` (cross-links `writing-code`), `finish-branch` (cross-links
   `committing-changes`/`finish-task`), `subagent-driven-development`.
3. **Batch C (edits to existing files, do last so cross-references in A/B
   resolve to real files):** the `writing-code`/`finish-task`/`committing-
   changes` in-place edits, `AGENTS.md`, `PER_RUN.md`, `PER_TURN.md`, and the
   description-format pass across all ~12 skills.
4. Drop the `settings.json` package entry; validate both harnesses still load
   everything cleanly (same check used after the original agent-craft
   migration — restart Claude Code, check Pi's startup skill list).

Nothing implemented yet — this is the plan for review before dispatching any
of it.
