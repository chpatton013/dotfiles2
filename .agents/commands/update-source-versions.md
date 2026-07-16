---
description: Check for newer releases of the source-built tools and bump the pins, auto-applying only where the metadata declares automated validation.
---

Audit and (where safe) bump the source-build version pins in
`config/roles/*/defaults/main.yml`, driven entirely by the `# release-metadata:`
comment blocks — do **not** hard-code per-tool knowledge; read everything from
the metadata at run time.

## 1. Discover the pins

Grep `config/roles/*/defaults/main.yml` for `# release-metadata:`. Each block is
a comment immediately above a version-pin variable and provides:

- `upstream:` — where to find the latest release (URL + how tags/releases look).
- `line:` — which release line to track / the pinning policy.
- `validation:` — starts with **`automated`** or **`interactive`**, then how to
  validate a bump. This field alone decides whether a bump may be applied
  autonomously (gate purely on validation availability — not on how big the
  version jump is).

Read the current pinned value from the variable directly below the block (it may
be `<tool>_release_version`, a fork SHA, etc.).

## 2. Check upstream

For each pin, look up the latest release on the tracked `line:` from the
`upstream:` source (GitHub releases/tags API, the project's releases page, …).
Choose the newest release consistent with the `line:` policy (e.g. "latest
stable, patch-level" → newest non-prerelease on the current line). Skip pins the
metadata marks as not a routine upstream release (e.g. a deliberate fork SHA).

## 3. Decide per pin — gate purely on validation availability

- **`validation: automated …`** — bump the pin in the defaults file (the URL/dir
  interpolate from it), apply the role (`config/config.sh --tags <role>`), and
  run the validation the metadata describes (e.g. `tmux -V`, `zsh --version` +
  `zmodload zsh/pcre`). If it builds and validates, keep the bump and commit it
  (`<role>: bump to <version>`, with the standard `Co-Authored-By` trailer). If
  it fails, revert the pin and report. Applies whether the jump is a patch or a
  major — the gate is the *existence* of an automated check.

- **`validation: interactive …`** — do **not** bump autonomously. Report that a
  newer release exists (current vs latest) and the exact interactive validation
  the metadata calls for, so the user can bump + verify with you. This is the
  human-in-the-loop case (Darwin-gated builds not verifiable on the dev machine,
  nvim config smoke tests, deliberate fork pins, …).

## 4. Report

Summarize per tool: current pin, latest available, and the action taken —
bumped + validated + committed, no update available, or flagged for interactive
review (with the steps). Never override git identity on the CLI (see
`AGENTS.md`); follow the repo's commit conventions.
