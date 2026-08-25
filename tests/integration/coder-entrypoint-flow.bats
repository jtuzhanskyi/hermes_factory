#!/usr/bin/env bats

load '../test_helper'

setup() {
  setup_stub_path
  export ENTRYPOINT="${REPO_ROOT}/bin/entrypoint.sh"
  export AGENTS_ROOT="${REPO_ROOT}/agents"
  export AGENT_NAME="coder-agent"
  export GITHUB_REPOSITORY="my-org/my-repo"
  export ISSUE_NUMBER="5"
  export GITHUB_TOKEN="test-token"
  export ANTHROPIC_API_KEY="test-key"

  write_stub "git" '
case "$1" in
  rev-parse) echo "deadbeef"; exit 0 ;;
  *) exit 0 ;;
esac
'
}

teardown() {
  teardown_stub_path
  unset GITHUB_REPOSITORY ISSUE_NUMBER GITHUB_TOKEN ANTHROPIC_API_KEY AGENT_NAME AGENTS_ROOT CODER_ASSIGNEE CODER_LABEL
}

@test "success path: pr_opened, verified postconditions, exit 0, outcome JSON printed" {
  write_stub "gh" '
case "$1 $2" in
  "issue view") echo "{\"title\":\"Fix title\",\"body\":\"Change title\",\"url\":\"https://github.com/my-org/my-repo/issues/5\"}"; exit 0 ;;
  "repo clone") mkdir -p "$4"; exit 0 ;;
  "pr view") echo "{\"assignees\":[{\"login\":\"jtuzhanskyi\"}],\"labels\":[{\"name\":\"agent-coded\"}]}"; exit 0 ;;
  *) exit 0 ;;
esac
'
  write_stub "claude" 'echo "{\"status\":\"pr_opened\",\"branch\":\"coder-agent/issue-5\",\"pr_number\":42,\"pr_url\":\"https://github.com/my-org/my-repo/pull/42\",\"summary\":\"Fixes #5\"}"; exit 0'

  run "${ENTRYPOINT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pr_opened"* ]]
  [[ "$output" == *"coder-agent/issue-5"* ]]
}

@test "no-op path: exit 32, no branch/PR created, reason on stderr" {
  write_stub "gh" '
case "$1 $2" in
  "issue view") echo "{\"title\":\"t\",\"body\":\"b\",\"url\":\"u\"}"; exit 0 ;;
  "repo clone") mkdir -p "$4"; exit 0 ;;
  "pr create"|"pr edit") echo "SHOULD NOT BE CALLED" >&2; exit 1 ;;
  *) exit 0 ;;
esac
'
  write_stub "claude" 'echo "{\"status\":\"no_op\",\"reason\":\"Title already matches.\"}"; exit 0'

  run "${ENTRYPOINT}"
  [ "$status" -eq 32 ]
  [[ "$output" == *"Title already matches."* ]]
}

@test "declined path: exit 31, reason on stderr" {
  write_stub "gh" '
case "$1 $2" in
  "issue view") echo "{\"title\":\"t\",\"body\":\"b\",\"url\":\"u\"}"; exit 0 ;;
  "repo clone") mkdir -p "$4"; exit 0 ;;
  *) exit 0 ;;
esac
'
  write_stub "claude" 'echo "{\"status\":\"declined\",\"reason\":\"Multi-file, ambiguous change.\"}"; exit 0'

  run "${ENTRYPOINT}"
  [ "$status" -eq 31 ]
  [[ "$output" == *"Multi-file, ambiguous change."* ]]
}

@test "postcondition-mismatch path: exit 40 when label/assignee missing" {
  write_stub "gh" '
case "$1 $2" in
  "issue view") echo "{\"title\":\"t\",\"body\":\"b\",\"url\":\"u\"}"; exit 0 ;;
  "repo clone") mkdir -p "$4"; exit 0 ;;
  "pr view") echo "{\"assignees\":[],\"labels\":[{\"name\":\"agent-coded\"}]}"; exit 0 ;;
  *) exit 0 ;;
esac
'
  write_stub "claude" 'echo "{\"status\":\"pr_opened\",\"branch\":\"coder-agent/issue-5\",\"pr_number\":42,\"pr_url\":\"u\",\"summary\":\"s\"}"; exit 0'

  run "${ENTRYPOINT}"
  [ "$status" -eq 40 ]
}
