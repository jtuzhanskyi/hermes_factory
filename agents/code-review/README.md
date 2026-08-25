# `code-review` agent

Self-contained harness for the default PR review agent (`AGENT_NAME=code-review`,
also the default when `AGENT_NAME` is unset).

## Contents

- `CLAUDE.md` — the agent's system prompt / operating guidance: what it's
  given, what it should do, and the exact JSON output contract the
  entrypoint (`bin/entrypoint.sh` → `lib/run-agent.sh`) expects on stdout.
- `skills/<name>/SKILL.md` — one file per review skill the agent applies to
  the diff (currently `correctness-check`, `risk-assessment`,
  `test-coverage-check`).

## Editing this agent

1. Edit `CLAUDE.md` and/or any `skills/<name>/SKILL.md` file.
2. To add a new skill, create `skills/<new-skill-name>/SKILL.md` and mention
   it in `CLAUDE.md`'s list of skills to apply.
3. Rebuild the image: `docker build -t pr-review-agent:local -f docker/Dockerfile .`
4. Re-run against a test PR (see `specs/001-pr-review-agent/quickstart.md`)
   and confirm the change is reflected in the review output.

No file outside `agents/code-review/` needs to change for any of the above.

## Isolation

This folder holds no shared state with any other agent. It must never
reference another agent's directory or any path outside itself —
`tests/unit/harness-isolation.bats` enforces this. A future second agent is
added as its own sibling folder alongside this one, selected via the
`AGENT_NAME` environment variable
(see `specs/001-pr-review-agent/contracts/container-input.md`), without
touching this folder.
