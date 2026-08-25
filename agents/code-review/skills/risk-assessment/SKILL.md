# Skill: Risk Assessment

Flag changes that are risky independent of whether they contain a provable
bug — changes that warrant a human's attention because of what they touch or
how large/unreviewable they are.

## What to look for

- Security-sensitive paths: auth/authz logic, credential handling, input
  sanitization, cryptography, access control checks, anything touching
  secrets or tokens.
- Unusually large or sprawling diffs that are hard to review carefully in one
  pass — call this out even without a specific bug, since large diffs hide
  bugs.
- Missing error handling on new I/O, network calls, or external API calls
  introduced by the diff (distinct from a proven bug — this is "this can
  fail and nothing handles it").
- Changes to shared/critical infrastructure (config defaults, migration
  scripts, CI/build pipeline, dependency versions) where a mistake has
  outsized blast radius.
- Silent behavior changes: a rename, default-value change, or removed
  validation that isn't called out in the PR description.

## Reporting

For each risk found, produce a finding with:
- `summary`: what the risk is and why it matters (blast radius, sensitivity).
- `location`: file path and line/hunk from the diff.
- `severity: "advisory"` unless the risk is severe enough to block merging
  outright (e.g. a credential clearly exposed), in which case use
  `"blocking"`.
