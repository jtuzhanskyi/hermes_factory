#!/usr/bin/env bash
# gh-backed functions to fetch PR diff/metadata and post a comment.
# Failure signals: "PR not accessible" -> caller exits EXIT_PR_INACCESSIBLE (20)
#                  "comment post failed" -> caller exits EXIT_COMMENT_POST_FAILED (40)

fetch_pr_diff() {
  local repository="$1"
  local pr_number="$2"

  if ! gh pr view "${pr_number}" --repo "${repository}" >/dev/null 2>&1; then
    echo "Unable to access PR #${pr_number} on ${repository} (not found, closed/inaccessible, or auth failure)" >&2
    return 1
  fi

  gh pr diff "${pr_number}" --repo "${repository}"
}

fetch_pr_metadata() {
  local repository="$1"
  local pr_number="$2"

  gh pr view "${pr_number}" --repo "${repository}" --json title,number,url
}

post_pr_comment() {
  local repository="$1"
  local pr_number="$2"
  local body="$3"

  if ! gh pr comment "${pr_number}" --repo "${repository}" --body "${body}" >/dev/null 2>&1; then
    echo "Failed to post comment on PR #${pr_number} on ${repository}" >&2
    return 1
  fi

  return 0
}
