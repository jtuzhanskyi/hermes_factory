#!/usr/bin/env bats

load '../test_helper'

setup() {
  setup_stub_path
  source "${REPO_ROOT}/lib/comment-format.sh"
}

teardown() {
  teardown_stub_path
}

@test "pass verdict renders marker, heading, and no findings" {
  run render_comment "code-review" "pass" "2026-08-25T10:00:00Z" "[]"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "<!-- pr-review-agent:code-review -->" ]
  [[ "$output" == *"## 🤖 Automated Code Review — No blocking issues found"* ]]
  [[ "$output" == *"_Run at 2026-08-25T10:00:00Z_"* ]]
  [[ "$output" == *"no blocking issues were found"* ]]
}

@test "issues_found verdict renders each finding's summary and location" {
  local findings='[{"summary":"Missing test for new branch","location":"src/foo.js:42"},{"summary":"Unhandled error path","location":"src/bar.js:10","severity":"blocking"}]'

  run render_comment "code-review" "issues_found" "2026-08-25T10:00:00Z" "${findings}"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "<!-- pr-review-agent:code-review -->" ]
  [[ "$output" == *"## 🤖 Automated Code Review — Issues found"* ]]
  [[ "$output" == *"**Missing test for new branch**"* ]]
  [[ "$output" == *'`src/foo.js:42`'* ]]
  [[ "$output" == *"**Unhandled error path**"* ]]
  [[ "$output" == *'`src/bar.js:10`'* ]]
  [[ "$output" == *"Severity: blocking"* ]]
}
