# Contract: Container Input

How a caller (person or external automation) invokes the container to review a PR.

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `GITHUB_REPOSITORY` | Yes | `owner/repo` of the PR to review |
| `PR_NUMBER` | Yes | Pull request number, positive integer |
| `GITHUB_TOKEN` | Yes | Token with permission to read the PR's diff and post a comment on it |
| `ANTHROPIC_API_KEY` | Yes | Credential for the Claude Code CLI to run the agent |
| `AGENT_NAME` | No | Selects which `agents/<name>/` harness to run. Default: `code-review` |

## Example invocation

```sh
docker run --rm \
  -e GITHUB_REPOSITORY="my-org/my-repo" \
  -e PR_NUMBER="42" \
  -e GITHUB_TOKEN="ghp_..." \
  -e ANTHROPIC_API_KEY="sk-ant-..." \
  pr-review-agent:latest
```

To select a future, second agent once one exists:

```sh
docker run --rm \
  -e GITHUB_REPOSITORY="my-org/my-repo" \
  -e PR_NUMBER="42" \
  -e GITHUB_TOKEN="ghp_..." \
  -e ANTHROPIC_API_KEY="sk-ant-..." \
  -e AGENT_NAME="some-other-agent" \
  pr-review-agent:latest
```

## Validation behavior

- Missing any required variable → container exits non-zero before any GitHub/Anthropic call is made; stderr names the specific missing variable.
- `GITHUB_REPOSITORY` not matching `owner/repo` shape, or `PR_NUMBER` not a positive integer → container exits non-zero; stderr names the specific malformed field.
- `AGENT_NAME` set but no matching `agents/<name>/` directory exists in the image → container exits non-zero; stderr names the unknown agent and (optionally) lists available agents.

See `exit-codes.md` for the exact exit code contract and `review-comment-format.md` for the output contract on success.
