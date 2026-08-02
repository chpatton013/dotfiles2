# Consolidating AI coding-harness config (skills, agents, instructions)

## Goal

Chris uses two coding harnesses today — Claude Code (`~/.claude/`) and Pi Agent
(`~/.pi/agent/`, this repo's `config/roles/pi-agent`) — and has been building up
skills/agents in each independently. Consolidate the reusable material into one
version-controlled, canonical source in this repo, symlinked out to every
harness that can use it, so writing a skill once makes it available everywhere.
Also leave the design open to future harnesses (Cursor, Codex CLI, Windsurf,
Aider, etc.) without redoing the architecture.

## Current state (inventoried this session)

**Claude Code** (`~/.claude/`, not managed by dotfiles today):
- `CLAUDE.md` — global instructions (currently about comment/doc writing style).
- `skills/{ste-writing,documentarian,humanizer}/SKILL.md` — frontmatter:
  `name`, `description` (`humanizer`'s description uses YAML block-scalar
  `|`, otherwise identical shape to Pi's).
- `agents/documentarian.md` — frontmatter: `name`, `description`, **`tools`,
  `model`** (a superset Pi's skills don't have — this is Claude Code's
  subagent concept, not directly analogous to a Pi skill).
- `settings.json` — machine/session prefs (`model`, `enabledPlugins`
  `theme`, `effortLevel`, `editorMode`) — **not** reuse material, this is
  per-machine/per-preference state, out of scope for symlinking.
- No `commands/` in use yet (Claude Code supports slash-commands here).

**Pi Agent** (`~/.pi/agent/`, symlinked today from
`config/files/pi-agent/` via `config/roles/pi-agent`):
- `AGENTS.md` — global engineering-practices instructions (commit/test
  discipline, code quality, follow-ups — see
  `docs/plans/improving-pi-agent-engineering-practices.md`).
- `skills/{commit,finish-task,software-design,execute-plan}/SKILL.md` —
  same `name`/`description` frontmatter shape as Claude Code's.
- `PER_TURN.md` / `PER_RUN.md` — read by the `pi-per` extension (this
  repo's own `~/projects/pi-per`), re-injected at end-of-context. **Pi-specific
  mechanism**, not portable to other harnesses.
- `settings.json` / `models.json` — Pi-specific provider/model config, not
  reuse material.
- A `@tintinweb/pi-subagents` plugin is installed; its manifest shape is
  compared against Claude Code's subagent format in the Tier 3 section below
  (checked this session — narrow compatible subset, most fields don't match).

**Key finding: skill frontmatter already matches.** A `SKILL.md` written for
one harness loads correctly in the other with zero changes — the shared
`skills/` tree can be a single symlinked directory, exactly like this repo
already does for Pi (`config/roles/pi-agent/tasks/main.yml` links the whole
`skills` dir).

**Bigger finding: `AGENTS.md` is now a real cross-harness standard.** The
Linux Foundation's Agentic AI Foundation (formed Dec 2025, OpenAI/Anthropic/
Block founding members) governs it. It's read natively by Codex CLI, Cursor,
GitHub Copilot, Gemini CLI, Aider, Windsurf, Zed, Devin, Jules, VS Code, and
JetBrains Junie — and **Claude Code now reads `AGENTS.md` too**, with
`CLAUDE.md` remaining its own richer/preferred format when both exist. Plain
markdown, no frontmatter, no required sections.

## Architecture: three tiers of reuse, by how portable each artifact is

**Tier 1 — global instructions (`AGENTS.md`): portable everywhere.**
One canonical `AGENTS.md`, symlinked (or content-identical) into every
harness's expected location. Broadest reach, cheapest to maintain.

**Tier 2 — skills (`SKILL.md`): portable across Claude Code + Pi today.**
One canonical `skills/` tree, whole-directory-symlinked into both harnesses'
`skills/` dirs, since the frontmatter shape already matches. Extend to a third
harness only if/when it converges on the same shape — don't assume it will.

**Tier 3 — agents: a narrow, real, confirmed-compatible subset; the rest isn't
portable.** Checked both official field tables (Claude Code's subagent docs;
`pi-subagents`' own README, which explicitly models itself on Claude Code —
"same tool names, calling conventions, and UI patterns"):

| Concept | Claude Code | pi-subagents | Verdict |
|---|---|---|---|
| Identity | `name:` (required) | *no field* — identity = filename | different mechanism |
| Description | `description:` (required) | `description:` (optional, defaults to filename) | ✅ compatible |
| Tools | `tools:` — Claude's own vocabulary (`Read`, `Edit`, `Bash`, `Glob`, `WebFetch`, …) | `tools:` — Pi's small abstract set (`read`, `grep`, `bash`, `find`, `ls`, `write`, `edit`, `*`/`all`/`none`) | ❌ same key, incompatible vocabularies |
| Tool denylist | `disallowedTools` | `disallowed_tools` | ❌ different key (casing) |
| Turn limit | `maxTurns` | `max_turns` | ❌ different key (casing) |
| Background | `background:` | `run_in_background:` | ❌ different key name |
| Thinking/effort | `effort:` (low/medium/high/xhigh/max) | `thinking:` (off/minimal/low/medium/high/xhigh/max) | ⚠️ overlapping values, different key |
| MCP | `mcpServers:` | handled via a different `extensions:` mechanism | ❌ not portable |
| Hooks, color, initialPrompt | present | no equivalent | ❌ Claude-only |
| Model | alias/full-id/`inherit` | fuzzy-matched against Pi's own configured models, cross-provider fallback | ✅ format compatible; ⚠️ availability depends on what's configured (Pi defaults to the local vLLM stack, not Anthropic) |
| Memory scope | `memory:` — `user`/`project`/`local` | `memory:` — `project`/`local`/`user` (same 3, same semantics) | ✅ exact match |
| Worktree isolation | `isolation: worktree` | `isolation: worktree` | ✅ exact match, same key *and* value |

**Conclusion: full agent files are not safely symlinkable.** Most fields
differ in vocabulary (`tools`), casing (`maxTurns`/`max_turns`,
`disallowedTools`/`disallowed_tools`, `background`/`run_in_background`), or
don't exist on the other side. But since only `name`+`description` are
*required* by Claude and *nothing* is required by Pi, **a minimal shared agent
file — just `name:`/`description:` plus a system-prompt body, with all
tool/model/turn-limit fields omitted — is safely symlinkable**, because both
harnesses fall back to permissive defaults (inherit tools, inherit model) when
those fields are absent. Anything needing tool restrictions or a pinned model
must be hand-authored per harness, not shared.

Slash commands (Claude Code's `commands/`) and Pi's prompt-templates mechanism
remain genuinely unverified — investigate before assuming portability, same
caution as agents before this check.

## Proposed layout in this repo

Follow the existing role/symlink convention (see `AGENTS.md` primer,
"Anatomy of a config role"):

```
config/files/agent-craft/
  AGENTS.md              # canonical global instructions (Tier 1)
  skills/
    commit/SKILL.md
    finish-task/SKILL.md
    software-design/SKILL.md
    execute-plan/SKILL.md
    ste-writing/SKILL.md
    documentarian/SKILL.md
    humanizer/SKILL.md    (+ LICENSE)
  agents/
    documentarian.md       # Tier 3: canonical body; frontmatter portability TBD
```

(`agent-craft` is a placeholder name — pick whatever reads best; it just needs
to not collide with `config/files/agent-*` conventions used elsewhere.)

New role `config/roles/claude-code/` (standard recipe: `defaults` for
`claude_config_dir: ~/.claude`, `tasks` creating the directory if absent, then
symlinking `CLAUDE.md` → `agent-craft/AGENTS.md`, `skills` → `agent-craft/
skills`, `agents` → `agent-craft/agents`). **Symlink only the specific
subpaths that are reuse material** — never the whole `~/.claude/` tree, since
it also holds session history, telemetry, caches, and per-machine
`settings.json`, none of which belong in version control.

Update `config/roles/pi-agent/tasks/main.yml` to link its `AGENTS.md`/`skills`
from the new shared `agent-craft/` location instead of its own
`config/files/pi-agent/`, leaving `config/files/pi-agent/` holding only
genuinely Pi-specific material: `PER_TURN.md`, `PER_RUN.md`, `settings.json`,
`models.json`, the node shell-rc fragment.

Add `- {role: claude-code, tags: [claude-code]}` to `config.playbook.yml`
(alphabetical, per convention).

## Migration steps

1. Create `config/files/agent-craft/{skills,agents}/`.
2. `git mv` the four Pi skills and `AGENTS.md` from `config/files/pi-agent/`
   into `agent-craft/`; update `config/roles/pi-agent/tasks/main.yml`'s
   symlink `src` to point at the new path (dest stays the same — still lands
   in `~/.pi/agent/`).
3. Copy the three Claude-only skills (`ste-writing`, `documentarian`,
   `humanizer` + its `LICENSE`) and the `documentarian` agent from
   `~/.claude/` into `agent-craft/` — these currently exist **only** on disk,
   untracked, so this is their first time entering version control.
4. **Reconcile the two `AGENTS.md`-shaped documents**, since they currently
   cover different, non-overlapping ground: Pi's `AGENTS.md` is engineering
   discipline (commit/test/docs), Claude's `CLAUDE.md` is writing style
   (timeless comments, why-not-what, STE-adjacent). Merge into one canonical
   `AGENTS.md` covering both concerns — **this needs your editorial pass**,
   not a silent auto-merge, since tone/scope choices are yours to make.
5. Write the new `claude-code` role; symlink `CLAUDE.md` from the merged
   `AGENTS.md` (same file — whichever name Claude Code actually reads, the
   content is single-sourced).
6. Apply with `config/config.sh --tags claude-code,pi-agent` and verify both
   harnesses load the skills/instructions (Claude Code's startup skill list;
   Pi's startup header, per earlier sessions this repo already validated).

## Open questions (need your input or a quick investigation before building)

- **Commands / prompt templates** — Claude Code's `commands/` slash-commands
  vs. Pi's `prompt-templates.md` mechanism: shape unconfirmed. Decide whether
  this is worth reuse-engineering now or left for later (lower value than
  Tiers 1–2 since neither harness has many built yet).
- **`AGENTS.md` global vs. project-level per other harness** — the standard
  guarantees *project-root* `AGENTS.md` discovery broadly; a **global**
  (home-directory) `AGENTS.md` outside a project is confirmed for Claude Code
  and Pi, but not verified for Cursor/Codex/Windsurf/etc. If a future harness
  is adopted, check its docs for global-instructions support before assuming
  the same symlink pattern applies — some may only read a project-local file.
- **Settings/plugins are deliberately out of scope** — `enabledPlugins`,
  `model`, `theme`, etc. differ by harness and by machine (e.g. a work-only
  Slack plugin) and shouldn't be unified; only *content* (instructions,
  skills, agent bodies) is being consolidated here.

## Future-proofing checklist (adding a new harness later)

1. Does it read a global (not just project-root) instructions file? If yes,
   symlink it to the canonical `AGENTS.md` (Tier 1 — cheap, high value).
2. Does it have a skills-like, on-demand-loaded procedure format with
   frontmatter matching `name`/`description`? If yes, symlink the shared
   `skills/` tree (Tier 2). If its format diverges, don't force it — note the
   divergence and revisit.
3. Does it have a subagent/command concept? Treat as Tier 3: write the
   canonical body once, hand-adapt the harness-specific
   frontmatter/wrapper — don't assume portability without checking the format
   first (this bit us with the `prompt` vs. `dotfiles-prompt` naming collision
   earlier this session; verify before wiring).
4. Never symlink a harness's entire config directory — only the specific
   reuse-material subpaths. Harness dirs accumulate session state, caches, and
   machine-specific settings that must never enter version control.
