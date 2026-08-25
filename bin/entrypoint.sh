#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Exit code constants (contracts/exit-codes.md)
readonly EXIT_OK=0
readonly EXIT_INVALID_INPUT=10
readonly EXIT_PR_INACCESSIBLE=20
readonly EXIT_REVIEW_FAILED=30
readonly EXIT_COMMENT_POST_FAILED=40

# shellcheck source=lib/validate-input.sh
source "${REPO_ROOT}/lib/validate-input.sh"
# shellcheck source=lib/github.sh
source "${REPO_ROOT}/lib/github.sh"
# shellcheck source=lib/run-agent.sh
source "${REPO_ROOT}/lib/run-agent.sh"
# shellcheck source=lib/comment-format.sh
source "${REPO_ROOT}/lib/comment-format.sh"

main() {
  if ! validate_input; then
    exit "${EXIT_INVALID_INPUT}"
  fi

  local agent_dir
  if ! agent_dir="$(resolve_agent_name)"; then
    exit "${EXIT_INVALID_INPUT}"
  fi
  local agent_name="${AGENT_NAME:-code-review}"

  local diff
  if ! diff="$(fetch_pr_diff "${GITHUB_REPOSITORY}" "${PR_NUMBER}")"; then
    exit "${EXIT_PR_INACCESSIBLE}"
  fi

  local outcome_json
  if ! outcome_json="$(run_agent "${agent_dir}" "${GITHUB_REPOSITORY}" "${PR_NUMBER}" "${diff}")"; then
    exit "${EXIT_REVIEW_FAILED}"
  fi

  local verdict findings_json generated_at comment_body
  verdict="$(echo "${outcome_json}" | jq -r '.verdict')"
  findings_json="$(echo "${outcome_json}" | jq -c '.findings // []')"
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  comment_body="$(render_comment "${agent_name}" "${verdict}" "${generated_at}" "${findings_json}")"

  if ! post_pr_comment "${GITHUB_REPOSITORY}" "${PR_NUMBER}" "${comment_body}"; then
    echo "${outcome_json}"
    exit "${EXIT_COMMENT_POST_FAILED}"
  fi

  exit "${EXIT_OK}"
}

main "$@"
