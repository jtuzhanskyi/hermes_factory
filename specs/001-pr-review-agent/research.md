# Research: Containerized PR Review Agent

## 1. Agent runtime

**Decision**: Use the Claude Code CLI (`@anthropic-ai/claude-code`) in non-interactive/print mode (`claude -p`) as the agent execution engine inside the container, rather than hand-rolling an agent loop against the raw Messages API.

**Rationale**: The feature explicitly asks to package "a system prompt, a few skills" as a harness and have "a claude agent" run it — this is exactly what Claude Code's project-scoped `CLAUDE.md` + `.claude/skills/` convention provides out of the box, including tool use (reading diffs, running `gh`), skill invocation, and structured turn-taking. Reusing it avoids re-implementing an agent loop, tool-calling, and skill-loading machinery that already exists and is well-tested. It also keeps a straight line to Requirement FR-011/FR-012 (multiple agents, selectable at run time): each agent is just a different working directory passed to the same `claude` binary.

**Alternatives considered**:
- Claude Agent SDK (Python/TypeScript) with a custom loop — more flexible, but duplicates skill-loading/system-prompt conventions this repo already uses for its own Speckit skills, and needs more code to reach the same behavior.
- Raw Anthropic Messages API with manual tool dispatch — most control, most code, slowest to build safely for a first iteration; rejected as premature for a single-agent MVP.

## 2. GitHub access (read PR, post comment)

**Decision**: Use the official GitHub CLI (`gh`), authenticated via `GH_TOKEN`/`GITHUB_TOKEN` supplied as a container environment variable, for both reading PR data (`gh pr diff`, `gh pr view`) and posting the review outcome (`gh pr comment`).

**Rationale**: `gh` is a single static-ish binary, well-documented, handles auth/rate-limit/pagination details, and is easy to make available to the agent as a tool it can invoke directly (matches "the agent... examines the PR's changes" — the agent itself calls `gh`, rather than a wrapper pre-fetching everything). Using the same tool for reading and commenting keeps the credential surface to one token with well-understood scopes (`repo` / `pull_request` write).

**Alternatives considered**:
- Direct GitHub REST/GraphQL calls via `curl` — more brittle (pagination, diff formatting, auth headers hand-rolled); no material benefit over `gh` for this scope.
- `octokit`/PyGithub SDK inside a custom wrapper script — adds a language runtime and dependency surface purely to do what `gh` already does; rejected to keep the image small and the harness language-agnostic.

## 3. Orchestration / entrypoint language

**Decision**: A small POSIX shell entrypoint (`bin/entrypoint.sh` + helper scripts under `lib/`) that: validates required inputs, exports GitHub/Anthropic credentials, invokes `claude -p` with the selected agent's directory as the working directory and a task prompt containing the PR reference, captures the result, and surfaces failures with non-zero exit codes and messages on stderr.

**Rationale**: The entrypoint's job is thin process orchestration (validate env → run one command → check exit status), which shell handles natively without adding a runtime/dependency (Python/Node) to the image just for glue code. It also matches how container entrypoints conventionally look, keeping the image minimal (FR-006: everything ships in the image).

**Alternatives considered**:
- Python entrypoint — nicer error handling and testability via pytest, but adds a runtime dependency and packaging step for what is ~100 lines of sequential logic; rejected for this scope but not precluded for a future agent.
- Making `claude` itself the container `ENTRYPOINT` with no wrapper — would push input validation and comment-posting logic into the agent's own prompt/skills, which is harder to test deterministically and makes failure surfacing (FR-010) less reliable than a scripted check of the CLI's exit code.

## 4. Testing approach for shell-based orchestration

**Decision**: Use `bats-core` for entrypoint/integration tests, with `gh` and `claude` stubbed out as fake executables on `PATH` so tests run without real GitHub/Anthropic credentials or network access.

**Rationale**: `bats-core` is the standard for testing bash scripts, integrates with CI easily, and stubbing the two external binaries lets tests exercise input validation, failure surfacing, and comment-formatting logic deterministically and offline.

**Alternatives considered**:
- No automated tests, manual `quickstart.md` validation only — insufficient given FR-010's "must not fail silently" requirement needs to be verifiable in CI, not just by hand.
- Full Docker-based integration tests hitting a real GitHub sandbox repo — valuable but heavier (needs live credentials, a disposable PR); kept as the manual `quickstart.md` validation path rather than a required automated test, since it can't run hermetically in CI without secrets.

## 5. Idempotency / re-run identification (edge case: same PR reviewed twice)

**Decision**: Each posted comment includes a hidden HTML-comment marker (`<!-- pr-review-agent:code-review -->`) plus a human-visible run timestamp, but the agent always posts a **new** comment rather than editing a previous one, per the spec's stated assumption.

**Rationale**: Matches FR-009/edge-case guidance directly ("post a new comment each time rather than editing a prior one") while still making automated tooling able to recognize/filter the agent's own comments later if needed (forward-compatible with a future "update in place" enhancement without requiring it now).

**Alternatives considered**: Editing/replacing the previous comment — explicitly out of scope per the spec's assumptions; rejected.

## 6. Multi-agent extensibility (FR-011/FR-012)

**Decision**: Each agent lives under `agents/<agent-name>/` with its own `CLAUDE.md` and `skills/` subfolder, self-contained and with no cross-agent shared state. The container's entrypoint accepts an `AGENT_NAME` environment variable (default `code-review`, the only agent shipped now) that selects which `agents/<agent-name>/` directory becomes the Claude Code working directory for that run.

**Rationale**: Directly satisfies FR-004 (dedicated, clearly-named location), FR-011 (new agents addable without touching existing ones), and FR-012 (selectable per run). Since Claude Code already scopes `CLAUDE.md`/skills to the working directory, "select an agent" reduces to "cd into its folder," which needs no additional selection framework.

**Alternatives considered**: A single shared `CLAUDE.md`/skills folder with agent-specific sections — rejected, violates FR-004's "dedicated, clearly-named location... separate from any future agent's configuration" and would make future agents modify a shared file (violates SC-005).
