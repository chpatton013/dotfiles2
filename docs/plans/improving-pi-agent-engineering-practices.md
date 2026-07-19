# Improving Pi Agent Software Engineering Practices

## Context

I run Pi Agent (`@earendil-works/pi-coding-agent`) against a locally-hosted
inference service (vLLM serving Qwen3.5 MoE models — see
`config/files/pi-agent/models.json`). Pi works, but out of the box it lacks the
"good software engineering practices" that Claude Code exhibits:

- **Automated git commits** at logical checkpoints, with well-formed messages.
- **Test/verify before declaring done.**
- **Documentation discipline** (docstrings, README/usage updates).
- **Follow-up management** for deferred work.
- **Self-review / PR hygiene.**

The goal of this doc is a concrete design + roadmap for closing those gaps in
*this repo's* Pi Agent configuration.

## How Pi is configured today

Config lives in `config/files/pi-agent/` and is symlinked by
`config/roles/pi-agent/` into **both** `~/.config/dotfiles/pi/agent/` and
`~/.pi/agent/` (Pi reads the latter). Current files:

- `settings.json` — provider (`vLLM`), default model
  (`AxionML/Qwen3.5-122B-A10B-NVFP4`), `defaultProjectTrust: always`, and the
  enabled plugin `packages`.
- `models.json` — the vLLM provider endpoint and two Qwen3.5 models.
- `3-pi-agent.sh` — shellrc fragment (PATH for the pi node prefix).
- **`AGENTS.md`** and **`skills/`** — added by this plan (see below).

### Plugins actually enabled (`settings.json` `packages`)

All plugins the earlier draft *listed* are enabled, plus four it omitted.
Enabled today:

| Plugin | Role |
| --- | --- |
| `@cad0p/pi-timestamps` | timestamps in transcript *(not in old list)* |
| `@ff-labs/pi-fff` | fast file find / grep |
| `@juicesharp/rpiv-ask-user-question` | structured questions |
| `@juicesharp/rpiv-btw` | "by the way" notifications |
| `@juicesharp/rpiv-todo` | persistent todo list w/ deps + overlay UI |
| `@narumitw/pi-goal` | `/goal` mode, `goal_complete` tool |
| `@narumitw/pi-plan-mode` | read-only `/plan` mode |
| `@npm-ken/pi-bar` | status bar (git branch, model, activity) |
| `@tintinweb/pi-subagents` | subagents *(not in old list)* |
| `@zigai/pi-prompt-history` | prompt history *(not in old list)* |
| `context-mode` | large-file context tools |
| `pi-auto-theme` | light/dark auto theme *(not in old list)* |
| `pi-lens` | LSP diagnostics, ast-grep/tree-sitter |
| `pi-mcp-adapter` | MCP integration |
| `pi-memory-stone` | cross-session memory |

Notable: **there is no `pi-git`/commit plugin and no test-runner plugin** in
the ecosystem the user has adopted, and until this plan there was **no
`AGENTS.md` and no skills** — so nothing was actually steering the model toward
commit/test/doc discipline. That is the core gap: capability plugins are
present, but *behavioral* guidance was absent.

## Pi's extension mechanisms (what we have to work with)

Researched from the Pi docs (`earendil-works/pi`, `pi.dev`):

- **Context files** — `AGENTS.md` are loaded at startup and concatenated into
  the system prompt, discovered from `~/.pi/agent/` (global), then each parent
  dir, then cwd. Project files layer over the global one. This is the idiomatic
  home for always-on behavioral rules.
- **System-prompt override** — `~/.pi/agent/SYSTEM.md` (replace) or
  `APPEND_SYSTEM.md` (append), plus `.pi/` project variants. Heavier hammer;
  `AGENTS.md` is preferred for our needs (append-style, non-destructive).
- **Skills** — `SKILL.md` (frontmatter: `name`, `description`, optional
  `allowed-tools`, `disable-model-invocation`, …) discovered from
  `~/.pi/agent/skills/` and `~/.agents/skills/` (global) or `.pi/skills/` and
  `.agents/skills/` (project). Progressive disclosure: only name+description sit
  in the prompt; the body is `read` on demand or via `/skill:name`. Ideal for
  detailed procedures we don't want inflating every turn.
- **Plugins/packages** — npm/git modules listed in `settings.json` `packages`;
  can add tools, commands, TUI, events. Installing one is a user decision.

Design principle (matches Pi's minimal-prompt philosophy): keep the always-on
`AGENTS.md` short and principled; push step-by-step procedure into skills.

## Per-gap recommendation

### 1. Git integration / automated commits

- **Mechanism: `AGENTS.md` principles + a `commit` skill.** Git is already
  available via the shell; no plugin is required to commit well. The missing
  piece was *guidance*, now supplied: commit at logical checkpoints, message
  style (`area: summary`), never override git identity, never commit secrets,
  don't push/PR unasked.
- **Status-bar "commit mode" segment** — `@npm-ken/pi-bar` already shows the
  git branch. A dedicated commit indicator is a nice-to-have that needs pi-bar
  config; left as a decision point, not required for the discipline.
- **Auto-commit-on-stop** (fully automatic, no prompt) would require a plugin
  or a Pi *extension* hooking a stop/idle event. **Decision point** — I lean
  *against* silent auto-commit for a local-model agent (higher error rate);
  agent-proposed commits via the skill are safer.

### 2. Testing / verify before done

- **Mechanism: `AGENTS.md` "definition of done" + a `finish-task` skill.**
  Encodes: detect the project's build/test commands, run the tests covering the
  change, or exercise the code directly, and never imply tests passed when they
  weren't run. Project-specific because every repo tests differently; a plugin
  can't know the command, but the skill teaches the model how to find it.
- No test-runner plugin recommended; `pi-lens` already surfaces LSP/static
  diagnostics as a complementary signal.

### 3. Docs / docstrings

- **Mechanism: `AGENTS.md` text** (update docstrings and stale docs/comments;
  match surrounding style; don't gold-plate). This is judgment, not automation —
  instruction text is the right and only sensible tool. No plugin.

### 3b. Design & architecture intuition

- **Mechanism: a `software-design` skill** (user-requested). Local models
  benefit from an explicit, loadable reference on *how* to design well, not just
  "prefer small units". The skill distills the classic principles — SOLID, DRY /
  single source of truth, KISS, YAGNI, Law of Demeter, loose coupling,
  open–closed, conservation of complexity, least astonishment, Unix philosophy,
  fail-fast + robustness principle — plus the realities of maintaining
  long-lived systems (Lehman's laws, Conway's law, Gall's law, big-ball-of-mud).
  Delivered as a skill (not always-on `AGENTS.md` text) so it costs nothing until
  a real design/refactor decision loads it; `AGENTS.md`'s Code-quality section
  points to it.

### 3c. Executing a plan (how to work, not what to build)

- **Mechanism: an `execute-plan` skill** (user-requested). Where
  `software-design` covers *principles*, this covers *process*: how to actually
  work through a multi-step plan. It synthesizes release-early/often + agile
  (small vertical increments, ship/commit often, adapt the plan) → DDD (model
  the slice in a ubiquitous language, explicit bounded contexts) → TDD framed as
  BDD (red-green-refactor where each test is a behavior scenario in that
  language). Presented as one coherent loop, cross-linked to `software-design`
  (refactor step) and `finish-task`/`commit` (per-slice close-out).
  `AGENTS.md`'s Code-quality section points to it for multi-step work.

### 4. Follow-up management

- **Mechanism: existing `@juicesharp/rpiv-todo` + `pi-memory-stone`, plus an
  `AGENTS.md` note** to surface deferred work in the closing summary and, in
  repos that keep one (like this one's `docs/followups.md`), append to it.
  Already well covered by plugins; only the *habit* was missing. No new plugin.

### 5. Review / PR automation

- **Mechanism: `AGENTS.md` self-review checklist** (built into the
  finish-task flow). Full PR-description generation is environment-specific
  (`gh`, remotes) and the user's local-model workflow may not push at all —
  **decision point**: add a `pr` skill / `gh` integration only if the user
  actually opens PRs from Pi. Not built here.

## What this plan implemented

Safe, in-repo, no plugin installs, no live `config.sh`:

1. `config/files/pi-agent/AGENTS.md` — global Pi instructions encoding the
   definition-of-done, commit, code-quality, follow-up, and review discipline.
   Short and principled; points to the skills for detail.
2. `config/files/pi-agent/skills/finish-task/SKILL.md` — the verify → document
   → self-review → record-follow-ups → offer-to-commit checklist.
3. `config/files/pi-agent/skills/commit/SKILL.md` — how to stage, split, and
   message a commit; run the linter/formatter; identity and secret guardrails.
4. `config/files/pi-agent/skills/software-design/SKILL.md` — design/architecture
   intuition (user-requested; see gap 3b), drawing on SOLID, DRY, KISS, YAGNI,
   Law of Demeter, loose coupling, open–closed, conservation of complexity,
   least astonishment, single source of truth, Unix philosophy, fail-fast,
   robustness principle, and — for long-lived systems — Conway's law, Lehman's
   laws, Gall's law, and big-ball-of-mud.
5. `config/files/pi-agent/skills/execute-plan/SKILL.md` — how to execute a plan
   (user-requested; see gap 3c): the small-increment loop synthesizing
   release-early/often + agile, DDD, and TDD/BDD, cross-linked to the
   software-design and finish-task/commit skills.
6. `config/roles/pi-agent/tasks/main.yml` — symlink `AGENTS.md` and the
   `skills/` directory into both `~/.config/dotfiles/pi/agent/` and
   `~/.pi/agent/` (alongside the existing `settings.json`/`models.json` links).
   The whole `skills/` dir is linked, so new skills need no role change.

These are global (apply to every project Pi runs on this machine); a
project-level `AGENTS.md` still overrides them.

## Roadmap

- [x] Map current config and the actually-enabled plugin set.
- [x] Research Pi's context-file / SYSTEM.md / skills / packages mechanisms and
      Claude Code's commit + verify workflow being emulated.
- [x] Decide the mechanism per gap (table above): instruction text + skills for
      git/test/docs/review; existing plugins for follow-ups.
- [x] Write `config/files/pi-agent/AGENTS.md` (global discipline).
- [x] Write `skills/finish-task/SKILL.md` and `skills/commit/SKILL.md`.
- [x] Write `skills/software-design/SKILL.md` (user-requested design intuition;
      includes Gall's law).
- [x] Write `skills/execute-plan/SKILL.md` (user-requested plan-execution loop).
- [x] Wire `AGENTS.md` + `skills/` into `config/roles/pi-agent/tasks/main.yml`.
      (The role links the whole `skills/` dir, so `execute-plan` needs no change.)
- [ ] **Apply + validate on the live machine**: `config/config.sh --tags
      pi-agent` (user runs it — this plan does not), then confirm the symlinks
      resolve (`~/.pi/agent/AGENTS.md`,
      `~/.pi/agent/skills/{finish-task,commit,software-design,execute-plan}`)
      and, in a Pi session, that `/skill:finish-task`, `/skill:commit`,
      `/skill:software-design`, and `/skill:execute-plan` load.
- [ ] **Observe real behavior** on a few tasks: does the local model actually
      run tests, commit at checkpoints, and update docs? Tune the wording of
      `AGENTS.md`/skills toward whatever the model under-does. (Qwen3.5 may need
      more explicit, imperative phrasing than Claude.)
- [ ] **Decision point — auto-commit:** keep agent-proposed commits (current
      design) or install/build a stop-event extension for automatic commits?
      Recommend staying manual until behavior is trusted.
- [ ] **Decision point — commit-mode status segment:** configure
      `@npm-ken/pi-bar` to show a commit/dirty indicator? Cosmetic.
- [ ] **Decision point — PR automation:** does the user open PRs from Pi? If so,
      add a `pr` skill (+`gh`) generating a description from the diff; otherwise
      drop it.
- [ ] **Optional — project-level overrides:** for repos with unusual test/commit
      conventions, add a repo-local `AGENTS.md`/`.pi/` that layers over the
      global one (this dotfiles repo already has its own `CLAUDE.md`, which Pi
      reads too).
