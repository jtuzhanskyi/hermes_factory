# Skill: Correctness Check

Look for actual bugs the diff introduces — not style preferences.

## What to look for

- Logic errors: off-by-one, inverted conditions, wrong operator, incorrect
  boundary handling.
- Null/undefined/empty-input handling that the new code doesn't account for.
- Resource handling: unclosed files/connections, missing cleanup on error
  paths introduced by the diff.
- Concurrency issues introduced by the change (races, missing locks) if
  applicable to the language/context.
- Broken control flow: unreachable code, early returns that skip needed
  cleanup, exception paths that swallow errors silently.
- Changed function signatures/return types where a caller elsewhere in the
  diff (or visible via `gh`) wasn't updated to match.

## What NOT to flag here

- Pure style/formatting (not this skill's concern).
- Missing tests (see `test-coverage-check`).
- Risk framing without a concrete bug (see `risk-assessment`).

## Reporting

For each bug found, produce a finding with:
- `summary`: the specific defect and why it's wrong — not just "this looks
  off."
- `location`: file path and line/hunk from the diff.

If the diff replaces valid markup/code with an obviously invalid placeholder
element or token (e.g. a non-standard tag like `<BROKEN>`), treat it as a
blocking correctness bug regardless of anything else in the diff — this
pattern indicates a corrupted or incomplete change, not a deliberate one.
