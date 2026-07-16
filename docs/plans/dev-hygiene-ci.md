# Dev-Hygiene Tooling: File Validation + GitHub Actions CI

## Context

This repo has no automated verification at all: no `.github/`, no
`.pre-commit-config.yaml`, no `.yamllint`, no `.ansible-lint` (see
`AGENTS.md`: *"There are no build systems, tests, or CI here"*). Correctness
today rests entirely on manually applying a playbook and eyeballing the result.

The followup **"Add dev-hygiene tooling: file validation + GitHub Actions CI"**
(`docs/followups.md`, *Repo hygiene & tooling*) asks us to port the patterns
from the user's `chiiiirrus` repo (https://github.com/chpatton013/chiiiirrus/):
file validation (pre-commit hooks / formatters / linters) plus a GitHub Actions
CI workflow that runs on push/PR.

**We do not have access to `chiiiirrus`.** This plan proposes a sensible
standard setup; every concrete choice below (hook set, tool versions, config
knobs, workflow shape) must be **reconciled against the actual chiiiirrus
patterns when this is implemented** — prefer chiiiirrus's conventions where they
differ, so the two repos stay consistent. This is the single biggest open
question (see Risks).

### What lives here (lint surface, by prevalence)

- **YAML** — ~141 `.yml` files: Ansible playbooks (`config/config.playbook.yml`,
  `setup-*/setup.playbook.yml`) and roles under `config/roles/` (29 roles) and
  `setup-{macos,ubuntu,archlinux}/roles/`. This is the dominant file type and the
  main source of both value and lint noise.
- **Shell** — ~57 `.sh` / `.bash` / `.zsh` scripts (entrypoints like
  `config/config.sh`, `setup-*/setup.sh`; the `color-theme` scripts; shellrc
  fragments). Note fragments are sourced, not standalone, and shells are mixed
  (bash, zsh, POSIX sh) — relevant to shellcheck dialect handling.
- **Lua** — 2 files: `config/files/neovim/init.lua`,
  `config/files/wezterm/wezterm.lua`.
- **JSON** — `config/files/pi-agent/{settings,models}.json`,
  `config/files/karabiner/*.json`, `.vscode/*.json`.
- **gitconfig** — `config/files/git/gitconfig-fragments/*.gitconfig` (no good
  dedicated linter; treat as generic-hooks only).

### Constraints from `AGENTS.md` worth encoding

- YAML: leading `---` + blank line; 2-space indent; Jinja without inner spaces
  (`{{item}}`, not `{{ item }}`); `with_items` lists alphabetized.
- Shell: `#!/bin/bash --norc`, `set -euo pipefail`, the `script_dir=...`
  preamble.
- Rendered files get restrictive modes; **templates under `templates/` are Jinja,
  not valid YAML/plain files** — must be excluded from most linters.

## Approach

Two layers, sharing one source of truth (`.pre-commit-config.yaml`) so local and
CI run identically:

1. **pre-commit** (local + CI) — the `pre-commit` framework orchestrates all
   hooks. Developers can `pre-commit install`; CI runs `pre-commit run
   --all-files`. One config, no drift between local and CI.
2. **GitHub Actions** — a workflow on push/PR that installs pre-commit and runs
   it across the repo (plus any checks awkward to express as a hook).

**Start lenient, ratchet later.** With 141 YAML files and 29+ roles written
before any linter existed, a strict `ansible-lint` will almost certainly produce
hundreds of findings. Strategy:

- Turn on the **cheap, universally-correct** generic hooks and formatters first
  (trailing-whitespace, end-of-file-fixer, YAML *syntax* validity) — these are
  low-noise and their diffs are mechanical.
- Introduce **yamllint** with a relaxed ruleset tuned to the existing style
  (notably `line-length` warning-only or generous, and Ansible-friendly
  truthy/comment rules).
- Introduce **ansible-lint** in a **non-blocking / warn** posture initially (or
  scoped to `config/` only), so CI reports but does not fail the build until the
  backlog is burned down. Escalate to blocking in a follow-up once clean.
- **shellcheck**: enable, but expect to need per-file `# shellcheck` directives
  or a `--severity` floor because of the sourced-fragment and mixed-shell reality.
- **stylua / luacheck**: low volume (2 files) — safe to enable, but `init.lua` is
  large and may need a first formatting pass committed separately.

### Proposed tool matrix

| File type | Validator / formatter | Notes |
| --- | --- | --- |
| Generic (all) | pre-commit-hooks: `trailing-whitespace`, `end-of-file-fixer`, `check-merge-conflict`, `check-added-large-files`, `mixed-line-ending`, `check-case-conflict` | Low-noise, mechanical fixes |
| YAML (syntax) | pre-commit-hooks `check-yaml` | Exclude `templates/` (Jinja) |
| YAML (style) | `yamllint` (relaxed config) | Tuned to AGENTS.md style; start lenient on line-length |
| Ansible | `ansible-lint` | **Warn-only / non-blocking initially**; scope to `config/` first |
| Shell | `shellcheck` (via `shellcheck-py` mirror) | Mixed shells; expect directives / severity floor |
| Lua | `stylua` (format) + `luacheck` (lint) | Only 2 files; may need a baseline format commit |
| Vimscript | `vim-vint` | Already installed via `config/roles/python`; **only if any `.vim` files exist** — currently none, so likely omit for now |
| JSON | pre-commit-hooks `check-json` | Note: some JSON has comments (`.vscode`) — may need exclude or `check-json5` |

`vim-vint` is called out in the followup, but a survey found **no `.vim` files**
(Neovim config is `init.lua`). Include vint only if/when vimscript appears;
otherwise note it as available-but-unused rather than adding a dead hook.

## Steps (exact files to add)

All new files; nothing existing is modified except (optionally) `README.md` /
`AGENTS.md` prose noting the new workflow. No Ansible role is required — these
are repo-development tools, not machine config (though a follow-up could add a
`pre-commit` install to a dev role).

1. **`.pre-commit-config.yaml`** — the orchestrator. Skeleton:

   ```yaml
   ---

   exclude: |
     (?x)^(
       .*/templates/.*|          # Jinja, not valid YAML/scripts
       config/files/neovim/lazy-lock.json  # generated (gitignored anyway)
     )$

   repos:
     - repo: https://github.com/pre-commit/pre-commit-hooks
       rev: v5.0.0            # pin; reconcile with chiiiirrus
       hooks:
         - id: trailing-whitespace
         - id: end-of-file-fixer
         - id: check-merge-conflict
         - id: check-added-large-files
         - id: mixed-line-ending
         - id: check-case-conflict
         - id: check-yaml
           exclude: .*/templates/.*
         - id: check-json
           exclude: .*\.vscode/.*   # JSON-with-comments

     - repo: https://github.com/adrienverge/yamllint
       rev: v1.35.1
       hooks:
         - id: yamllint
           args: [-c, .yamllint]

     - repo: https://github.com/ansible/ansible-lint
       rev: v24.12.2
       hooks:
         - id: ansible-lint
           # start scoped/lenient; see .ansible-lint
           files: ^config/.*\.(ya?ml)$

     - repo: https://github.com/shellcheck-py/shellcheck-py
       rev: v0.10.0.1
       hooks:
         - id: shellcheck
           args: [--severity=warning]   # floor; loosen/tighten per findings

     - repo: https://github.com/JohnnyMorganz/StyLua
       rev: v2.0.2
       hooks:
         - id: stylua

     - repo: https://github.com/lunarmodules/luacheck
       rev: v1.2.0
       hooks:
         - id: luacheck
           args: [--no-max-line-length]   # tune
   ```

   (Versions are placeholders — pin to current releases and match chiiiirrus.)

2. **`.yamllint`** — relaxed ruleset aligned to AGENTS.md conventions:

   ```yaml
   ---

   extends: relaxed
   rules:
     line-length:
       max: 100
       level: warning
     document-start:
       present: true          # enforce the leading `---`
     indentation:
       spaces: 2
     truthy:
       allowed-values: ["true", "false"]
       check-keys: false      # avoid flagging Ansible `yes/no` module keys
     comments:
       min-spaces-from-content: 1   # ansible-lint compatibility
   ignore: |
     */templates/
   ```

3. **`.ansible-lint`** — lenient starting posture:

   ```yaml
   ---

   # Start lenient: burn down the backlog before escalating to strict.
   profile: min            # loosest built-in profile; raise over time
   exclude_paths:
     - setup-ubuntu/        # bit-rotted per AGENTS.md; enable later
     - setup-archlinux/
     - "**/templates/"
   # warn_list / skip_list: add specific rule ids as the first run reveals them
   ```

   Decision to make at implementation time: whether ansible-lint **fails** CI or
   is warn-only. Recommend warn-only (or `continue-on-error` in the workflow) for
   the first PR, flip to blocking in a follow-up once the tree is clean.

4. **`.github/workflows/ci.yml`** — CI entrypoint:

   ```yaml
   ---

   name: CI

   "on":
     push:
       branches: [main]
     pull_request:

   permissions:
     contents: read

   jobs:
     pre-commit:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: actions/setup-python@v5
           with:
             python-version: "3.12"
         - uses: pre-commit/action@v3.0.1
           # or: run `pipx run pre-commit run --all-files`
   ```

   Notes:
   - Use `pre-commit/action` or `pre-commit-ci`-style caching for hook envs.
   - Non-Python hooks (stylua binary, shellcheck, luacheck/lua) are provisioned
     by pre-commit's own language runtimes on the runner — verify each installs
     cleanly on `ubuntu-latest`; luacheck needs Lua/LuaRocks on the runner (may
     need an extra setup step or a container).
   - Runners are GitHub-hosted (Linux) only; nothing here provisions the user's
     actual machines, so no secrets and read-only `contents` permission.

5. **Optional prose** — a short "Development / linting" note in `README.md` or
   `AGENTS.md` (`pre-commit install`, `pre-commit run --all-files`). Keep to a
   few lines; AGENTS.md's "no CI here" statement should be updated once this lands.

## Verification

- `pre-commit run --all-files` locally on macOS — capture the finding count per
  hook; this reveals the true noise level and drives the lenient-vs-strict knobs
  above. Expect a large, mostly-mechanical first diff from
  trailing-whitespace/end-of-file-fixer.
- Confirm excludes work: `templates/*.j2`/Jinja files and generated JSON are not
  linted; hand-written YAML is.
- Push a throwaway branch / open a draft PR and confirm the Actions workflow
  triggers, installs all hook toolchains on `ubuntu-latest`, and reports.
- Deliberately introduce a violation (trailing whitespace, bad indent) and
  confirm CI catches it; confirm a clean tree passes.
- Sanity-check that the mechanical auto-fixes (formatters) don't break anything:
  re-run `config/config.sh --check --diff` after the first formatting pass to
  confirm no rendered/symlinked behavior changed.

## Risks / open questions

- **Reconciliation with `chiiiirrus` (primary).** This plan is a best-guess
  standard setup built *without* access to chiiiirrus. Before/at implementation,
  read chiiiirrus's `.pre-commit-config.yaml`, lint configs, and
  `.github/workflows/` and adopt its hook set, tool versions, config style, and
  workflow shape where they differ. Treat the concrete YAML above as a starting
  scaffold, not a spec. (chiiiirrus is also the reference for the bootstrap-script
  followup, so aligning now pays off twice.)
- **Lint noise on the existing codebase.** 141 YAML files + 29 config roles +
  three `setup-*` trees were all written pre-linter. `ansible-lint` at a strict
  profile will likely flag hundreds of issues (naming, FQCN, `command`-vs-module,
  `changed_when`, etc.). Mitigation: start at `profile: min`, scope to `config/`,
  exclude bit-rotted `setup-ubuntu`/`setup-archlinux`, and warn-only in CI first.
  Open question: burn the backlog down in one big cleanup PR vs. ratchet
  rule-by-rule. Recommend: land tooling lenient first (this plan), then a
  separate cleanup effort — which dovetails with the **"Audit the project"**
  followup (CI enforces whatever that audit settles on).
- **Jinja templates masquerading as YAML/scripts.** `templates/*.sh` and
  `templates/*.conf`/`tmux.conf`/`vars.sh` contain `{{...}}` and are not valid
  standalone files; the exclude patterns must be correct or hooks will false-fail.
  Verify the glob catches every `templates/` dir across all role trees.
- **Mixed shell dialects.** shellcheck must handle bash, POSIX sh, and *sourced*
  zsh fragments (`config/files/*/N-*.zsh` / `.sh` are sourced, lack shebangs, and
  reference vars defined elsewhere). Expect `SC1090/SC1091` (can't follow source)
  and unassigned-var noise; may need `--severity`, `# shellcheck source=/dev/null`
  directives, or excluding fragments. zsh-specific syntax is not fully supported
  by shellcheck at all — may need to exclude `.zsh`.
- **Auto-formatting churn on `init.lua`.** stylua reformatting the large
  `init.lua` produces a big diff; commit the baseline format separately from the
  tooling so review stays legible. Same for end-of-file/whitespace across the tree.
- **Runner toolchain availability.** stylua (Rust binary), shellcheck, and
  especially luacheck (needs Lua + LuaRocks) must install cleanly on
  `ubuntu-latest` via pre-commit's language runtimes; luacheck may need an extra
  `leafo/gh-actions-lua` (or apt) step. Verify before declaring CI green.
- **`vim-vint` mismatch.** The followup lists vint, but there are no `.vim`
  files (Neovim config is Lua). Omit unless/until vimscript appears; note it as
  available (installed via `config/roles/python`) rather than wiring a dead hook.
- **JSON with comments.** `.vscode/*.json` (and possibly Karabiner assets) may be
  JSONC; `check-json` will reject comments. Exclude those paths or use a JSON5
  check.
- **First-PR ergonomics.** Auto-fixing hooks modify files during commit; document
  the "stage, commit fails with fixes applied, re-add, re-commit" flow so it isn't
  surprising. Pin all hook `rev`s (reproducibility) and add a periodic
  `pre-commit autoupdate` habit.
