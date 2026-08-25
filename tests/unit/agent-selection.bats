#!/usr/bin/env bats

load '../test_helper'

setup() {
  setup_stub_path
  export REPO_ROOT="${REPO_ROOT}"
  source "${REPO_ROOT}/lib/validate-input.sh"
  export AGENTS_ROOT="${REPO_ROOT}/tests/fixtures/agents"
}

teardown() {
  teardown_stub_path
  unset AGENT_NAME AGENTS_ROOT
}

@test "resolve_agent_name selects a fixture agent directory via AGENTS_ROOT override" {
  export AGENT_NAME="sample-agent"
  run resolve_agent_name
  [ "$status" -eq 0 ]
  [ "$output" = "${REPO_ROOT}/tests/fixtures/agents/sample-agent" ]
}

@test "resolve_agent_name exits non-zero with a clear message for an unknown AGENT_NAME" {
  export AGENT_NAME="does-not-exist"
  run resolve_agent_name
  [ "$status" -eq 1 ]
  [[ "$output" == *"does-not-exist"* ]]
}
