# Data Model: Containerized PR Review Agent

There is no database — "entities" here are the structured artifacts (on-disk config, run-time input, and generated output) that flow through a single container run. Documented as data shapes for clarity and to anchor validation rules and contract tests.

## Agent Harness

Represents one agent's complete, self-contained behavior bundle. Lives on disk, baked into the image at build time.

| Field | Type | Description | Validation |
|---|---|---|---|
| `name` | string | Directory name under `agents/`, also the value of `AGENT_NAME` that selects it | kebab-case, unique across `agents/*` |
| `guidance_path` | path | `agents/<name>/CLAUDE.md` — system prompt / operating guidance | Must exist for the harness to be usable |
| `skills_dir` | path | `agents/<name>/skills/` | May contain zero or more Skill directories |

**Relationships**: One Agent Harness has many Skills (composition — skills live inside the harness's own folder, not shared).

**Lifecycle**: Defined at build time (files committed to the image); selected at run time via `AGENT_NAME`; immutable during a run.

## Skill

A discrete, named unit of review guidance belonging to exactly one Agent Harness.

| Field | Type | Description | Validation |
|---|---|---|---|
| `name` | string | Skill directory name, e.g. `test-coverage-check` | kebab-case, unique within its harness |
| `definition_path` | path | `agents/<agent>/skills/<name>/SKILL.md` | Must exist |

**Relationships**: Belongs to exactly one Agent Harness (FR-004: no cross-agent sharing).

**Lifecycle**: Defined at build time; loaded implicitly by Claude Code when the harness's directory is the working directory for a run.

## Review Target

The run-time input identifying what to review and how to access it. Supplied via container environment variables at `docker run` time (never embedded in the image).

| Field | Type | Description | Validation |
|---|---|---|---|
| `repository` | string | `owner/repo` | Required; must match `^[\w.-]+/[\w.-]+$` |
| `pr_number` | integer | Pull request number within `repository` | Required; positive integer |
| `github_token` | secret string | Credential for reading the PR and posting comments | Required; never logged or echoed |
| `agent_name` | string | Which Agent Harness to run (`AGENT_NAME`) | Optional; defaults to `code-review`; must match an existing `agents/<name>/` |

**Validation rules** (enforced by the entrypoint before any agent/API work starts, so failures are fast and unambiguous — see Edge Cases in spec.md):
- All required fields present and non-empty → else exit non-zero with a specific "missing input" message identifying which field.
- `repository` and `pr_number` well-formed → else exit non-zero with a specific "malformed input" message.
- `agent_name` resolves to an existing `agents/<agent_name>/` directory → else exit non-zero naming the unknown agent.

**Lifecycle**: Constructed once per container run from environment variables; read-only thereafter.

## Review Outcome

The result produced by a completed review run; becomes the content of the posted PR comment.

| Field | Type | Description | Validation |
|---|---|---|---|
| `verdict` | enum | `pass` \| `issues_found` | Required; exactly one of the two (FR-008) |
| `findings` | list of Finding | Present when `verdict = issues_found`; empty when `verdict = pass` | Each Finding has enough detail to act on |
| `run_marker` | string | Hidden marker embedded in the comment (`<!-- pr-review-agent:<agent_name> -->`) identifying the comment as agent-authored | Always present |
| `generated_at` | timestamp | When the review completed, shown in the comment | Always present |

### Finding (nested within Review Outcome)

| Field | Type | Description | Validation |
|---|---|---|---|
| `summary` | string | What the issue is | Required, non-empty |
| `location` | string | Where in the diff (file, and line/hunk if determinable) | Required, non-empty (FR-003 Acceptance Scenario 3: "what and where") |
| `severity` | enum (optional) | e.g. `blocking` \| `advisory`, if the agent distinguishes | Optional — spec does not mandate severity levels, only "enough detail to act on" |

**State transitions**: Review Outcome is produced exactly once per run (in-memory / as CLI output), then immediately rendered into a comment and posted — it is not persisted or mutated afterward (stateless run, per spec Assumptions).

**Relationships**: One Review Target run produces exactly one Review Outcome, which produces exactly one posted PR comment (SC-002: 100% of completed runs → exactly one comment).
