# Skill: Test Coverage Check

Check whether new or changed logic in the diff has corresponding test
coverage.

## What to look for

- New functions/methods/branches with no new or updated test exercising
  them.
- Bug fixes with no regression test added for the specific case being fixed.
- Changed behavior (e.g. a modified return value or edge-case handling)
  where the existing tests weren't updated to match, or don't cover the new
  case.
- New error paths (validation, exception handling) with no test asserting
  the failure behavior.

Use `gh` to look at the full test files if the diff doesn't make it obvious
whether coverage already exists elsewhere in the repo.

## What NOT to flag here

- Coverage gaps in code the diff didn't touch (out of scope for this
  review).
- Style of existing tests — only their presence/absence for the new
  behavior.

## Reporting

For each gap found, produce a finding with:
- `summary`: what new/changed behavior lacks a test, and what should be
  tested.
- `location`: file path and line/hunk of the untested logic (not the missing
  test file).
- `severity: "advisory"` in general; use `"blocking"` only when the untested
  logic is itself high-risk (e.g. touches the paths called out in
  `risk-assessment`).
