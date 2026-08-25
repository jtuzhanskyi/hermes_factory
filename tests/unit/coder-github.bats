#!/usr/bin/env bats

load '../test_helper'

setup() {
  setup_stub_path
  source "${REPO_ROOT}/lib/coder-github.sh"
}

teardown() {
  teardown_stub_path
}

@test "fetch_issue returns JSON on success" {
  write_stub "gh" '
if [[ "$1" == "issue" && "$2" == "view" ]]; then
  echo "{\"title\":\"Fix title\",\"body\":\"Change the title\",\"url\":\"https://github.com/o/r/issues/5\"}"
  exit 0
fi
exit 1
'
  run fetch_issue "o/r" "5"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fix title"* ]]
}

@test "fetch_issue fails when issue is not found/inaccessible" {
  write_stub "gh" 'exit 1'
  run fetch_issue "o/r" "999999"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unable to access issue #999999"* ]]
}

@test "clone_repo_at_main returns workspace path and base sha on success" {
  write_stub "gh" '
if [[ "$1" == "repo" && "$2" == "clone" ]]; then
  target="$4"
  mkdir -p "${target}"
  git -C "${target}" init -q
  git -C "${target}" -c user.email=a@b.c -c user.name=t commit -q --allow-empty -m init
  exit 0
fi
exit 1
'
  run clone_repo_at_main "o/r"
  [ "$status" -eq 0 ]
  local workspace
  workspace="$(echo "$output" | awk '{print $1}')"
  [ -d "${workspace}" ]
  local sha
  sha="$(echo "$output" | awk '{print $2}')"
  [ -n "${sha}" ]
}

@test "clone_repo_at_main fails when gh repo clone fails" {
  write_stub "gh" 'exit 1'
  run clone_repo_at_main "o/r"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to clone"* ]]
}

@test "verify_pr_postconditions passes when assignee and label are present" {
  write_stub "gh" '
if [[ "$1" == "pr" && "$2" == "view" ]]; then
  echo "{\"assignees\":[{\"login\":\"jtuzhanskyi\"}],\"labels\":[{\"name\":\"agent-coded\"}]}"
  exit 0
fi
exit 1
'
  run verify_pr_postconditions "o/r" "42" "jtuzhanskyi" "agent-coded"
  [ "$status" -eq 0 ]
}

@test "verify_pr_postconditions fails when assignee is missing" {
  write_stub "gh" '
if [[ "$1" == "pr" && "$2" == "view" ]]; then
  echo "{\"assignees\":[],\"labels\":[{\"name\":\"agent-coded\"}]}"
  exit 0
fi
exit 1
'
  run verify_pr_postconditions "o/r" "42" "jtuzhanskyi" "agent-coded"
  [ "$status" -eq 1 ]
  [[ "$output" == *"assignee 'jtuzhanskyi'"* ]]
}

@test "verify_pr_postconditions fails when label is missing" {
  write_stub "gh" '
if [[ "$1" == "pr" && "$2" == "view" ]]; then
  echo "{\"assignees\":[{\"login\":\"jtuzhanskyi\"}],\"labels\":[]}"
  exit 0
fi
exit 1
'
  run verify_pr_postconditions "o/r" "42" "jtuzhanskyi" "agent-coded"
  [ "$status" -eq 1 ]
  [[ "$output" == *"label 'agent-coded'"* ]]
}
