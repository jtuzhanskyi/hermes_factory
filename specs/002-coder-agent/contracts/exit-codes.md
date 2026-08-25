# Contract: Exit Codes (Coder Agent)

Scoped to `AGENT_NAME=coder-agent` runs. Deliberately a separate numbering
from
[001-pr-review-agent/contracts/exit-codes.md](../../001-pr-review-agent/contracts/exit-codes.md)
(rationale: research.md §4) — the two agents are selected by, and reported
on, distinct `AGENT_NAME` values, so a given exit code is only ever
interpreted against the contract of the agent that was actually selected.

| Code | Name                     | Meaning                                                                                     | Stderr message includes                        |
|------|--------------------------|-----------------------------------------------------------------------------------------------|-------------------------------------------------|
| `0`  | `EXIT_OK`                | PR opened, targeting `main`, with verified assignee and label                                 | —                                               |
| `10` | `EXIT_INVALID_INPUT`     | Missing/malformed required env var, or unknown `AGENT_NAME`                                   | which variable(s)                               |
| `20` | `EXIT_ISSUE_INACCESSIBLE`| `gh issue view` failed (not found, private/no access, auth failure)                           | repository + issue number                       |
| `21` | `EXIT_CLONE_FAILED`      | Fresh clone of `GITHUB_REPOSITORY`'s `main` failed                                             | repository                                      |
| `30` | `EXIT_AGENT_FAILED`      | `claude -p` crashed, timed out, or produced no parseable Agent Outcome JSON                    | raw agent output (truncated)                    |
| `31` | `EXIT_DECLINED`          | Agent Outcome `status: "declined"` — issue ambiguous or out of MVP scope (not a bug)           | the agent's `reason`                            |
| `32` | `EXIT_NO_OP`             | Agent Outcome `status: "no_op"` — requested content already present, nothing to change         | the agent's `reason`                            |
| `40` | `EXIT_POSTCONDITION_FAILED` | Agent reported `status: "pr_opened"` but the harness's `gh pr view` check found the assignee and/or `agent-coded` label missing | PR number/url + what was missing |

## Notes

- `31` and `32` are deliberately distinct from each other and from `30`:
  a maintainer or calling automation needs to tell "the agent correctly
  refused an out-of-scope ask" and "there was nothing to do" apart from
  "the agent run itself broke," per SC-004 and the no-op edge case.
- `40` exists because SC-002 requires *100%* of opened PRs to carry the
  correct assignee/label — a run that opens a PR without them is not a
  full success even though a PR did get created (research.md §5).
