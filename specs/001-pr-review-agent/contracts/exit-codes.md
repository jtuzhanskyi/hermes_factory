# Contract: Exit Codes & Failure Surfacing

Per FR-010, every failure mode must be surfaced clearly to whoever/whatever started the container — never a silent exit, never a misleading success comment.

| Exit Code | Meaning | Comment posted? |
|---|---|---|
| `0` | Review completed; exactly one comment posted (verdict `pass` or `issues_found`) | Yes — the review outcome |
| `10` | Invalid/missing input (env vars) — validated before any external call | No |
| `20` | Unable to access the PR (repo/PR not found, closed/merged and inaccessible, auth/permissions failure) | No |
| `30` | Review process failed (agent crash, timeout, unexpected error) after PR access succeeded | No |
| `40` | Review completed successfully but posting the comment to GitHub failed (e.g. transient API failure, permissions) | No — outcome is written to stderr/stdout instead so it is not lost |

## Rules

1. All non-zero exits write a specific, human-readable reason to stderr — never just a bare non-zero exit with no message.
2. A comment is posted **if and only if** exit code is `0`. There is no code path where a comment is posted alongside a non-zero exit (prevents the "misleading success comment after a failed run" case called out in Edge Cases / SC-003).
3. On exit code `40` (review succeeded, posting failed), the full review outcome is printed to stdout so the caller/operator does not lose the result even though it never reached GitHub.
4. Timeouts (review taking too long, e.g. on a very large diff) surface as exit code `30`, not a silent hang — the entrypoint enforces an upper bound on the agent run.
