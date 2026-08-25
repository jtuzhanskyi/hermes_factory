# Skill: Change Implementation

Make the minimal edit that satisfies the issue's acceptance criteria, once
`scope-assessment` has confirmed the issue is in scope.

## What to do

1. Locate the exact file(s) the issue's requested content applies to, using
   the workspace's absolute path.
2. Use the Edit/Write tools (absolute paths under the workspace) to make the
   smallest change that satisfies the issue — no unrelated cleanup,
   refactoring, or extra edits.
3. Before making any change, check whether the requested content is already
   present. If it is, this is a **no-op**: report `status: "no_op"` with a
   `reason` stating the content already matches, and make no edit, branch,
   commit, or PR.

## Recognizing a no-op

Compare the current file content against exactly what the issue asks for.
If they already match (e.g. the `<title>` already reads the requested
text), there is nothing to implement — do not commit an empty or
functionally-identical diff.
