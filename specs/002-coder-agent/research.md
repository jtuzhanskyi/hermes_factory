# Research: Coder Agent

## 1. How the agent gets a real, writable checkout of the target repo

**Decision**: The entrypoint clones the target repository fresh into an ephemeral
workspace directory (`mktemp -d`) for every run, via `gh repo clone
"${GITHUB_REPOSITORY}" "${workspace}"`, before invoking the agent. `gh repo
clone` checks out the repository's default branch (`main`) at its current
tip with no prior local state to go stale.

**Rationale**: FR-003/SC-003 require every run to branch from the *current*
tip of `main`, never a cached copy. A brand-new clone per container run
trivially satisfies this — there is no persistent volume or cache to go
stale, since the container itself is stateless per run (matching the
existing PR-review agent's model, [research.md](../001-pr-review-agent/research.md) §1-2).

**Alternatives considered**:
- A persistent, harness-managed clone reused across runs with `git fetch` +
  `reset --hard origin/main` before each run — adds statefulness (a volume,
  cleanup logic, staleness-detection logic) purely to save clone time on a
  workload that is one run per container invocation; rejected as
  unnecessary complexity for the MVP.
- Letting the agent itself run `git clone`/`gh repo clone` from inside its
  Claude Code session instead of the entrypoint doing it — keeps the
  entrypoint simpler, but pushes a hard-failure mode (clone failing) behind
  the agent's own JSON-output contract, making it harder to reliably map to
  a distinct exit code (FR-012 requires a clear failure signal). Cloning in
  the entrypoint, before the agent even runs, keeps that failure path in
  scripted, testable shell code — consistent with how `fetch_pr_diff`
  already separates "can we reach the target" from "did the agent do its
  job" in the review agent.

## 2. How the agent edits files, commits, and opens the PR

**Decision**: The Claude Code process keeps its working directory at
`agents/coder-agent/` (so its `CLAUDE.md` + `skills/` load the same way the
review agent's do), and the task prompt passed to `claude -p` includes the
**absolute path** of the cloned workspace. The agent is instructed to `cd`
into that path for all `git`/`gh`/file-editing operations, using its Bash
tool for git/gh commands and its Edit/Write tools (which take absolute
paths) for the source-file change itself. The agent performs the branch
creation, commit, push, `gh pr create`, and `gh pr edit --add-label
--add-assignee` steps itself, then reports a structured outcome (see
[contracts/agent-output.md](./contracts/agent-output.md)).

**Rationale**: This keeps the harness/workspace separation clean — no
scaffolding files (`CLAUDE.md`, `skills/`) ever need to be copied into, or
excluded from, the target repo's working tree, so there is no risk of the
agent accidentally committing them. It also matches the feature description
directly: "the agent should create a new branch, PR with changes" — the
agent, not the shell wrapper, performs the GitHub write operations, using
the same `gh`/`claude` tool surface the review agent already has.

**Alternatives considered**:
- Copying `CLAUDE.md`/`skills/` into the cloned workspace and running
  `claude -p` with the workspace as cwd — lets the agent use only relative
  paths, but introduces a containment problem (scaffolding files could end
  up `git add -A`'d into the commit) that then needs its own safety net;
  rejected in favor of passing an absolute workspace path, which needs no
  such net.
- Having the shell entrypoint perform the branch/commit/push/PR-create
  itself, with the agent only producing a patch/diff for the wrapper to
  apply — more scriptable, but re-introduces exactly the "agent produces a
  diff, harness applies it" pattern the review agent deliberately avoided
  for its own read-only case, and here would require the wrapper to
  understand arbitrary diffs well enough to apply them safely; rejected as
  more code for less flexibility on what is supposed to be a minimal MVP
  harness.

## 3. Structured outcome contract (success vs. decline vs. no-op vs. failure)

**Decision**: The agent's final stdout is exactly one JSON object with a
`status` field: `"pr_opened"`, `"declined"`, or `"no_op"` — see
[contracts/agent-output.md](./contracts/agent-output.md). The entrypoint
maps `pr_opened` to exit `0` (after a post-condition check, see §5),
`declined`/`no_op` to their own distinct non-zero-but-not-a-bug exit codes,
and treats a crashed/timed-out/malformed-output agent run as a hard failure
— mirroring the review agent's `extract_outcome_json` pattern
(`lib/run-agent.sh`).

**Rationale**: FR-005 and the edge cases require the agent to be able to
*decline* (ambiguous/out-of-scope issue) or *no-op* (nothing to change)
without that being indistinguishable from a crash, while FR-012 requires
genuine failures (can't read the issue, can't branch, can't commit, can't
open the PR) to be loud and distinct. A three-way status field, plus the
existing crash/timeout/malformed-JSON failure path, covers all four
outcomes named in the spec's edge cases without inventing a fourth
mechanism.

**Alternatives considered**:
- Reusing the review agent's `{"verdict": "pass" | "issues_found", ...}`
  shape by treating "declined" as a kind of `issues_found` — rejected, the
  semantics don't match (this isn't a review verdict on someone else's
  code) and it would blur "the agent made a judgment call" with "the agent
  found a defect," a distinction the spec's edge cases care about.
- Only two states (success/failure), with "declined" and "no-op" folded
  into "failure" — rejected by SC-004, which explicitly requires declines
  to be *reported*, not treated as errors, and by the no-op edge case,
  which explicitly forbids opening an empty PR without calling that a
  failure either.

## 4. Exit codes

**Decision**: Extend the existing exit-code convention (`contracts/exit-codes.md`
pattern from the review agent) with a parallel, non-overlapping table for
the coder agent — see [contracts/exit-codes.md](./contracts/exit-codes.md).

**Rationale**: The review agent's codes (`10/20/30/40`) are specific to its
own failure modes (bad input, PR inaccessible, review failed, comment post
failed) and don't have slots for "issue inaccessible," "clone failed,"
"declined," or "no-op." Reusing the same numbers for different meanings
across agents would make any shared caller/CI logic ambiguous about which
agent produced the code. A parallel table keeps each agent's codes
self-describing within its own contract, matching the "self-contained,
never reference another agent's directory" isolation rule already enforced
by `tests/unit/harness-isolation.bats`.

**Alternatives considered**: A single global exit-code table shared by all
agents in this repo — more consistent on paper, but would require
renumbering the already-shipped review-agent codes (a breaking change to
`specs/001-pr-review-agent/contracts/exit-codes.md`) to make room for the
coder agent's extra states; rejected as an unjustified change to a shipped
feature.

## 5. Verifying the PR's assignee/label after the agent claims success

**Decision**: After the agent reports `status: "pr_opened"`, the entrypoint
runs one lightweight `gh pr view <pr_number> --repo <repo> --json
assignees,labels` check and fails loudly (a distinct exit code) if the
assignee (`jtuzhanskyi`) or label (`agent-coded`) is missing, rather than
trusting the agent's self-report unconditionally.

**Rationale**: SC-002 requires *100%* of opened PRs to carry the correct
assignee and label — a measurable, testable success criterion, not just an
instruction to the agent. A cheap read-only `gh pr view` after the fact
turns "the agent was told to set these" into "the harness confirmed they
are set," closing the gap between instructing the agent and guaranteeing
the outcome, at negligible cost (one extra read call).

**Alternatives considered**: Trusting the agent's structured output fields
(`assignee`, `label`) as sufficient evidence — simpler, but SC-002's "100%"
framing reads as a measurable guarantee the harness should verify, not just
report; a single agent misstep (e.g. `gh pr edit` failing silently mid-run)
would otherwise go undetected.

## 6. Scope guard for "simple, mechanical" changes (FR-005)

**Decision**: A dedicated `scope-assessment` skill instructs the agent to
decline (rather than attempt) any issue whose requested change: touches
more than a small, bounded number of files; requires new dependencies,
build/config wiring, or logic/control-flow changes; or is ambiguous about
what the final content should be. The skill gives the reference issue
(`kids-routine-app#5`, a `<title>` text change) as the calibration example
of what's in scope.

**Rationale**: FR-005/edge cases require the agent to recognize
out-of-scope or ambiguous requests and stop rather than guess. Encoding
this as an explicit skill (mirroring the review agent's `risk-assessment`
skill shape) keeps the judgment call auditable and adjustable independent
of the rest of `CLAUDE.md`.

**Alternatives considered**: Enforcing scope mechanically in the shell
harness (e.g. rejecting any run whose resulting diff touches more than N
files) — a useful secondary guard, but on its own can't recognize
*ambiguity* (e.g. "update the wording" with no target text given), which
requires judgment the shell layer can't perform; the skill-based approach
is primary, with the per-file-count check folded in as one of its stated
heuristics rather than a separate enforcement mechanism.
