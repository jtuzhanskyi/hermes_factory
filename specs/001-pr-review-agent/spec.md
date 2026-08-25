# Feature Specification: Containerized PR Review Agent

**Feature Branch**: `[001-pr-review-agent]`

**Created**: 2026-08-25

**Status**: Draft

**Input**: User description: "Build a docker image where I can run a claude agent to review a PR in GitHub. I'd like to have a separate folder with a specific set of skills, claude.md file to support `code-review` agent and guide how to that. The agent should spin up in docker container (kind of sandbox) run the review of PR and depends on result include comment with result into the github PR. The agent harness should contains a simple set of system prompt, a few skills for revieing pr and this all things should be shipped into the container. Having an assumption that in the future we will have another agent to write code or find but with it's own harness skills, mcp etc, so just keep in mind so we can extend a list of agents in the future."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run an automated code review on a PR (Priority: P1)

A developer or platform operator points the containerized code-review agent at a specific GitHub pull request. The agent runs inside an isolated sandbox container, examines the PR's changes, forms a review verdict, and leaves the outcome as a comment on the pull request so the PR author and reviewers can see it without anyone running a review manually.

**Why this priority**: This is the entire value proposition of the feature — without a working end-to-end run that produces a visible PR comment, nothing else matters.

**Independent Test**: Can be fully tested by starting the container against a real (or test) PR reference and confirming a review comment appears on that PR, delivering a working automated review with no other stories implemented.

**Acceptance Scenarios**:

1. **Given** a valid GitHub PR reference and valid GitHub credentials are supplied to the container, **When** the container is started, **Then** the agent retrieves the PR's changes, produces a review outcome, and posts a single comment on that PR summarizing the findings.
2. **Given** the PR under review has no issues worth flagging, **When** the review completes, **Then** the posted comment clearly communicates that the review passed with no blocking findings (not silence, and not a generic error-shaped message).
3. **Given** the review agent identifies one or more issues, **When** the review completes, **Then** the posted comment lists each issue with enough detail (what and where) for a reviewer to act on it.

---

### User Story 2 - Maintain the code-review agent's instructions and skills independently (Priority: P2)

A platform maintainer needs to update how the code-review agent behaves — refine its system prompt, add a new review skill, or adjust an existing one — by editing files in a dedicated, clearly-scoped location, without touching unrelated infrastructure or other agents' configurations.

**Why this priority**: The review quality and behavior will need to evolve; if the instructions and skills aren't cleanly separated and easy to find, every tweak becomes riskier and slower, but the system is still usable end-to-end without this being perfect on day one.

**Independent Test**: Can be fully tested by editing a skill or the agent's guidance file, rebuilding the image, and confirming the new/changed behavior is reflected in the next review run — without needing to modify any other part of the system.

**Acceptance Scenarios**:

1. **Given** the code-review agent's dedicated folder of skills and guidance file, **When** a maintainer adds a new skill file or edits the guidance file, **Then** rebuilding the image produces a container whose review behavior reflects that change.
2. **Given** the maintainer only changed the code-review agent's own files, **When** the image is rebuilt, **Then** no other agent's configuration or behavior is affected.

---

### User Story 3 - Add a new, differently-configured agent later (Priority: P3)

A platform maintainer, at a future date, wants to introduce a second agent (for example, one that writes code or investigates issues) with its own system prompt, its own skills, and its own set of external tool connections — without reworking the code-review agent or the container packaging approach already in place.

**Why this priority**: This is a forward-looking requirement (no second agent is being built now), but the layout and packaging decisions made for the first agent must not preclude it, so it is validated architecturally rather than functionally in this iteration.

**Independent Test**: Can be evaluated by inspecting the repository layout and confirming a new agent's harness, skills, and guidance file could be added side-by-side with the code-review agent's, each independently selectable when building or running a container, with no shared state that would force them to collide.

**Acceptance Scenarios**:

1. **Given** the current repository layout for agent harnesses, **When** a new agent's folder (system prompt, skills, guidance file) is added alongside the code-review agent's, **Then** the existing code-review agent continues to work unmodified.
2. **Given** two agent configurations exist side-by-side, **When** a container is run, **Then** it is possible to select which agent's harness is loaded without ambiguity.

---

### Edge Cases

- What happens when the referenced PR does not exist, is already closed/merged, or the container is not authorized to access the repository?
- What happens when the PR is too large to review in full (e.g., very large diffs)?
- How does the system behave if the agent's review process fails partway through (crash, timeout, unexpected error)? It must not fail silently — the operator running the container needs to know the review did not complete, and no misleading comment should be posted.
- What happens if posting the comment to GitHub fails after the review itself completed successfully (e.g., transient GitHub API failure, permissions issue)?
- What happens if the same PR is reviewed more than once (re-run after new commits are pushed)? Each run should result in its own clearly identifiable comment rather than silently overwriting history in a confusing way.
- What happens if required inputs (PR reference, GitHub credentials) are missing or malformed when the container starts?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a container image capable of running a "code-review" agent that reviews a specified GitHub pull request end-to-end.
- **FR-002**: System MUST accept, as input at container start, a reference to the specific pull request to review (repository and PR number, or equivalent) and the credentials needed to access it.
- **FR-003**: System MUST run the review inside an isolated, sandboxed container environment that does not require or assume access to systems beyond what the review task needs.
- **FR-004**: The code-review agent's instructions (a guidance/system-prompt file) and its review skills MUST live in a dedicated, clearly-named location separate from any future agent's configuration.
- **FR-005**: The code-review agent's harness MUST consist of a system prompt plus a small, purpose-built set of skills for reviewing a PR (e.g., identifying correctness issues, flagging risky changes, checking for missing tests) — not a general-purpose, open-ended toolset.
- **FR-006**: System MUST package the agent's harness (system prompt, skills, guidance file) inside the container image so no separate delivery step is needed at run time.
- **FR-007**: System MUST retrieve the actual code changes (diff) and relevant context for the specified PR before producing a review outcome.
- **FR-008**: System MUST produce a review outcome that distinguishes at least between "no blocking issues found" and "issues found," with enough detail in the latter case to act on.
- **FR-009**: System MUST post the review outcome as a comment on the target GitHub pull request.
- **FR-010**: System MUST clearly surface failures (unable to access the PR, review process error, failure to post the comment) to whoever/whatever started the container, rather than exiting silently or posting a misleading success comment.
- **FR-011**: System's packaging/layout MUST allow additional agents — each with its own system prompt, skills, guidance file, and external tool connections — to be added later without modifying the code-review agent's harness or requiring a different container-building approach.
- **FR-012**: System MUST make it possible to select which agent's harness a container run uses, once more than one agent exists.

### Key Entities

- **Agent Harness**: The bundle that defines one agent's behavior — a system prompt/guidance file plus a set of skills — packaged for a specific purpose (e.g., "code-review"). Each agent has exactly one harness.
- **Skill**: A discrete, named unit of review guidance or capability (e.g., "check for missing tests") that belongs to one agent's harness.
- **Review Target**: A specific GitHub pull request identified by repository and PR number, along with the credentials/context needed to read it and comment on it.
- **Review Outcome**: The result produced by a completed review run — a verdict (e.g., pass / issues found) plus the supporting findings, which becomes the content of the posted PR comment.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can go from "container started against a PR" to "review comment visible on that PR" in a single run, with no manual steps in between.
- **SC-002**: 100% of completed review runs result in exactly one review comment on the correct PR reflecting that run's outcome.
- **SC-003**: 100% of runs that fail before producing a review (bad input, access failure, crash) are surfaced as a visible failure to the operator, with zero cases of a misleading "success" comment being posted after a failed run.
- **SC-004**: A maintainer can change the code-review agent's skills or guidance and see the change reflected in the next run without needing to modify any file outside that agent's dedicated folder.
- **SC-005**: Adding a second, differently-configured agent in the future requires no changes to the code-review agent's existing files.

## Assumptions

- Review runs are started explicitly (e.g., by a person or an external automation invoking the container with a PR reference) rather than the container itself watching for new PRs or listening for webhooks; wiring this into a specific CI/CD system is out of scope for this feature.
- The review outcome is posted as a single top-level PR comment summarizing findings, rather than multiple inline, line-by-line review comments; the latter can be considered as a future enhancement.
- Credentials for accessing GitHub (reading the PR and posting comments) are supplied to the container at run time (e.g., as environment configuration) rather than being embedded in the image.
- "Isolated/sandboxed" means the container does not retain state between runs and does not require standing access to unrelated systems — it is not a requirement for a specific sandboxing technology or security certification.
- Only one review comment is expected per run; behavior across repeated runs on the same PR (e.g., after new commits) is to post a new comment each time rather than editing a prior one.
- The initial scope covers exactly one agent type ("code-review"); the ability to add further agents later is a structural/architectural expectation validated by inspection, not a second working agent delivered in this feature.
