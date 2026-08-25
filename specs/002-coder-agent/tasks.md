---

description: "Task list template for feature implementation"
---

# Tasks: Coder Agent

**Input**: Design documents from `/specs/002-coder-agent/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (all present)

**Tests**: Included — `quickstart.md` §7 and plan.md's Project Structure explicitly enumerate `bats` contract/integration/unit test files as part of this feature's deliverables.

**Organization**: This feature has a single user story (US1 — MVP, P1). Tasks are grouped by Setup → Foundational → US1 → Polish.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 for all user-story tasks
- Exact file paths included in every task description

## Path Conventions

Single project, repository root — matches the existing `agents/code-review/` harness shape (plan.md "Project Structure").

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add the new agent's static scaffolding and Docker dependency; nothing here is wired into the entrypoint yet.

- [X] T001 [P] Create `agents/coder-agent/CLAUDE.md` — system prompt: read the issue (passed in the task prompt), `cd` into the given absolute workspace path, decide scope via the `scope-assessment` skill, implement via `change-implementation`, open the PR via `pr-authoring`, then emit exactly one Agent Outcome JSON object on stdout per `specs/002-coder-agent/contracts/agent-output.md` (no markdown fences, nothing else on the last line)
- [X] T002 [P] Create `agents/coder-agent/README.md` documenting the agent's purpose, inputs (`GITHUB_REPOSITORY`, `ISSUE_NUMBER`), and output contract, mirroring `agents/code-review/README.md`'s structure
- [X] T003 [P] Create `agents/coder-agent/skills/scope-assessment/SKILL.md` — decision skill for FR-005: decline when the change touches more than a small, bounded number of files, needs new dependencies/build/config wiring or logic/control-flow changes, or is ambiguous about target content; use `kids-routine-app#5` (a `<title>` text change) as the in-scope calibration example (research.md §6)
- [X] T004 [P] Create `agents/coder-agent/skills/change-implementation/SKILL.md` — instructs making the minimal edit satisfying the issue's acceptance criteria using Edit/Write tools with absolute paths under the workspace, and recognizing a no-op (requested content already present) per FR-011
- [X] T005 [P] Create `agents/coder-agent/skills/pr-authoring/SKILL.md` — branch naming (`coder-agent/issue-<issue_number>`, fail loudly if it already exists per data-model.md), commit message referencing the issue (e.g. `Fixes #5: ...`), `gh pr create` targeting `main`, `gh pr edit --add-label agent-coded --add-assignee jtuzhanskyi` (creating the label first if missing), and summary content requirements (FR-008, FR-009, FR-010)
- [X] T006 Add `git` package to `docker/Dockerfile` (new dependency for `coder-agent`; the review agent never needed a local checkout — plan.md Project Structure)

**Checkpoint**: Static agent scaffolding and Dockerfile dependency exist; no orchestration wiring yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared shell library code and entrypoint dispatch that every US1 task and test depends on.

**⚠️ CRITICAL**: No US1 task can be implemented or tested until this phase is complete.

- [X] T007 Add `validate_coder_input()` to `lib/validate-input.sh` — validates `GITHUB_REPOSITORY` (`^[[:alnum:]._-]+/[[:alnum:]._-]+$`), `ISSUE_NUMBER` (`^[1-9][0-9]*$`), non-empty `GITHUB_TOKEN`/`ANTHROPIC_API_KEY`, applies `CODER_ASSIGNEE`/`CODER_LABEL` defaults (`jtuzhanskyi`/`agent-coded`), and on failure prints which variable(s) are missing/malformed and returns non-zero for exit `10` (contracts/container-input.md); leaves the existing `validate_input` function untouched
- [X] T008 [P] Create `lib/coder-github.sh` with `fetch_issue()` (wraps `gh issue view`, returns title/body/url, non-zero on not-found/inaccessible/auth-failure for exit `20`) and `clone_repo_at_main()` (wraps `gh repo clone` into a `mktemp -d` workspace, returns the absolute path and `main`'s tip SHA, non-zero on clone failure for exit `21`) — per data-model.md's Workspace entity and research.md §1
- [X] T009 [P] Add `verify_pr_postconditions()` to `lib/coder-github.sh` — runs `gh pr view <pr_number> --repo <repo> --json assignees,labels` and returns non-zero (naming what's missing) if `jtuzhanskyi`/`CODER_ASSIGNEE` or `agent-coded`/`CODER_LABEL` is absent, for exit `40` (research.md §5, contracts/exit-codes.md)
- [X] T010 Create `lib/run-coder-agent.sh` — invokes `claude -p` with cwd `agents/coder-agent/` and a task prompt naming the cloned workspace's absolute path, enforces `RUN_AGENT_TIMEOUT_SECONDS`/`RUN_AGENT_MODEL` (shared defaults from `lib/run-agent.sh`), and implements `extract_coder_outcome_json()` — scans stdout for the last line parsing as a JSON object matching contracts/agent-output.md's shape, returning non-zero (for exit `30`) if none is found (mirrors `lib/run-agent.sh`'s `extract_outcome_json`)
- [X] T011 Add the `coder-agent` dispatch path in `bin/entrypoint.sh` — when `AGENT_NAME=coder-agent`: call `validate_coder_input`, `fetch_issue`, `clone_repo_at_main`, `run-coder-agent.sh`, then branch on the Agent Outcome `status` (`pr_opened` → `verify_pr_postconditions` → exit `0`/`40`; `declined` → exit `31` with `reason` on stderr; `no_op` → exit `32` with `reason` on stderr; unparseable/crashed/timed out → exit `30`); existing `AGENT_NAME=code-review` path untouched (contracts/exit-codes.md, data-model.md's State flow)

**Checkpoint**: Full coder-agent orchestration path exists end-to-end; US1 can now be exercised and tested.

---

## Phase 3: User Story 1 - Turn a simple issue into a merge-ready PR (Priority: P1) 🎯 MVP

**Goal**: Point the agent at a GitHub issue describing a small, well-defined change; it opens a merge-ready PR from a fresh `main`, correctly assigned/labeled, or cleanly declines/no-ops.

**Independent Test**: Run the container against `jtuzhanskyi/kids-routine-app#5` (quickstart.md §2); confirm exit `0`, a new branch `coder-agent/issue-5` from `main`'s current tip, a PR with the `<title>` change, assignee `jtuzhanskyi`, label `agent-coded`, and a summary referencing issue #5.

### Tests for User Story 1

> Write these tests first; confirm they fail against the pre-T007–T011 codebase (or use `git stash` to verify), then confirm they pass after Foundational + implementation.

- [X] T012 [P] [US1] Unit tests for `validate_coder_input` in `tests/unit/coder-input-validation.bats` — covers missing `ISSUE_NUMBER`, malformed `GITHUB_REPOSITORY`, missing tokens, `CODER_ASSIGNEE`/`CODER_LABEL` defaulting, per contracts/container-input.md
- [X] T013 [P] [US1] Unit tests for `lib/coder-github.sh` in `tests/unit/coder-github.bats` — `fetch_issue` success/not-found/inaccessible, `clone_repo_at_main` success/failure, `verify_pr_postconditions` pass/missing-assignee/missing-label, with `gh`/`git` stubbed on `PATH` (same approach as `tests/test_helper.bash`)
- [X] T014 [P] [US1] Contract tests for the Agent Outcome JSON in `tests/contract/coder-agent-output.bats` — validates required/omitted fields per status (`pr_opened`, `declined`, `no_op`) against contracts/agent-output.md, and that malformed/missing JSON is rejected by `extract_coder_outcome_json`
- [X] T015 [P] [US1] Contract tests for exit-code mapping in `tests/contract/coder-exit-codes.bats` — one case per row of contracts/exit-codes.md (`0,10,20,21,30,31,32,40`)
- [X] T016 [US1] Integration test in `tests/integration/coder-entrypoint-flow.bats` exercising `bin/entrypoint.sh`'s coder path end-to-end with `gh`, `git`, and `claude` stubbed on `PATH` — covers the success path (`pr_opened` → exit `0`), the no-op path (exit `32`), the declined path (exit `31`), and a postcondition-mismatch path (exit `40`)
- [X] T017 [US1] Extend `tests/unit/harness-isolation.bats` to assert `agents/coder-agent/` never references `agents/code-review/` (or vice versa), matching the existing isolation rule for the review agent

### Implementation for User Story 1

- [X] T018 [US1] Run `bats tests/unit/coder-input-validation.bats tests/unit/coder-github.bats tests/contract/coder-agent-output.bats tests/contract/coder-exit-codes.bats tests/integration/coder-entrypoint-flow.bats tests/unit/harness-isolation.bats` and fix any gaps in T001–T011 until all pass (implementation tasks live in Setup/Foundational above; this task closes the loop between those and the tests written in T012–T017)
- [ ] T019 [US1] Rebuild the image (`docker build -t coder-agent:local -f docker/Dockerfile .`) and run the live quickstart walkthrough (quickstart.md §2–§6) against `jtuzhanskyi/kids-routine-app#5` and a manufactured no-op/decline case, confirming exit codes and PR state match SC-001–SC-004

**Checkpoint**: User Story 1 (the entire MVP) is fully functional and independently verified, both via `bats` and a live run.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Final documentation/consistency pass; no new behavior.

- [X] T020 [P] Update `docs/adding-a-new-agent.md` (if present) to note that the "never touch `bin/`/`lib/`/`docker/Dockerfile`" guarantee applies to agents fitting the review contract, with `coder-agent` documented as the deliberate, called-out exception (plan.md Complexity Tracking)
- [X] T021 Re-run the full `bats` suite (`bats tests/`) to confirm the coder-agent additions haven't broken any existing `code-review` agent tests

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup (T001, agent's `CLAUDE.md`, is referenced by T010's task-prompt cwd). BLOCKS all of Phase 3.
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) completion.
- **Polish (Phase 4)**: Depends on Phase 3 completion.

### Within Phase 2 (Foundational)

- T007 has no dependency on T008–T010.
- T008 and T009 both live in `lib/coder-github.sh` — sequential (same file), T009 after T008.
- T010 depends on T001 (CLAUDE.md must exist for the cwd it invokes) and conceptually on T008 (workspace path it's given), though these can be authored in parallel and only need to align by review time.
- T011 depends on T007, T008, T009, T010 (it calls all of them).

### Within Phase 3 (User Story 1)

- Tests (T012–T017) should be written first and can run in parallel with each other ([P], distinct files) once Phase 2 exists to test against.
- T018 depends on T012–T017 (all tests written) and T007–T011 (all implementation present).
- T019 depends on T018 (bats green) and T006 (Dockerfile updated).

### Parallel Opportunities

- T001–T005 (Setup, all distinct files) run in parallel; T006 (Dockerfile) is independent of them too.
- T008/T009 must be sequential (same file); everything else in Phase 2 that's marked differently is otherwise independent enough to draft in parallel, converging at T011.
- T012–T015 run in parallel (distinct test files); T016 and T017 touch shared/adjacent fixtures and are best run after T012–T015 land.

---

## Parallel Example: Setup Phase

```bash
Task: "Create agents/coder-agent/CLAUDE.md"
Task: "Create agents/coder-agent/README.md"
Task: "Create agents/coder-agent/skills/scope-assessment/SKILL.md"
Task: "Create agents/coder-agent/skills/change-implementation/SKILL.md"
Task: "Create agents/coder-agent/skills/pr-authoring/SKILL.md"
```

## Parallel Example: User Story 1 Tests

```bash
Task: "Unit tests for validate_coder_input in tests/unit/coder-input-validation.bats"
Task: "Unit tests for lib/coder-github.sh in tests/unit/coder-github.bats"
Task: "Contract tests for Agent Outcome JSON in tests/contract/coder-agent-output.bats"
Task: "Contract tests for exit-code mapping in tests/contract/coder-exit-codes.bats"
```

---

## Implementation Strategy

### MVP First (and Only) — This Feature Is a Single User Story

1. Complete Phase 1: Setup (agent scaffolding + Dockerfile).
2. Complete Phase 2: Foundational (shell library + entrypoint dispatch) — CRITICAL, blocks everything else.
3. Complete Phase 3: User Story 1 (tests + closing the implementation loop + live quickstart validation).
4. **STOP and VALIDATE**: `bats tests/` green, live run against `kids-routine-app#5` produces a correct PR (quickstart.md §3).
5. Complete Phase 4: Polish.

### Notes

- [P] tasks = different files, no dependencies.
- Commit after each task or logical group.
- This feature has no US2/US3 — the spec defines exactly one (P1) user story; all edge cases (decline, no-op, postcondition failure, bad input) are covered as scenarios/tests within US1 rather than separate stories, since they're all facets of the same "point the agent at an issue" flow.
