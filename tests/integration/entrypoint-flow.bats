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

  write_stub "gh" '
case "$1 $2" in
  "pr view") exit 0 ;;
  "pr diff") echo "diff --git a/f b/f"; exit 0 ;;
  "pr comment")
    {
      echo "--- comment ---"
      echo "$*"
    } >> "'"${STUB_BIN}"'/gh-comments.log"
    exit 0
    ;;
  *) exit 0 ;;
esac
'
}

teardown() {
  teardown_stub_path
  unset GITHUB_REPOSITORY PR_NUMBER GITHUB_TOKEN ANTHROPIC_API_KEY AGENT_NAME AGENTS_ROOT
}

@test "happy path pass verdict: exit 0 and exactly one comment posted" {
  write_stub "claude" 'echo "{\"verdict\":\"pass\",\"findings\":[]}"; exit 0'

  run "${ENTRYPOINT}"

  [ "$status" -eq 0 ]
  [ -f "${STUB_BIN}/gh-comments.log" ]
  [ "$(grep -c -- '--- comment ---' "${STUB_BIN}/gh-comments.log")" -eq 1 ]
  grep -q "No blocking issues found" "${STUB_BIN}/gh-comments.log"
}

@test "issues-found verdict: posted comment lists each finding's summary and location" {
  write_stub "claude" 'echo "{\"verdict\":\"issues_found\",\"findings\":[{\"summary\":\"Missing test\",\"location\":\"src/foo.js:1\"}]}"; exit 0'

  run "${ENTRYPOINT}"

  [ "$status" -eq 0 ]
  grep -q "Missing test" "${STUB_BIN}/gh-comments.log"
  grep -q "src/foo.js:1" "${STUB_BIN}/gh-comments.log"
}

@test "re-run behavior: two separate runs post two separate comments" {
  write_stub "claude" 'echo "{\"verdict\":\"pass\",\"findings\":[]}"; exit 0'

  run "${ENTRYPOINT}"
  [ "$status" -eq 0 ]
  run "${ENTRYPOINT}"
  [ "$status" -eq 0 ]

  [ "$(grep -c -- '--- comment ---' "${STUB_BIN}/gh-comments.log")" -eq 2 ]
}
