# Implementation Plan: Coder Agent

**Branch**: `002-coder-agent` | **Date**: 2026-08-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-coder-agent/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Add a second agent, `coder-agent`, to the existing containerized-agent
harness (alongside `agents/code-review/`), selected the same way via
`AGENT_NAME`. Given a target repository and issue number, the entrypoint
fetches the issue via `gh`, clones the repo fresh (always at `main`'s
current tip — never a stale copy), and runs `claude -p` with a task prompt
naming that workspace's absolute path. The agent itself — guided by a
minimal `CLAUDE.md` + three skills (`scope-assessment`,
`change-implementation`, `pr-authoring`) — decides whether the issue
describes a simple, mechanical change; if so it makes the edit, creates a
branch from `main`, commits, pushes, and opens a PR (assignee
`jtuzhanskyi`, label `agent-coded`, a summary referencing the issue) all
via `gh`/`git`; otherwise it declines or reports a no-op. The entrypoint
turns every failure mode (bad input, inaccessible issue, clone failure,
agent crash, missing PR postconditions) into a distinct, documented exit
code, and declines/no-ops into their own non-error exit codes distinct
from both success and failure.

## Technical Context

**Language/Version**: POSIX shell (entrypoint/orchestration, same as the
review agent) + `CLAUDE.md`/`SKILL.md` (markdown) consumed by the Claude
Code CLI; no new language runtime

**Primary Dependencies**: Claude Code CLI (`@anthropic-ai/claude-code`, via
`claude -p`), GitHub CLI (`gh`), `git` (new — the review agent never needed
a local checkout; `git clone`/branch/commit/push happen inside this
agent's session), Docker

**Storage**: N/A — stateless per-run container; the cloned workspace is a
`mktemp -d` directory that lives and dies with the container run (data-model.md)

**Testing**: `bats-core`, same convention as `tests/` today, with `gh`,
`git`, and `claude` stubbed on `PATH`; manual `quickstart.md` walkthrough
against the reference issue for live-credential end-to-end validation

**Target Platform**: Linux container (Docker), run via `docker run`, same
image as the review agent (`AGENT_NAME=coder-agent` selects this mode)

**Project Type**: Single project — same container image, extended with a
second agent folder and a second orchestration path in the shared
entrypoint

**Performance Goals**: Not throughput-sensitive (one issue per container
run); the run-time bound already enforced for agent execution
(`RUN_AGENT_TIMEOUT_SECONDS`) extends to this agent

**Constraints**: Must never branch from a stale/cached copy of `main`
(FR-003) — satisfied structurally by cloning fresh every run, not by a
staleness check; must never open a no-op PR (FR-011); must never silently
swallow a failure (FR-012); `GITHUB_TOKEN` for this agent needs write scope
(contents + pull-requests), unlike the review agent's read-oriented token

**Scale/Scope**: Single issue per container run; two agents now ship in the
image (`code-review`, `coder-agent`), each self-contained per the existing
isolation rule (`tests/unit/harness-isolation.bats`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the unfilled template (no
ratified principles for this project) — same state noted in
[001-pr-review-agent/plan.md](../001-pr-review-agent/plan.md). There are no
concrete gates to evaluate against, so this check passes trivially with
nothing to justify. If/when the constitution is ratified, this section
should be revisited for this feature.

## Project Structure

### Documentation (this feature)

```text
specs/002-coder-agent/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── container-input.md
│   ├── agent-output.md
│   └── exit-codes.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
agents/
├── code-review/                     # Unchanged — existing agent, untouched
│   └── ...
└── coder-agent/                     # This feature's new agent harness (FR-001..FR-012)
    ├── CLAUDE.md                    # System prompt: read issue, scope-check, implement, branch/commit/PR via gh+git
    ├── README.md
    └── skills/
        ├── scope-assessment/
        │   └── SKILL.md             # Decide: simple/mechanical vs. decline (FR-005)
        ├── change-implementation/
        │   └── SKILL.md             # Make the minimal edit matching the issue's acceptance criteria
        └── pr-authoring/
            └── SKILL.md             # Branch naming, commit message, PR title/body/label/assignee

docker/
└── Dockerfile                       # +`git` package (new dependency for this agent only)

bin/
└── entrypoint.sh                    # +dispatch: AGENT_NAME=coder-agent routes to the coder flow below

lib/
├── validate-input.sh                # +validate_coder_input (new function; existing validate_input untouched)
├── coder-github.sh                  # gh wrappers: fetch_issue, clone_repo_at_main, verify_pr_postconditions
└── run-coder-agent.sh               # Invokes `claude -p` from agents/coder-agent/, passing the workspace path;
                                      # enforces timeout; parses the Agent Outcome JSON (contracts/agent-output.md)

tests/
├── contract/
│   ├── coder-agent-output.bats      # Validates Agent Outcome JSON shape per status (contracts/agent-output.md)
│   └── coder-exit-codes.bats        # Validates exit-code mapping (contracts/exit-codes.md)
├── integration/
│   └── coder-entrypoint-flow.bats   # Exercises bin/entrypoint.sh's coder path end-to-end, gh/git/claude stubbed
└── unit/
    ├── coder-input-validation.bats  # validate_coder_input cases (contracts/container-input.md)
    ├── coder-github.bats            # fetch_issue / clone_repo_at_main / verify_pr_postconditions, gh stubbed
    └── harness-isolation.bats       # extended: agents/coder-agent must not reference agents/code-review or vice versa
```

**Structure Decision**: Same single-project shape as the review agent
(container image + shell orchestration + markdown agent harness), extended
rather than replaced. `agents/coder-agent/` is added as a sibling to
`agents/code-review/` with no changes to the latter, honoring the existing
extensibility contract in `docs/adding-a-new-agent.md`. That doc's promise
of "never requires touching `bin/`, `lib/`, or `docker/Dockerfile`" holds
for agents that fit the *review* contract (PR diff in, comment out); this
agent has a genuinely different input/output contract (issue in; a
branch+PR out, with three possible terminal states instead of two), so it
necessarily adds a second orchestration path to `bin/entrypoint.sh`,
coder-specific functions to `lib/`, and one new OS package (`git`) to
`docker/Dockerfile` — each addition is additive (existing review-agent
functions/files/paths are untouched) and is called out explicitly in
Complexity Tracking below rather than silently stretched to fit the old
contract.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No constitution violations (no ratified gates exist to violate — see
Constitution Check above). The table below instead documents the one
deliberate departure from `docs/adding-a-new-agent.md`'s stated goal
("adding a new agent never requires touching `bin/`, `lib/`, or
`docker/Dockerfile`"), since that goal is otherwise a strong default this
plan does not meet literally:

| Departure | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| New coder-specific code in `bin/entrypoint.sh`, `lib/`, and one new package in `docker/Dockerfile` | The coder agent's input (issue number, not PR number), required credential scope (write, not read), and output (branch+PR across three terminal states, not a single PR comment) do not fit the review agent's existing contract at all — there is no way to express "clone `main`, run the agent, verify PR postconditions" inside `fetch_pr_diff`/`post_pr_comment`/`extract_outcome_json` without changing their meaning for the review agent too | Forcing the coder agent through the unmodified review-agent contract (e.g. treating the issue number as if it were a PR number, or posting a "comment" instead of opening a PR) would produce a harness that technically avoids touching `bin/`/`lib/`/`Dockerfile` but doesn't do what the feature asks for; rejected as satisfying the letter of the extensibility doc while failing the feature's actual requirements (FR-001..FR-012) |

All additions are strictly additive (no existing review-agent file,
function, or Dockerfile line is modified or removed), so the review
agent's own behavior, tests, and isolation guarantee are unaffected.
