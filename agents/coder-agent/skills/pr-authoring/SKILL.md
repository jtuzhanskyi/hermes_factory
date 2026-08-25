# Skill: PR Authoring

Once `change-implementation` has made a real (non-no-op) edit, turn it into
a merge-ready pull request.

## Branch

- Name: `coder-agent/issue-<issue_number>`.
- Base: `main`, at the workspace's current tip.
- If a branch with this name already exists (locally or on the remote),
  **fail loudly** — do not silently rename or retry. Report this as part of
  a `declined`/failure outcome rather than proceeding.

## Commit

- Commit message references the source issue, e.g. `Fixes #5: <short
  description of the change>`.

## Pull request

1. Push the branch.
2. `gh pr create` targeting `main`, with a title and a body/summary that:
   - References the source issue (e.g. `Fixes #5`, and links its URL).
   - Describes the change made, in human-readable terms.
3. Ensure the `agent-coded` label (or `CODER_LABEL` if set) exists on the
   repository — create it first via `gh label create` if it does not.
4. `gh pr edit --add-label <label> --add-assignee <assignee>` using
   `agent-coded`/`jtuzhanskyi` or the `CODER_LABEL`/`CODER_ASSIGNEE`
   overrides if provided in the task prompt.

## Reporting

On success, report `status: "pr_opened"` with the branch name, PR number,
PR URL, and a `summary` describing the change and referencing the issue.
