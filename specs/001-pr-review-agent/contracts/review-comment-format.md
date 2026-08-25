# Contract: Posted PR Review Comment Format

The single top-level comment the agent posts on the target PR (FR-009, Assumptions: one top-level comment, not inline line comments).

## Structure

```markdown
<!-- pr-review-agent:{agent_name} -->
## 🤖 Automated Code Review — {verdict_heading}

_Run at {generated_at}_

{body}
```

Where `{verdict_heading}` and `{body}` depend on `verdict`:

### `verdict = pass`

```markdown
## 🤖 Automated Code Review — No blocking issues found

_Run at 2026-08-25T10:00:00Z_

This PR was reviewed automatically and no blocking issues were found.
```

Must be unambiguous that the review ran and passed — never blank, never a generic/error-shaped message (Acceptance Scenario 2).

### `verdict = issues_found`

```markdown
## 🤖 Automated Code Review — Issues found

_Run at 2026-08-25T10:00:00Z_

The following issues were found:

1. **{finding.summary}**
   - Location: `{finding.location}`
   - Severity: {finding.severity}   <!-- omitted if the agent didn't assign one -->

2. **{finding.summary}**
   - Location: `{finding.location}`
```

Each listed finding MUST include both a summary (what) and a location (where), per Acceptance Scenario 3.

## Rules

1. Exactly one comment per run (SC-002) — never zero on success, never more than one.
2. The hidden `<!-- pr-review-agent:{agent_name} -->` marker is always the first line, enabling future tooling to recognize the agent's own comments without it being visible in the rendered PR.
3. Re-running against the same PR (e.g. after new commits) posts a new comment with a new `generated_at`; it never edits or deletes a prior comment (spec Assumptions / Edge Cases).
4. No comment is posted for verdicts other than `pass`/`issues_found` — those two are exhaustive (FR-008).
