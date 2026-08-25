# Quickstart: Validating the Containerized PR Review Agent

## Prerequisites

- Docker installed locally.
- A GitHub personal access token (or fine-grained token) with read access to the target repo's pull requests and write access to post issue/PR comments.
- An Anthropic API key.
- A real (or disposable test) GitHub PR to point the agent at.

## 1. Build the image

```sh
docker build -t pr-review-agent:local -f docker/Dockerfile .
```

Expected: build succeeds; the image contains `agents/code-review/CLAUDE.md`, `agents/code-review/skills/`, the `claude` CLI, and the `gh` CLI (see `contracts/container-input.md` for how the image is invoked, `data-model.md` for the Agent Harness shape being packaged).

## 2. Run against a PR with no issues (happy path — pass)

```sh
docker run --rm \
  -e GITHUB_REPOSITORY="<owner>/<repo>" \
  -e PR_NUMBER="<pr-number>" \
  -e GITHUB_TOKEN="<token>" \
  -e ANTHROPIC_API_KEY="<key>" \
  pr-review-agent:local
```

Expected:
- Exit code `0`.
- Exactly one new comment appears on the target PR, formatted per `contracts/review-comment-format.md`, with the "No blocking issues found" heading.
- Corresponds to spec Acceptance Scenario 1 & 2 (US1), and SC-001/SC-002.

## 3. Run against a PR with known issues

Point at a PR containing an obvious issue (e.g. a missing test for new logic, or an unhandled error path).

Expected:
- Exit code `0`.
- The posted comment lists each issue with a summary and a location, per `contracts/review-comment-format.md`.
- Corresponds to spec Acceptance Scenario 3 (US1).

## 4. Validate failure surfacing (edge cases)

Run each of the following and confirm: non-zero exit code matching `contracts/exit-codes.md`, a specific stderr message, and **no comment posted**.

| Scenario | How to trigger | Expected exit code |
|---|---|---|
| Missing required input | Omit `PR_NUMBER` | `10` |
| Malformed input | Set `GITHUB_REPOSITORY="not-a-repo"` | `10` |
| PR not accessible | Use a nonexistent PR number, or an unauthorized token | `20` |
| Unknown agent | Set `AGENT_NAME="does-not-exist"` | `10` |

Corresponds to spec Edge Cases and SC-003.

## 5. Validate re-run behavior

Run step 2 twice in a row against the same PR.

Expected: two separate comments appear (each with its own `generated_at`), not one comment edited in place. Corresponds to Edge Cases ("reviewed more than once").

## 6. Validate agent-harness independence (US2)

1. Edit `agents/code-review/skills/<any-skill>/SKILL.md` (or `agents/code-review/CLAUDE.md`) with a small, observable change (e.g. add a rule that changes what gets flagged).
2. Rebuild: `docker build -t pr-review-agent:local -f docker/Dockerfile .`
3. Re-run step 2 or 3.

Expected: the change is reflected in the next run's review output, and no file outside `agents/code-review/` needed to change. Corresponds to Acceptance Scenario 1 (US2) and SC-004.

## 7. Validate multi-agent extensibility by inspection (US3)

Confirm by inspection (no second agent is built in this feature):
- A new agent could be added as `agents/<new-agent-name>/CLAUDE.md` + `agents/<new-agent-name>/skills/` alongside `agents/code-review/`, with no shared files between the two.
- `AGENT_NAME` in `contracts/container-input.md` is the sole selection mechanism, requiring no code change to `agents/code-review/` to add a new one.

Corresponds to Acceptance Scenarios 1 & 2 (US3) and SC-005.
