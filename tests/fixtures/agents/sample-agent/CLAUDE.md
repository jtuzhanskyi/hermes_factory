# Sample Agent (test fixture)

Used only by `tests/unit/agent-selection.bats` to prove `AGENT_NAME`
resolution can select an arbitrary agent directory. Never shipped in the
container image (excluded from the build context by `.dockerignore`'s
`tests/` exclusion).
