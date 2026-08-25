# Contract: Container Input (Coder Agent)

Parallel to
[001-pr-review-agent/contracts/container-input.md](../../001-pr-review-agent/contracts/container-input.md),
for the `coder-agent` run mode. Selected via `AGENT_NAME=coder-agent`.

## Required environment variables

| Variable            | Type          | Validation                                                    |
|----------------------|---------------|------------------------------------------------------------------|
| `GITHUB_REPOSITORY`  | string        | must match `^[[:alnum:]._-]+/[[:alnum:]._-]+$` (owner/repo)       |
| `ISSUE_NUMBER`       | string (int)  | must match `^[1-9][0-9]*$`                                        |
| `GITHUB_TOKEN`       | string        | non-empty; must carry write scope (`repo`, i.e. contents + pull-requests) on `GITHUB_REPOSITORY` — read-only tokens will fail at branch-push or PR-create time, surfaced as exit `40` |
| `ANTHROPIC_API_KEY`  | string        | non-empty                                                          |
| `AGENT_NAME`         | string        | must equal `coder-agent` to select this run mode                  |

## Optional environment variables

| Variable              | Default            | Notes                                                         |
|-----------------------|---------------------|-----------------------------------------------------------------|
| `CODER_ASSIGNEE`      | `jtuzhanskyi`       | overrides the PR assignee (FR-008)                              |
| `CODER_LABEL`         | `agent-coded`       | overrides the PR label (FR-009); created on the repo if absent  |
| `RUN_AGENT_TIMEOUT_SECONDS` | `300` (shared with review agent, `lib/run-agent.sh`) | upper bound on the `claude -p` run  |
| `RUN_AGENT_MODEL`     | `claude-haiku-4-5-20251001` (shared default) | override the model used for the agent run |

## Validation failure

Missing/malformed required variables produce a specific stderr message
(naming the missing/malformed variable(s)) and exit code `10` — same
convention as `lib/validate-input.sh`'s `validate_input`, via a new
`validate_coder_input` function.

## Not applicable to this mode

`PR_NUMBER` (the review agent's input) is not read or validated when
`AGENT_NAME=coder-agent`; the two run modes have disjoint required-input
sets and are selected by the same `AGENT_NAME` variable that already
selects which `agents/<name>/` directory is used.
