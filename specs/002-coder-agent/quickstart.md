# Quickstart: Coder Agent

Validates the MVP end-to-end (User Story 1 / SC-001–SC-004) against the
reference issue named in the spec:
`https://github.com/jtuzhanskyi/kids-routine-app/issues/5`.

## Prerequisites

- Docker.
- A `GITHUB_TOKEN` with write access (`repo` scope: contents +
  pull-requests) on the target repository (`jtuzhanskyi/kids-routine-app`,
  or your own fork for a dry run).
- An `ANTHROPIC_API_KEY`.
- Credentials available locally in `.env` per this repo's existing
  convention (see the review agent's own quickstart) — do not commit them.

## 1. Build the image

```sh
docker build -t coder-agent:local -f docker/Dockerfile .
```

(Same image as the review agent — `AGENT_NAME` selects the run mode at
`docker run` time; no separate Dockerfile.)

## 2. Run against the reference issue

```sh
docker run --rm \
  -e GITHUB_REPOSITORY="jtuzhanskyi/kids-routine-app" \
  -e ISSUE_NUMBER="5" \
  -e GITHUB_TOKEN="$(grep '^GITHUB_TOKEN=' .env | cut -d= -f2-)" \
  -e ANTHROPIC_API_KEY="$(grep '^ANTHROPIC_TOKEN=' .env | cut -d= -f2-)" \
  -e AGENT_NAME="coder-agent" \
  coder-agent:local
```

## 3. Expected outcome (success path — SC-001, SC-002, SC-003)

- Exit code `0`.
- Stdout: the Agent Outcome JSON with `status: "pr_opened"`
  (`contracts/agent-output.md`).
- On GitHub: a new PR against `main` on `jtuzhanskyi/kids-routine-app`,
  from a branch named `coder-agent/issue-5`, containing exactly the
  `<title>` text change issue #5 asked for, assigned to `jtuzhanskyi`,
  labeled `agent-coded`, with a description summarizing the change and
  linking back to issue #5.
- The branch's parent commit is `main`'s current tip at run time (verify
  with `git log --oneline -1 main` on your local clone vs. the PR's base
  commit).

## 4. Validate the "already satisfied" edge case (no-op)

Run the same command again after the PR from step 2 has merged (or after
manually applying the same title change to `main`):

```sh
docker run --rm \
  -e GITHUB_REPOSITORY="jtuzhanskyi/kids-routine-app" \
  -e ISSUE_NUMBER="5" \
  -e GITHUB_TOKEN="..." -e ANTHROPIC_API_KEY="..." -e AGENT_NAME="coder-agent" \
  coder-agent:local
```

Expected: exit code `32`, no new branch or PR created, stderr states the
requested content already matches.

## 5. Validate the out-of-scope/ambiguous case (decline)

Point at any issue in the target repo describing a multi-file, logic-level,
or vague change (e.g. "improve the app's UX"):

```sh
docker run --rm \
  -e GITHUB_REPOSITORY="jtuzhanskyi/kids-routine-app" \
  -e ISSUE_NUMBER="<that issue's number>" \
  -e GITHUB_TOKEN="..." -e ANTHROPIC_API_KEY="..." -e AGENT_NAME="coder-agent" \
  coder-agent:local
```

Expected: exit code `31`, no new branch or PR created, stderr states why
the request is out of scope or ambiguous (SC-004).

## 6. Validate input/failure handling (SC — FR-012)

```sh
# Missing ISSUE_NUMBER
docker run --rm -e GITHUB_REPOSITORY="jtuzhanskyi/kids-routine-app" \
  -e GITHUB_TOKEN="..." -e ANTHROPIC_API_KEY="..." -e AGENT_NAME="coder-agent" \
  coder-agent:local
# Expected: exit code 10, stderr names ISSUE_NUMBER as missing

# Nonexistent issue
docker run --rm -e GITHUB_REPOSITORY="jtuzhanskyi/kids-routine-app" \
  -e ISSUE_NUMBER="999999" \
  -e GITHUB_TOKEN="..." -e ANTHROPIC_API_KEY="..." -e AGENT_NAME="coder-agent" \
  coder-agent:local
# Expected: exit code 20
```

## 7. Automated checks (run before/instead of live docker runs in CI)

```sh
bats tests/unit/coder-input-validation.bats
bats tests/contract/coder-agent-output.bats
bats tests/contract/coder-exit-codes.bats
bats tests/integration/coder-entrypoint-flow.bats
bats tests/unit/harness-isolation.bats   # extended to cover agents/coder-agent
```

These stub `gh`, `git`, and `claude` on `PATH` (same approach as the review
agent's `tests/`), so they run offline without real credentials.
