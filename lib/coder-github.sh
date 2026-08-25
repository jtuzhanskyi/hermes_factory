#!/usr/bin/env bash
# gh-backed functions for the coder agent: fetch the target issue, clone the
# repo fresh at main's tip, and verify a PR's assignee/label post-hoc.
# Failure signals: "issue not accessible" -> caller exits EXIT_ISSUE_INACCESSIBLE (20)
#                  "clone failed" -> caller exits EXIT_CLONE_FAILED (21)
#                  "postcondition failed" -> caller exits EXIT_POSTCONDITION_FAILED (40)

fetch_issue() {
  local repository="$1"
  local issue_number="$2"

  local json
  if ! json="$(gh issue view "${issue_number}" --repo "${repository}" --json title,body,url 2>&1)"; then
    echo "Unable to access issue #${issue_number} on ${repository} (not found, closed/inaccessible, or auth failure)" >&2
    return 1
  fi

  echo "${json}"
  return 0
}

clone_repo_at_main() {
  local repository="$1"

  local workspace
  workspace="$(mktemp -d)"

  if ! gh repo clone "${repository}" "${workspace}" -- --branch main >/dev/null 2>&1; then
    echo "Failed to clone ${repository} at main" >&2
    return 1
  fi

  local base_sha
  base_sha="$(git -C "${workspace}" rev-parse HEAD)"

  echo "${workspace} ${base_sha}"
  return 0
}

verify_pr_postconditions() {
  local repository="$1"
  local pr_number="$2"
  local expected_assignee="${3:-jtuzhanskyi}"
  local expected_label="${4:-agent-coded}"

  local json
  if ! json="$(gh pr view "${pr_number}" --repo "${repository}" --json assignees,labels 2>&1)"; then
    echo "Unable to read PR #${pr_number} on ${repository} to verify assignee/label" >&2
    return 1
  fi

  local missing=()

  if ! echo "${json}" | jq -e --arg a "${expected_assignee}" '.assignees | map(.login) | index($a) != null' >/dev/null 2>&1; then
    missing+=("assignee '${expected_assignee}'")
  fi

  if ! echo "${json}" | jq -e --arg l "${expected_label}" '.labels | map(.name) | index($l) != null' >/dev/null 2>&1; then
    missing+=("label '${expected_label}'")
  fi

  if (( ${#missing[@]} > 0 )); then
    echo "PR #${pr_number} on ${repository} is missing: ${missing[*]}" >&2
    return 1
  fi

  return 0
}
