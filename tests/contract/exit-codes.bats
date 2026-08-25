#!/usr/bin/env bats

load '../test_helper'

setup() {
  setup_stub_path
  export ENTRYPOINT="${REPO_ROOT}/bin/entrypoint.sh"
  export AGENTS_ROOT="${REPO_ROOT}/agents"
  export GITHUB_REPOSITORY="my-org/my-repo"
  export PR_NUMBER="42"
  export GITHUB_TOKEN="test-token"
  export ANTHROPIC_API_KEY="test-key"
}

teardown() {
  teardown_stub_path
  unset GITHUB_REPOSITORY PR_NUMBER GITHUB_TOKEN ANTHROPIC_API_KEY AGENT_NAME AGENTS_ROOT
}

@test "exit 10: missing required input" {
  unset PR_NUMBER
  run "${ENTRYPOINT}"
  [ "$status" -eq 10 ]
  [[ "$output" == *"PR_NUMBER"* ]]
}

@test "exit 10: malformed input" {
  export GITHUB_REPOSITORY="not-a-repo"
  run "${ENTRYPOINT}"
  [ "$status" -eq 10 ]
  [[ "$output" == *"GITHUB_REPOSITORY"* ]]
}

@test "exit 10: unknown agent" {
  export AGENT_NAME="does-not-exist"
  run "${ENTRYPOINT}"
  [ "$status" -eq 10 ]
  [[ "$output" == *"does-not-exist"* ]]
}

@test "exit 20: PR not accessible" {
  write_stub "gh" 'if [[ "$1" == "pr" && "$2" == "view" ]]; then exit 1; fi; exit 0'
  write_stub "claude" 'exit 0'
  run "${ENTRYPOINT}"
  [ "$status" -eq 20 ]
  [[ "$output" == *"Unable to access PR"* ]]
}

@test "exit 30: agent crash/timeout" {
  write_stub "gh" '
if [[ "$1" == "pr" && "$2" == "view" ]]; then exit 0; fi
if [[ "$1" == "pr" && "$2" == "diff" ]]; then echo "diff --git a/f b/f"; exit 0; fi
exit 0
'
  write_stub "claude" 'exit 1'
  run "${ENTRYPOINT}"
  [ "$status" -eq 30 ]
}

@test "exit 40: comment post failed, outcome printed to stdout" {
  write_stub "gh" '
if [[ "$1" == "pr" && "$2" == "view" ]]; then exit 0; fi
if [[ "$1" == "pr" && "$2" == "diff" ]]; then echo "diff --git a/f b/f"; exit 0; fi
if [[ "$1" == "pr" && "$2" == "comment" ]]; then exit 1; fi
exit 0
'
  write_stub "claude" 'echo "{\"verdict\":\"pass\",\"findings\":[]}"; exit 0'
  run "${ENTRYPOINT}"
  [ "$status" -eq 40 ]
  [[ "$output" == *"pass"* ]]
}
