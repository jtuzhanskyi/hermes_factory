# Implementation Plan: Containerized PR Review Agent

**Branch**: `001-pr-review-agent` | **Date**: 2026-08-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-pr-review-agent/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Ship a Docker image that runs the Claude Code CLI as a "code-review" agent against a single specified GitHub pull request: the agent reads the PR diff via `gh`, forms a pass/issues-found verdict using a dedicated, image-baked harness (`CLAUDE.md` + a small set of review skills under `agents/code-review/`), and posts exactly one summary comment back to the PR. A thin shell entrypoint validates run-time input (repo, PR number, credentials), invokes the agent, and turns any failure (bad input, inaccessible PR, agent crash, failed comment post) into a distinct non-zero exit code with a clear stderr message — never a silent failure or a misleading success comment. The `agents/<name>/` layout is designed so a second, differently-configured agent can be added later purely by adding a new sibling folder, with no changes to `agents/code-review/`.

## Technical Context

**Language/Version**: POSIX shell (entrypoint/orchestration) + whatever CLAUDE.md/SKILL.md (markdown) the Claude Code CLI consumes; no application-level language runtime beyond what `claude` and `gh` require (Node.js, bundled in the `claude` CLI's own image layer)

**Primary Dependencies**: Claude Code CLI (`@anthropic-ai/claude-code`, run via `claude -p`), GitHub CLI (`gh`), Docker

**Storage**: N/A — stateless per-run container, no persistence between runs

**Testing**: `bats-core` for entrypoint/integration tests (with `gh` and `claude` stubbed on `PATH`); manual `quickstart.md` walkthrough for live-credential end-to-end validation

**Target Platform**: Linux container (Docker), run via `docker run` by a person or external automation

**Project Type**: Single project — container image + orchestration scripts + agent harness content (no frontend/backend split, no mobile component)

**Performance Goals**: Not throughput-sensitive (one PR review per container run); the only latency expectation is that a run completes without requiring manual intervention (SC-001)

**Constraints**: Entrypoint must enforce an upper time bound on the agent run so an oversized/pathological diff surfaces as a timeout failure (exit code `30`, see `contracts/exit-codes.md`) rather than hanging indefinitely; no credentials may be embedded in the image (spec Assumptions)

**Scale/Scope**: Single PR per container run; one agent shipped in this iteration (`code-review`), with the layout validated (not executed) for future additional agents (US3)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the unfilled template (no ratified principles for this project). There are no concrete gates to evaluate against, so this check passes trivially with nothing to justify. If/when the constitution is ratified, this section should be revisited for this feature.

## Project Structure

### Documentation (this feature)

```text
specs/001-pr-review-agent/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── container-input.md
│   ├── exit-codes.md
│   └── review-comment-format.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
agents/
└── code-review/                     # This feature's only agent harness (FR-004, FR-005)
    ├── CLAUDE.md                    # System prompt / operating guidance for the code-review agent
    └── skills/
        ├── correctness-check/
        │   └── SKILL.md
        ├── risk-assessment/
        │   └── SKILL.md
        └── test-coverage-check/
            └── SKILL.md
    # A future agent (US3) would be added as a sibling: agents/<new-agent>/CLAUDE.md + skills/,
    # with no changes required here.

docker/
└── Dockerfile                       # Installs claude + gh, copies agents/ and bin/lib/ into the image

bin/
└── entrypoint.sh                    # Container ENTRYPOINT: validate input → run agent → post comment → exit code

lib/
├── validate-input.sh                # Review Target validation (contracts/container-input.md)
├── github.sh                        # gh wrapper: fetch PR diff/metadata, post comment
├── run-agent.sh                     # Invokes `claude -p` against agents/<AGENT_NAME>/, enforces timeout
└── comment-format.sh                # Renders Review Outcome -> comment markdown (contracts/review-comment-format.md)

tests/
├── contract/
│   └── review-comment-format.bats   # Validates rendered comment matches contracts/review-comment-format.md
├── integration/
│   └── entrypoint-flow.bats         # Exercises bin/entrypoint.sh end-to-end with gh/claude stubbed
└── unit/
    ├── validate-input.bats
    └── github.bats
```

**Structure Decision**: Single project. The "application" is a container image plus the shell orchestration and markdown harness content that ship inside it — there is no frontend/backend split and no library/CLI/web distinction beyond what's shown above. `agents/` is kept as a top-level directory (not nested under `src/`) because it is user/maintainer-facing content (FR-004: "dedicated, clearly-named location"), not application source code, and because future agents (US3) must be addable as siblings without touching `docker/`, `bin/`, or `lib/`. `bin/` and `lib/` hold the reusable orchestration; `docker/` holds image packaging; `tests/` mirrors the existing `contract/integration/unit` convention from the plan template, adapted to shell/bats.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations — table intentionally omitted (constitution has no ratified gates to violate; see Constitution Check above).
