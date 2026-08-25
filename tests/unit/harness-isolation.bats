#!/usr/bin/env bats

load '../test_helper'

@test "agents/code-review has no relative parent-directory references" {
  run bash -c "grep -rn '\\.\\./' '${REPO_ROOT}/agents/code-review' || true"
  [ -z "$output" ]
}

@test "agents/code-review has no references into another agent's directory" {
  run bash -c "grep -rn 'agents/' '${REPO_ROOT}/agents/code-review' | cut -d: -f3- | grep -v 'agents/code-review/' || true"
  [ -z "$output" ]
}

@test "agents/code-review has no absolute filesystem path references" {
  run bash -c "grep -rEn '(^|[^\`])/(Users|home|etc|app)/' '${REPO_ROOT}/agents/code-review' || true"
  [ -z "$output" ]
}

@test "agents/coder-agent has no relative parent-directory references" {
  run bash -c "grep -rn '\\.\\./' '${REPO_ROOT}/agents/coder-agent' || true"
  [ -z "$output" ]
}

@test "agents/coder-agent has no references into another agent's directory" {
  run bash -c "grep -rn 'agents/' '${REPO_ROOT}/agents/coder-agent' | cut -d: -f3- | grep -v 'agents/coder-agent/' || true"
  [ -z "$output" ]
}

@test "agents/coder-agent has no absolute filesystem path references" {
  run bash -c "grep -rEn '(^|[^\`])/(Users|home|etc|app)/' '${REPO_ROOT}/agents/coder-agent' || true"
  [ -z "$output" ]
}

@test "agents/code-review does not reference agents/coder-agent" {
  run bash -c "grep -rn 'coder-agent' '${REPO_ROOT}/agents/code-review' || true"
  [ -z "$output" ]
}
