# PR Review Agent

A Docker image that runs the Claude Code CLI as an automated code-review
agent against a single GitHub pull request. Given a repository, PR number,
and credentials, it reads the PR's diff, applies a dedicated review harness,
and posts exactly one summary comment (pass or issues-found) back to the PR
— or exits with a specific non-zero code and stderr message if anything
fails, without ever posting a misleading comment.

## Build

```sh
docker build -t pr-review-agent:local -f docker/Dockerfile .
```

## Run

```sh
docker run --rm \
  -e GITHUB_REPOSITORY="my-org/my-repo" \
  -e PR_NUMBER="42" \
  -e GITHUB_TOKEN="ghp_..." \
  -e ANTHROPIC_API_KEY="sk-ant-..." \
  pr-review-agent:local
```

The reviewer model defaults to Claude Haiku 4.5 (`lib/run-agent.sh`); override
it by passing `-e RUN_AGENT_MODEL="..."`.

See `specs/001-pr-review-agent/contracts/container-input.md` for the full
input contract, `specs/001-pr-review-agent/contracts/exit-codes.md` for
failure modes, and `specs/001-pr-review-agent/quickstart.md` for a full
manual validation walkthrough.

### Local test run against a real PR

Rebuild the image after any change under `bin/`, `lib/`, `agents/`, or
`docker/` — Docker won't pick up source edits otherwise:

```sh
docker build -t pr-review-agent:local -f docker/Dockerfile .
```

Local credentials live in the repo's `.env` (not committed) as
`GITHUB_TOKEN` and `ANTHROPIC_TOKEN`. Note the container expects
`ANTHROPIC_API_KEY`, not `ANTHROPIC_TOKEN` — map it explicitly when sourcing
`.env`. For the GitHub token, prefer a fresh `gh auth token` over the one in
`.env` if you're already logged in via `gh`:

```sh
set -a; source .env; set +a

docker run --rm \
  -e GITHUB_REPOSITORY="owner/repo" \
  -e PR_NUMBER="4" \
  -e GITHUB_TOKEN="$(gh auth token)" \
  -e ANTHROPIC_API_KEY="${ANTHROPIC_TOKEN}" \
  pr-review-agent:local
```

This posts a real comment to the target PR — only point it at a PR you're
prepared to have commented on.

## Layout

- `agents/code-review/` — the default (and only, for now) agent's system
  prompt (`CLAUDE.md`) and review skills (`skills/`). See
  `agents/code-review/README.md`.
- `bin/entrypoint.sh`, `lib/*.sh` — container entrypoint and its helpers
  (input validation, GitHub access, agent invocation, comment rendering).
- `docker/Dockerfile` — image packaging.
- `tests/` — `bats-core` contract/integration/unit tests
  (`bats tests/ -r`).
- `docs/adding-a-new-agent.md` — how to add a second, differently
  configured agent selectable via `AGENT_NAME`.

## Testing

```sh
bats tests/ -r
shellcheck bin/*.sh lib/*.sh
```
