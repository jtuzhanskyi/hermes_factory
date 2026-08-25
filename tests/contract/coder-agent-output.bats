#!/usr/bin/env bats

load '../test_helper'

setup() {
  setup_stub_path
  source "${REPO_ROOT}/lib/run-coder-agent.sh"
}

teardown() {
  teardown_stub_path
}

@test "extract_coder_outcome_json accepts a pr_opened outcome with all required fields" {
  local raw='{"status":"pr_opened","branch":"coder-agent/issue-5","pr_number":42,"pr_url":"https://github.com/o/r/pull/42","summary":"Updates the title."}'
  run extract_coder_outcome_json "${raw}"
  [ "$status" -eq 0 ]
  echo "${output}" | jq -e '.status == "pr_opened"'
  echo "${output}" | jq -e '.branch == "coder-agent/issue-5"'
  echo "${output}" | jq -e '.pr_number == 42'
}

@test "extract_coder_outcome_json accepts a declined outcome with a reason" {
  local raw='{"status":"declined","reason":"Issue is ambiguous."}'
  run extract_coder_outcome_json "${raw}"
  [ "$status" -eq 0 ]
  echo "${output}" | jq -e '.status == "declined"'
  echo "${output}" | jq -e '.reason == "Issue is ambiguous."'
}

@test "extract_coder_outcome_json accepts a no_op outcome with a reason" {
  local raw='{"status":"no_op","reason":"Content already matches."}'
  run extract_coder_outcome_json "${raw}"
  [ "$status" -eq 0 ]
  echo "${output}" | jq -e '.status == "no_op"'
}

@test "extract_coder_outcome_json picks the last valid JSON line when there is prose around it" {
  local raw='thinking about this...
{"status":"no_op","reason":"already matches"}
done'
  run extract_coder_outcome_json "${raw}"
  [ "$status" -eq 0 ]
  echo "${output}" | jq -e '.status == "no_op"'
}

@test "extract_coder_outcome_json rejects malformed JSON" {
  local raw='not json at all'
  run extract_coder_outcome_json "${raw}"
  [ "$status" -eq 0 ]
  [ -z "${output}" ]
}

@test "extract_coder_outcome_json rejects JSON with an unrecognized status" {
  local raw='{"status":"something_else"}'
  run extract_coder_outcome_json "${raw}"
  [ "$status" -eq 0 ]
  [ -z "${output}" ]
}

@test "extract_coder_outcome_json rejects an object missing the status field entirely" {
  local raw='{"reason":"no status here"}'
  run extract_coder_outcome_json "${raw}"
  [ "$status" -eq 0 ]
  [ -z "${output}" ]
}
