# Skill: Scope Assessment

Decide whether the issue describes a simple, mechanical change this agent
should attempt, or whether it should decline.

## Decline the issue when the requested change

- Touches more than a small, bounded number of files (a handful at most —
  this agent is for small, mechanical edits, not multi-file features).
- Requires adding new dependencies, or wiring new build/config.
- Requires logic or control-flow changes (new branches, new functions with
  behavior, new conditionals) rather than a content/text/markup edit.
- Is ambiguous about what the final content should be — e.g. "improve the
  wording" or "fix the UX" with no concrete target text or behavior given.

## In-scope calibration example

`kids-routine-app#5` — an issue asking for the page's `<title>` text to be
changed to specific wording. This is in scope: one file, no new logic, no
ambiguity about the target content.

## Reporting

If declining, produce a `reason` that specifically names why: which
scope-guard rule was triggered, and (for ambiguity) what information is
missing. Do not attempt any edit, branch, or PR when declining.
