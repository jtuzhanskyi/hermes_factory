# Data Model: Coder Agent

This feature is a stateless, single-run container process (no database, no
persistence between runs). "Entities" below are the shapes of data that
flow through one run, mirroring the style of
[001-pr-review-agent/data-model.md](../001-pr-review-agent/data-model.md).

## Issue Reference (run input)

The run's input target, supplied via environment variables
(`contracts/container-input.md`).

| Field               | Type   | Notes                                                        |
|---------------------|--------|---------------------------------------------------------------|
| `repository`        | string | `owner/repo`, distinct from this harness repo                |
| `issue_number`      | int    | positive integer                                              |
| `title`             | string | fetched via `gh issue view`, not supplied directly            |
| `body`              | string | fetched via `gh issue view`; drives what change is implemented|
| `url`               | string | fetched via `gh issue view`; used for the PR description link |

Validation: `repository` must match `owner/repo`; `issue_number` must be a
positive integer (same shape as the review agent's `PR_NUMBER` validation
in `lib/validate-input.sh`). Fetch failure (issue not found, private repo
without access, auth failure) is a hard failure (exit `20`,
`contracts/exit-codes.md`).

## Workspace (ephemeral, run-scoped)

A fresh local clone of `repository`, created fresh for this run only.

| Field       | Type   | Notes                                                              |
|-------------|--------|---------------------------------------------------------------------|
| `path`      | string | absolute path under a `mktemp -d` directory                        |
| `base_sha`  | string | the commit `main` pointed to at clone time (for traceability/logs) |

Lifecycle: created before the agent runs, discarded when the container
exits (no cleanup step needed beyond container teardown — nothing outside
the container references this path). Never reused across runs — this is
what guarantees FR-003/SC-003 (always branch from the current tip of
`main`).

## Branch

Created by the agent (not the harness) inside the Workspace.

| Field    | Type   | Notes                                                                 |
|----------|--------|------------------------------------------------------------------------|
| `name`   | string | `coder-agent/issue-<issue_number>`; agent MUST fail loudly (not silently rename/retry) if this already exists |
| `base`   | string | always `main`, at `base_sha`                                          |

## Change

The concrete edit the agent makes, scoped by the `scope-assessment` skill.

| Field         | Type          | Notes                                                                |
|---------------|---------------|------------------------------------------------------------------------|
| `files`       | array<string> | paths touched, relative to the Workspace root                         |
| `commit_sha`  | string        | set once committed                                                    |
| `commit_message` | string     | references the source issue (e.g. `Fixes #5: ...`)                    |

A Change with zero files (the requested content already matches what
exists) is a **no-op**: FR-011 forbids opening a PR for it.

## Pull Request (run output, success path)

Created by the agent via `gh pr create` + `gh pr edit`, targeting `main`.

| Field        | Type          | Notes                                                             |
|--------------|---------------|----------------------------------------------------------------------|
| `number`     | int           | assigned by GitHub on creation                                       |
| `url`        | string        | returned by `gh pr create`                                           |
| `assignees`  | array<string> | MUST include `jtuzhanskyi` (FR-008); harness verifies post-hoc (research.md §5) |
| `labels`     | array<string> | MUST include `agent-coded` (FR-009), created on the repo if missing  |
| `summary`    | string        | human-readable, references the source Issue (FR-010)                 |

## Agent Outcome (structured stdout contract)

The single JSON object the agent emits at the end of its run — the
authoritative record of what happened this run. Full shape in
[contracts/agent-output.md](./contracts/agent-output.md).

| `status`      | Meaning                                                              | Populated fields                          |
|---------------|------------------------------------------------------------------------|--------------------------------------------|
| `pr_opened`   | Success path: PR created, assignee/label applied                       | `branch`, `pr_number`, `pr_url`, `summary` |
| `declined`    | Issue is ambiguous or outside MVP scope (FR-005); no PR opened          | `reason`                                   |
| `no_op`       | Requested content already matches; no change made, no PR opened        | `reason`                                   |

A run that crashes, times out, or emits anything else on stdout is *not*
one of these three states — it is a hard failure (exit `30`), same pattern
as the review agent's `extract_outcome_json` (`lib/run-agent.sh`).

## State flow (single run)

```text
Issue Reference (validated)
        │
        ▼
  gh issue view  ──(not found/inaccessible)──▶ exit 20
        │
        ▼
Workspace (fresh clone of main) ──(clone fails)──▶ exit 21
        │
        ▼
  claude -p (agent run) ──(crash/timeout/bad JSON)──▶ exit 30
        │
        ├─ status: declined ───────────────────────▶ exit 31 (reason on stderr)
        ├─ status: no_op ──────────────────────────▶ exit 32 (reason on stderr)
        └─ status: pr_opened
                │
                ▼
        gh pr view (assignee/label check) ──(mismatch)──▶ exit 40
                │
                ▼
              exit 0
```
