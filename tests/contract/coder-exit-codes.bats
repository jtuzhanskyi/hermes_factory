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

stub_gh_success_clone() {
  write_stub "gh" '
case "$1 $2" in
  "issue view") echo "{\"title\":\"t\",\"body\":\"b\",\"url\":\"https://github.com/my-org/my-repo/issues/5\"}"; exit 0 ;;
  "repo clone") mkdir -p "$4"; exit 0 ;;
  "pr view") echo "{\"assignees\":[{\"login\":\"jtuzhanskyi\"}],\"labels\":[{\"name\":\"agent-coded\"}]}"; exit 0 ;;
  *) exit 0 ;;
esac
'
}

@test "exit 0: pr_opened with verified assignee/label" {
  stub_gh_success_clone
  write_stub "claude" 'echo "{\"status\":\"pr_opened\",\"branch\":\"coder-agent/issue-5\",\"pr_number\":42,\"pr_url\":\"https://github.com/my-org/my-repo/pull/42\",\"summary\":\"Fixes #5\"}"; exit 0'

  run "${ENTRYPOINT}"
  [ "$status" -eq 0 ]
}

@test "exit 10: missing required input" {
  unset ISSUE_NUMBER
  run "${ENTRYPOINT}"
  [ "$status" -eq 10 ]
  [[ "$output" == *"ISSUE_NUMBER"* ]]
}

@test "exit 20: issue not accessible" {
  write_stub "gh" 'exit 1'
  run "${ENTRYPOINT}"
  [ "$status" -eq 20 ]
}

@test "exit 21: clone failed" {
  write_stub "gh" '
case "$1 $2" in
  "issue view") echo "{\"title\":\"t\",\"body\":\"b\",\"url\":\"u\"}"; exit 0 ;;
  "repo clone") exit 1 ;;
  *) exit 0 ;;
esac
'
  run "${ENTRYPOINT}"
  [ "$status" -eq 21 ]
}

@test "exit 30: agent crash/timeout" {
  write_stub "gh" '
case "$1 $2" in
  "issue view") echo "{\"title\":\"t\",\"body\":\"b\",\"url\":\"u\"}"; exit 0 ;;
  "repo clone") mkdir -p "$4"; exit 0 ;;
  *) exit 0 ;;
esac
'
  write_stub "claude" 'exit 1'
  run "${ENTRYPOINT}"
  [ "$status" -eq 30 ]
}

@test "exit 31: declined" {
  stub_gh_success_clone
  write_stub "claude" 'echo "{\"status\":\"declined\",\"reason\":\"too ambiguous\"}"; exit 0'

  run "${ENTRYPOINT}"
  [ "$status" -eq 31 ]
  [[ "$output" == *"too ambiguous"* ]]
}

@test "exit 32: no-op" {
  stub_gh_success_clone
  write_stub "claude" 'echo "{\"status\":\"no_op\",\"reason\":\"already matches\"}"; exit 0'

  run "${ENTRYPOINT}"
  [ "$status" -eq 32 ]
  [[ "$output" == *"already matches"* ]]
}

@test "exit 40: postcondition mismatch" {
  write_stub "gh" '
case "$1 $2" in
  "issue view") echo "{\"title\":\"t\",\"body\":\"b\",\"url\":\"u\"}"; exit 0 ;;
  "repo clone") mkdir -p "$4"; exit 0 ;;
  "pr view") echo "{\"assignees\":[],\"labels\":[]}"; exit 0 ;;
  *) exit 0 ;;
esac
'
  write_stub "claude" 'echo "{\"status\":\"pr_opened\",\"branch\":\"coder-agent/issue-5\",\"pr_number\":42,\"pr_url\":\"u\",\"summary\":\"s\"}"; exit 0'

  run "${ENTRYPOINT}"
  [ "$status" -eq 40 ]
}
