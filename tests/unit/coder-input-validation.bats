#!/usr/bin/env bats

load '../test_helper'

setup() {
  setup_stub_path
  export REPO_ROOT="${REPO_ROOT}"
  source "${REPO_ROOT}/lib/validate-input.sh"
}

teardown() {
  teardown_stub_path
  unset GITHUB_REPOSITORY ISSUE_NUMBER GITHUB_TOKEN ANTHROPIC_API_KEY CODER_ASSIGNEE CODER_LABEL
}

@test "validate_coder_input fails on missing ISSUE_NUMBER" {
  export GITHUB_REPOSITORY="my-org/my-repo"
  export GITHUB_TOKEN="test-token"
  export ANTHROPIC_API_KEY="test-key"

  run validate_coder_input
  [ "$status" -eq 1 ]
  [[ "$output" == *"ISSUE_NUMBER"* ]]
}

@test "validate_coder_input fails on malformed GITHUB_REPOSITORY" {
  export GITHUB_REPOSITORY="not-a-repo"
  export ISSUE_NUMBER="5"
  export GITHUB_TOKEN="test-token"
  export ANTHROPIC_API_KEY="test-key"

  run validate_coder_input
  [ "$status" -eq 1 ]
  [[ "$output" == *"GITHUB_REPOSITORY"* ]]
}

@test "validate_coder_input fails on missing tokens" {
  export GITHUB_REPOSITORY="my-org/my-repo"
  export ISSUE_NUMBER="5"

  run validate_coder_input
  [ "$status" -eq 1 ]
  [[ "$output" == *"GITHUB_TOKEN"* ]]
  [[ "$output" == *"ANTHROPIC_API_KEY"* ]]
}

@test "validate_coder_input defaults CODER_ASSIGNEE and CODER_LABEL when unset" {
  export GITHUB_REPOSITORY="my-org/my-repo"
  export ISSUE_NUMBER="5"
  export GITHUB_TOKEN="test-token"
  export ANTHROPIC_API_KEY="test-key"
  unset CODER_ASSIGNEE CODER_LABEL

  validate_coder_input
  [ "${CODER_ASSIGNEE}" = "jtuzhanskyi" ]
  [ "${CODER_LABEL}" = "agent-coded" ]
}

@test "validate_coder_input preserves explicit CODER_ASSIGNEE and CODER_LABEL" {
  export GITHUB_REPOSITORY="my-org/my-repo"
  export ISSUE_NUMBER="5"
  export GITHUB_TOKEN="test-token"
  export ANTHROPIC_API_KEY="test-key"
  export CODER_ASSIGNEE="someone-else"
  export CODER_LABEL="custom-label"

  validate_coder_input
  [ "${CODER_ASSIGNEE}" = "someone-else" ]
  [ "${CODER_LABEL}" = "custom-label" ]
}
