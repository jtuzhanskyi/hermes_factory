# Adding a new agent

The container can run any agent harness under `agents/<agent-name>/`,
selected at run time via the `AGENT_NAME` environment variable
(default: `code-review`). Adding a new agent never requires touching
`agents/code-review/`, `bin/`, `lib/`, or `docker/Dockerfile` beyond the
one line that copies `agents/` into the image (already generic) — **as
long as the new agent fits the review contract**: a PR diff in, a single
structured verdict out. `coder-agent` (`specs/002-coder-agent/`) is the
deliberate, called-out exception: its input (an issue number, not a PR),
required credential scope (write, not read), and output (a branch + PR
across three terminal states, not one comment) don't fit that contract, so
it necessarily adds its own dispatch path in `bin/entrypoint.sh`,
coder-specific functions in `lib/`, and the `git` package in
`docker/Dockerfile` — see `specs/002-coder-agent/plan.md`'s Complexity
Tracking for the full rationale. Everything below still applies to any
agent that *does* fit the review contract.

## Steps

1. Create `agents/<new-agent-name>/CLAUDE.md` — the system prompt /
   operating guidance for this agent. It must end with instructions to
   produce exactly one JSON object on stdout in the shape the entrypoint
   expects (see `agents/code-review/CLAUDE.md` for the exact contract):

   ```json
   {"verdict": "pass" | "issues_found", "findings": [{"summary": "...", "location": "...", "severity": "..."}]}
   ```

2. Create `agents/<new-agent-name>/skills/<skill-name>/SKILL.md` for each
   discrete piece of guidance this agent applies. Zero or more skills are
   allowed.

3. Keep the new agent self-contained: it must not reference
   `agents/code-review/` (or any other agent's directory) or any path
   outside its own folder. `tests/unit/harness-isolation.bats` enforces
   this for `agents/code-review/`; apply the same discipline to your new
   agent.

4. Rebuild the image:

   ```sh
   docker build -t pr-review-agent:local -f docker/Dockerfile .
   ```

   `docker/Dockerfile`'s `COPY agents/ /app/agents/` picks up the new
   folder automatically — no Dockerfile edit needed.

5. Select it at run time:

   ```sh
   docker run --rm \
     -e GITHUB_REPOSITORY="my-org/my-repo" \
     -e PR_NUMBER="42" \
     -e GITHUB_TOKEN="ghp_..." \
     -e ANTHROPIC_API_KEY="sk-ant-..." \
     -e AGENT_NAME="<new-agent-name>" \
     pr-review-agent:local
   ```

   See `specs/001-pr-review-agent/contracts/container-input.md` for the
   full input contract. An unknown `AGENT_NAME` fails fast with exit code
   `10` and a stderr message naming the unrecognized agent
   (`specs/001-pr-review-agent/contracts/exit-codes.md`).
