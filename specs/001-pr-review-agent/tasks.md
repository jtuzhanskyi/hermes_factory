---

description: "Task list template for feature implementation"
---

# Tasks: Containerized PR Review Agent

**Input**: Design documents from `/specs/001-pr-review-agent/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included — `plan.md`/`research.md` (Decision 4) call for `bats-core` contract/integration/unit tests as part of the architecture.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Single project layout per `plan.md`: `agents/`, `docker/`, `bin/`, `lib/`, `tests/` at repository root.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Create the repository directory skeleton: `agents/code-review/skills/`, `docker/`, `bin/`, `lib/`, `tests/contract/`, `tests/integration/`, `tests/unit/`, `tests/fixtures/` (empty dirs with `.gitkeep` where needed)
- [X] T002 [P] Vendor/install `bats-core` for the test suite and add `tests/test_helper.bash` with shared setup (temp `PATH` for stubbed `gh`/`claude`, teardown)
- [X] T003 [P] Add `.dockerignore` at repository root excluding `tests/`, `specs/`, local dev artifacts from the image build context
- [X] T004 [P] Add shell lint config: `.shellcheckrc` at repository root

**Checkpoint**: Directory layout and tooling exist; no functional code yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 Create `bin/entrypoint.sh` skeleton: shebang, `set -euo pipefail`, sourcing of `lib/*.sh`, exit code constants matching `contracts/exit-codes.md` (0/10/20/30/40)
- [X] T006 [P] Implement `lib/validate-input.sh`: validates the Review Target (`GITHUB_REPOSITORY`, `PR_NUMBER`, `GITHUB_TOKEN`, `ANTHROPIC_API_KEY`, optional `AGENT_NAME`) per `data-model.md` and `contracts/container-input.md`; on failure, prints a specific stderr message naming the missing/malformed field and returns exit code `10`
- [X] T007 [P] Implement `lib/github.sh`: `gh`-backed functions to fetch PR diff/metadata (`fetch_pr_diff`) and to post a comment (`post_pr_comment`), returning distinguishable failure signals for "PR not accessible" (exit `20`) vs. "comment post failed" (exit `40`)
- [X] T008 [P] Implement `lib/comment-format.sh`: renders a Review Outcome (verdict, findings, `run_marker`, `generated_at`) into the markdown structure defined in `contracts/review-comment-format.md`
- [X] T009 Implement `AGENT_NAME` resolution in `bin/entrypoint.sh`: defaults to `code-review`, resolves to `agents/<AGENT_NAME>/`, and exits `10` with a message naming the unknown agent if the directory doesn't exist (FR-012, `contracts/container-input.md`) — depends on T005, T006
- [X] T010 [P] Write `docker/Dockerfile`: base image with Node.js, install `@anthropic-ai/claude-code` and the GitHub CLI (`gh`), copy `agents/`, `bin/`, `lib/` into the image, set `ENTRYPOINT ["bin/entrypoint.sh"]`

**Checkpoint**: Foundation ready — input validation, GitHub access, comment rendering, and agent selection are all in place; user story implementation can now begin.

---

## Phase 3: User Story 1 - Run an automated code review on a PR (Priority: P1) 🎯 MVP

**Goal**: Starting the container against a real PR produces exactly one review comment (pass or issues-found) on that PR, with failures surfaced clearly instead of silently.

**Independent Test**: Start the container against a real/test PR reference with valid credentials and confirm a review comment appears; confirm failure scenarios (bad PR, crash, comment-post failure) each exit non-zero with no comment posted.

### Tests for User Story 1 ⚠️

> Write these tests FIRST, ensure they FAIL before implementation

- [X] T011 [P] [US1] Contract test `tests/contract/review-comment-format.bats`: given sample Review Outcomes (pass; issues-found with 1+ findings), assert `lib/comment-format.sh` output matches `contracts/review-comment-format.md` exactly (marker line first, heading text, findings list with summary + location)
- [X] T012 [P] [US1] Contract test `tests/contract/exit-codes.bats`: stub `gh`/`claude` to force each failure mode and assert `bin/entrypoint.sh` exits with the codes in `contracts/exit-codes.md` (10, 20, 30, 40) and prints a specific stderr message for each
- [X] T013 [P] [US1] Integration test `tests/integration/entrypoint-flow.bats` (happy path, pass verdict): stub `gh` and `claude` on `PATH`, run `bin/entrypoint.sh` with valid env vars, assert exit code `0` and exactly one `gh pr comment` invocation with a "No blocking issues found" body
- [X] T014 [P] [US1] Integration test `tests/integration/entrypoint-flow.bats` (issues-found verdict): stub `claude` to emit findings, assert the posted comment lists each finding's summary and location per the contract
- [X] T015 [P] [US1] Integration test `tests/integration/entrypoint-flow.bats` (re-run behavior): run the happy path twice against the same stubbed PR, assert two separate `gh pr comment` invocations (no edit-in-place)

### Implementation for User Story 1

- [X] T016 [US1] Implement `lib/run-agent.sh`: invokes `claude -p` with `agents/<AGENT_NAME>/` as working directory and a task prompt containing the PR diff/metadata, enforces a run timeout (exit `30` on timeout or crash), and emits a structured Review Outcome (verdict + findings) — depends on T009
- [X] T017 [US1] Wire `bin/entrypoint.sh` end-to-end: `lib/validate-input.sh` → `lib/github.sh#fetch_pr_diff` → `lib/run-agent.sh` → `lib/comment-format.sh` → `lib/github.sh#post_pr_comment` → correct exit code per outcome, including the "print outcome to stdout on comment-post failure" rule from `contracts/exit-codes.md` — depends on T016, T007, T008
- [X] T018 [P] [US1] Author `agents/code-review/CLAUDE.md`: system prompt/operating guidance instructing the agent to use `gh` to read the PR diff, apply its skills, and produce a verdict (`pass`/`issues_found`) with findings (summary + location) per FR-005/FR-008
- [X] T019 [P] [US1] Author `agents/code-review/skills/correctness-check/SKILL.md`: guidance for identifying correctness issues in a diff
- [X] T020 [P] [US1] Author `agents/code-review/skills/risk-assessment/SKILL.md`: guidance for flagging risky changes (e.g. large diffs, security-sensitive paths, missing error handling)
- [X] T021 [P] [US1] Author `agents/code-review/skills/test-coverage-check/SKILL.md`: guidance for checking whether new/changed logic has corresponding tests
- [X] T022 [US1] Finalize `docker/Dockerfile` build (`docker build -t pr-review-agent:local -f docker/Dockerfile .`) and fix any packaging issues surfaced by the build — depends on T010, T017, T018-T021
- [X] T023 [US1] Execute `quickstart.md` steps 1–5 (build, pass-path run, issues-found run, failure-surfacing matrix, re-run behavior) against a real or disposable test PR and confirm expected outcomes

**Checkpoint**: User Story 1 is fully functional and independently testable — this is the MVP.

---

## Phase 4: User Story 2 - Maintain the code-review agent's instructions and skills independently (Priority: P2)

**Goal**: A maintainer can edit `agents/code-review/`'s guidance or skills, rebuild, and see the change reflected — without touching anything outside that folder.

**Independent Test**: Edit a skill or `CLAUDE.md`, rebuild the image, confirm the change is reflected in the next review run, and confirm no other file needed to change.

### Tests for User Story 2 ⚠️

- [X] T024 [US2] Unit test `tests/unit/harness-isolation.bats`: grep `agents/code-review/` for any reference to paths outside itself (e.g. `../`, absolute paths into `agents/<other>/`) and assert none exist, enforcing FR-004's "dedicated, clearly-named location... separate from any future agent's configuration"

### Implementation for User Story 2

- [X] T025 [P] [US2] Author `agents/code-review/README.md`: documents the folder's purpose, how to add/edit a skill, and confirms the folder is self-contained (no shared state with other agents)
- [X] T026 [US2] Execute `quickstart.md` step 6: make an observable edit to a skill or `CLAUDE.md`, rebuild the image, re-run against a test PR, and confirm the change is reflected with no edits outside `agents/code-review/` — depends on T022 (US1's built image), T025

**Checkpoint**: User Stories 1 AND 2 both work independently — the harness is verified editable in isolation.

---

## Phase 5: User Story 3 - Add a new, differently-configured agent later (Priority: P3)

**Goal**: The repository layout and `AGENT_NAME` selection mechanism can support a second agent added later, validated architecturally without building a second real agent.

**Independent Test**: Inspect the repository layout and confirm a new agent's folder could be added side-by-side with `agents/code-review/`, each independently selectable via `AGENT_NAME`, with no shared state forcing a collision.

### Tests for User Story 3 ⚠️

- [X] T027 [US3] Create a minimal fixture agent at `tests/fixtures/agents/sample-agent/CLAUDE.md` (used only by tests, never shipped in the image) and add `tests/unit/agent-selection.bats` asserting `bin/entrypoint.sh`'s `AGENT_NAME` resolution logic (T009) correctly selects a fixture agent directory when pointed at it via a test-only `AGENTS_ROOT` override, and exits `10` with a clear message for an unknown `AGENT_NAME` — depends on T009

### Implementation for User Story 3

- [X] T028 [P] [US3] Author `docs/adding-a-new-agent.md`: step-by-step guide for adding `agents/<new-agent-name>/CLAUDE.md` + `skills/` and selecting it via `AGENT_NAME`, referencing `contracts/container-input.md`
- [X] T029 [US3] Execute `quickstart.md` step 7: inspect the repository layout against the checklist (new agent addable as a sibling folder, `AGENT_NAME` is the sole selection mechanism, `agents/code-review/` untouched) and record confirmation

**Checkpoint**: All three user stories are independently validated — functional MVP (US1), maintainability (US2), and extensibility (US3).

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect the whole feature, not any single story

- [X] T030 [P] Add top-level `README.md` covering project overview, build/run instructions, and links to `specs/001-pr-review-agent/quickstart.md`
- [X] T031 [P] Run `shellcheck` across `bin/*.sh` and `lib/*.sh` and fix any warnings
- [X] T032 Run the full `quickstart.md` validation checklist end-to-end (steps 1–7) in one pass and record results

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion — no dependency on US2/US3
- **User Story 2 (Phase 4)**: Depends on Foundational completion; T026 additionally depends on US1's built image (T022) since it validates a rebuild-and-rerun cycle
- **User Story 3 (Phase 5)**: Depends on Foundational completion (specifically T009's `AGENT_NAME` resolution); independent of US1/US2 content
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: No dependencies on other stories — this is the MVP
- **User Story 2 (P2)**: Structurally independent; its validation step (T026) reuses the image built in US1 but does not require new US1 code
- **User Story 3 (P3)**: Structurally independent; validated by inspection and a fixture, not by touching `agents/code-review/`

### Within Each User Story

- Tests written and failing before implementation (T011-T015 before T016-T023; T024 before T025-T026; T027 before T028-T029)
- Shared `lib/` helpers before `bin/entrypoint.sh` wiring
- `bin/entrypoint.sh` wiring before Dockerfile finalization
- Story implementation complete before its `quickstart.md` validation task

### Parallel Opportunities

- Setup tasks T002, T003, T004 can run in parallel (different files)
- Foundational tasks T006, T007, T008, T010 can run in parallel once T005 exists (different files); T009 depends on T005+T006
- All US1 test tasks (T011-T015) can run in parallel with each other
- US1 harness content tasks (T018, T019, T020, T021) can run in parallel with each other and with T016/T017 (different files)
- Once Foundational is done, US1, US2, and US3 test/doc authoring (T011-T015, T024, T027) can start in parallel across team members — though US2's T026 and US3's fixture test T027 are cheap to run after US1 lands

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Contract test in tests/contract/review-comment-format.bats"
Task: "Contract test in tests/contract/exit-codes.bats"
Task: "Integration test (pass path) in tests/integration/entrypoint-flow.bats"
Task: "Integration test (issues-found path) in tests/integration/entrypoint-flow.bats"
Task: "Integration test (re-run behavior) in tests/integration/entrypoint-flow.bats"

# Launch all harness content authoring for User Story 1 together:
Task: "Author agents/code-review/CLAUDE.md"
Task: "Author agents/code-review/skills/correctness-check/SKILL.md"
Task: "Author agents/code-review/skills/risk-assessment/SKILL.md"
Task: "Author agents/code-review/skills/test-coverage-check/SKILL.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run `quickstart.md` steps 1–5 against a real/test PR
5. Deploy/demo if ready — this is a complete, working automated PR review agent

### Incremental Delivery

1. Complete Setup + Foundational → foundation ready (input validation, GitHub access, comment rendering, agent selection)
2. Add User Story 1 → validate via `quickstart.md` steps 1–5 → deploy/demo (MVP!)
3. Add User Story 2 → validate via `quickstart.md` step 6 → confirms the harness is maintainable in isolation
4. Add User Story 3 → validate via `quickstart.md` step 7 → confirms the layout supports future agents
5. Polish

### Parallel Team Strategy

With multiple contributors:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Contributor A: User Story 1 (the functional MVP — highest priority)
   - Contributor B: User Story 2 (docs + isolation test, can start immediately, final validation waits on US1's image)
   - Contributor C: User Story 3 (fixture + selection test, can start immediately once T009 lands)
3. Stories complete and validate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
