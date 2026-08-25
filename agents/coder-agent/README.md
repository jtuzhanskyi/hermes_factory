# `coder-agent` agent

Self-contained harness for the coder agent (`AGENT_NAME=coder-agent`), which
turns a single GitHub issue into a merge-ready pull request.

## Contents

- `CLAUDE.md` — the agent's system prompt / operating guidance: what it's
  given, what it should do, and the exact JSON output contract the
  entrypoint (`bin/entrypoint.sh` → `lib/run-coder-agent.sh`) expects on
  stdout.
- `skills/<name>/SKILL.md` — one file per skill the agent applies:
  `scope-assessment` (decide in-scope vs. decline), `change-implementation`
  (make the minimal edit), `pr-authoring` (branch/commit/PR).

## Inputs

- `GITHUB_REPOSITORY` — `owner/repo` of the target repository.
- `ISSUE_NUMBER` — the issue to address.

Full contract: `specs/002-coder-agent/contracts/container-input.md`.

## Output

Exactly one JSON object on stdout with a `status` of `pr_opened`,
`declined`, or `no_op`. Full contract:
`specs/002-coder-agent/contracts/agent-output.md`.

## Editing this agent

1. Edit `CLAUDE.md` and/or any `skills/<name>/SKILL.md` file.
2. To add a new skill, create `skills/<new-skill-name>/SKILL.md` and mention
   it in `CLAUDE.md`'s list of skills to apply.
3. Rebuild the image: `docker build -t coder-agent:local -f docker/Dockerfile .`
4. Re-run against the reference issue (see
   `specs/002-coder-agent/quickstart.md`) and confirm the change is
   reflected.

## Isolation

This folder holds no shared state with any other agent. It must never
reference another agent's directory or any path outside itself —
`tests/unit/harness-isolation.bats` enforces this.
