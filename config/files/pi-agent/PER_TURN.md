# Every turn — non-negotiable

- **Commit as you go.** After each working change, use the `committing-changes`
  skill (lowercase `area: summary`, never push). Do not save it all for the end.
- **Never declare done without the `finish-task` skill.** Before you call
  anything complete, ready, or finished, run its checklist: build/typecheck, run
  the tests you touched — write them, tests are part of the task — update docs,
  and self-review your diff.
- **Hit a bug or test failure?** Load `systematic-debugging` *before*
  proposing a fix. A fix proposed before the failure is understood is a guess.
- Mid design/refactor → `software-design` skill. Multi-step work →
  `writing-code` skill.

"Use a skill" = read its `SKILL.md` and follow it, the moment it applies — not
later.
