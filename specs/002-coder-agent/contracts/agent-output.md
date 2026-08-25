# Contract: Agent Output (Coder Agent)

The coder agent's final stdout MUST be exactly one JSON object, with no
markdown fences and no other text before or after it — same rule as the
review agent's outcome contract
([001-pr-review-agent/contracts/review-comment-format.md](../../001-pr-review-agent/contracts/review-comment-format.md)),
enforced the same way: the entrypoint scans stdout for the last line that
parses as a JSON object matching this shape (`extract_coder_outcome_json`,
mirroring `lib/run-agent.sh`'s `extract_outcome_json`).

## Shape

```json
{
  "status": "pr_opened" | "declined" | "no_op",
  "reason": "string, required when status is declined or no_op",
  "branch": "string, required when status is pr_opened",
  "pr_number": 0,
  "pr_url": "string, required when status is pr_opened",
  "summary": "string, required when status is pr_opened; references the source issue"
}
```

## Rules by status

- `pr_opened`: `branch`, `pr_number`, `pr_url`, and `summary` are all
  required and non-empty. `reason` MUST be omitted. The agent must have
  already: created the branch from `main`'s tip, committed the change,
  pushed it, opened the PR against `main`, applied the `agent-coded` label
  (creating it on the repo first if it did not exist), and set
  `jtuzhanskyi` (or `CODER_ASSIGNEE`) as assignee — all via `gh`, before
  emitting this outcome.
- `declined`: `reason` is required and must explain, specifically, why the
  issue is ambiguous or out of the MVP's scope (FR-005). `branch`,
  `pr_number`, `pr_url`, `summary` MUST be omitted — no branch, commit, or
  PR may have been created.
- `no_op`: `reason` is required and must state that the requested content
  already matches the current source. `branch`, `pr_number`, `pr_url`,
  `summary` MUST be omitted — no branch, commit, or PR may have been
  created.

## Entrypoint-side handling

| Condition                                                             | Exit code | See `exit-codes.md` |
|-------------------------------------------------------------------------|-----------|----------------------|
| stdout has no parseable outcome JSON, or `claude -p` crashed/timed out   | `30`      | agent run failed      |
| `status: "declined"`                                                    | `31`      | declined              |
| `status: "no_op"`                                                       | `32`      | no-op                 |
| `status: "pr_opened"` but `gh pr view` shows a missing assignee/label    | `40`      | postcondition failed  |
| `status: "pr_opened"` and assignee/label verified                       | `0`       | success               |

## Example — success

```json
{"status": "pr_opened", "branch": "coder-agent/issue-5", "pr_number": 42, "pr_url": "https://github.com/jtuzhanskyi/kids-routine-app/pull/42", "summary": "Updates the <title> text to match issue #5's requested wording."}
```

## Example — declined

```json
{"status": "declined", "reason": "Issue #7 asks to 'improve the routine builder UX' without specifying concrete wording/markup — this is ambiguous and beyond a mechanical text/content edit."}
```

## Example — no-op

```json
{"status": "no_op", "reason": "The <title> element already reads the exact text requested in issue #5; no change needed."}
```
