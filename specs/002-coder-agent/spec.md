# Feature Specification: Coder Agent

**Feature Branch**: `002-coder-agent`

**Created**: 2026-08-25

**Status**: Draft

**Input**: User description: "Now create a `coder-agent` that will take an issue as input, it should read description and implement requested change. For the MVP the changes is super simple you can take a look here. https://github.com/jtuzhanskyi/kids-routine-app/issues/5. The agent should create a new branch, PR with changes. Create a new agent with required but minimalisitc harness skills just to make it work, the agent should take a `main` branch as a source branch it will be up-to-date always. The agent should set `Assignees` - jtuzhanskyi, add `Labels` - `agent-coded` and provide a simple summary in the PR."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Turn a simple issue into a merge-ready PR (Priority: P1)

A maintainer points the agent at a GitHub issue that describes a small, well-defined change (for example, "update the page title text"). The agent reads the issue, makes the requested change starting from the latest `main`, and opens a pull request containing that change — ready for the maintainer to review and merge.

**Why this priority**: This is the entire MVP. Without this flow working end-to-end, the agent delivers no value.

**Independent Test**: Point the agent at a real issue containing a small, unambiguous text/content change (e.g. issue #5 in the reference repo). Confirm a new branch and PR are created from an up-to-date `main`, the PR contains exactly the change the issue asked for, and the PR is reviewable/mergeable as-is.

**Acceptance Scenarios**:

1. **Given** an open issue with a clear, narrow description of a change (e.g. "update the `<title>` text to X"), **When** the agent is run against that issue, **Then** it creates a new branch from the current tip of `main`, commits a change that satisfies the issue's stated acceptance criteria, and opens a pull request targeting `main`.
2. **Given** the newly opened pull request, **When** a maintainer inspects it, **Then** the PR is assigned to `jtuzhanskyi`, carries the `agent-coded` label, and its description contains a short, human-readable summary of what changed and why (referencing the source issue).
3. **Given** `main` has moved forward since the agent last ran, **When** the agent is run again for a new issue, **Then** the new branch is created from the current tip of `main`, not from any previously cached or stale copy.

### Edge Cases

- What happens when the issue description is ambiguous, contradictory, or does not describe a concrete, implementable change? The agent must not guess at large or risky changes; for the MVP it should stop and report that it could not confidently implement the request, rather than opening a low-quality PR.
- What happens when the issue asks for a change that is outside the MVP's supported scope (e.g. multi-file, architectural, or logic-heavy changes)? The agent should recognize this is beyond simple/mechanical scope and stop rather than attempt a large speculative change.
- What happens when there are no actual changes to make (e.g. the requested content already matches what's requested)? The agent should not open an empty or no-op pull request.
- What happens when branch creation or PR creation fails (e.g. naming collision, permissions issue)? The agent should fail loudly with a clear error rather than silently doing nothing.
- What happens when the `agent-coded` label does not yet exist on the target repository? The agent should still succeed in opening the PR (creating the label if possible, or clearly reporting that the label could not be applied).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The agent MUST accept a reference to a single GitHub issue (target repository + issue number) as its input.
- **FR-002**: The agent MUST read the issue's title and description to determine the specific change being requested.
- **FR-003**: The agent MUST create its working branch from the current, up-to-date tip of the target repository's `main` branch — never from a stale or cached copy.
- **FR-004**: The agent MUST implement the change described in the issue directly in the repository's source files.
- **FR-005**: The agent MUST scope itself to simple, mechanical, low-risk changes for the MVP (e.g. small text/content/config edits) and MUST decline to attempt changes that are ambiguous or clearly beyond that scope, reporting why instead of guessing.
- **FR-006**: The agent MUST commit its change to a newly created branch (not directly to `main`).
- **FR-007**: The agent MUST open a pull request from that new branch targeting `main`.
- **FR-008**: The agent MUST set the pull request's assignee to `jtuzhanskyi`.
- **FR-009**: The agent MUST apply the `agent-coded` label to the pull request.
- **FR-010**: The agent MUST include a concise, human-readable summary of the change in the pull request description, and MUST reference the source issue.
- **FR-011**: The agent MUST NOT open a pull request when it made no actual change (no-op).
- **FR-012**: The agent MUST report a clear failure (rather than a partial or silent one) if it cannot read the issue, cannot branch from `main`, cannot commit, or cannot open the pull request.

### Key Entities

- **Issue**: The GitHub issue describing the requested change — has a repository, number, title, and description/acceptance criteria that drive what the agent implements.
- **Branch**: A new, uniquely named branch created from the current tip of `main`, holding the agent's committed change.
- **Pull Request**: The output artifact — links the branch to `main`, carries the assignee (`jtuzhanskyi`), the `agent-coded` label, and a summary description referencing the source issue.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Given a simple, well-defined issue (comparable in scope to the reference example), the agent produces an open, reviewable pull request that fully satisfies the issue's stated acceptance criteria on the first attempt, with no manual follow-up edits required.
- **SC-002**: 100% of pull requests opened by the agent have the correct assignee (`jtuzhanskyi`), the `agent-coded` label, and a non-empty summary referencing the source issue.
- **SC-003**: 100% of branches created by the agent are branched from the current tip of `main` at run time, never from an outdated snapshot.
- **SC-004**: When given an issue outside the MVP's simple-change scope, the agent stops and reports why in 100% of cases, rather than opening an incorrect or incomplete pull request.

## Assumptions

- The agent operates on a target repository distinct from this harness repository (`hermes_factory`); the target repository and issue number are supplied as input at run time, following the same style of externally-supplied configuration as the existing PR-review agent.
- The agent has GitHub credentials with permission to read issues, create branches, push commits, and open/label/assign pull requests on the target repository.
- "Simple" changes for the MVP means small, localized, low-risk edits (e.g. static text/content/config changes) similar in scope to the reference issue (updating an HTML `<title>` value) — not multi-file refactors, new features, or logic changes.
- The `agent-coded` label and the `jtuzhanskyi` GitHub user already exist and are usable on the target repository; if the label is missing, the agent will attempt to create it.
- No automated test suite is assumed to exist on simple target repositories like the reference example; verifying the change is limited to confirming the requested content/text change was made correctly.
- The agent runs on demand (manually triggered per issue) for the MVP; scheduling, polling for new issues, or reacting to issue-comment triggers is out of scope.
