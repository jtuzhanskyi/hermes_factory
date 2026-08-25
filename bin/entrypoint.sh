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

# Exit code constants (specs/002-coder-agent/contracts/exit-codes.md)
# Distinct table, only meaningful when AGENT_NAME=coder-agent — see
# specs/002-coder-agent/research.md §4 for why these are not shared with
# the review-agent codes above despite some numeric overlap.
readonly EXIT_ISSUE_INACCESSIBLE=20
readonly EXIT_CLONE_FAILED=21
readonly EXIT_AGENT_FAILED=30
readonly EXIT_DECLINED=31
readonly EXIT_NO_OP=32
readonly EXIT_POSTCONDITION_FAILED=40

# shellcheck source=lib/validate-input.sh
source "${REPO_ROOT}/lib/validate-input.sh"
# shellcheck source=lib/github.sh
source "${REPO_ROOT}/lib/github.sh"
# shellcheck source=lib/run-agent.sh
source "${REPO_ROOT}/lib/run-agent.sh"
# shellcheck source=lib/comment-format.sh
source "${REPO_ROOT}/lib/comment-format.sh"
# shellcheck source=lib/coder-github.sh
source "${REPO_ROOT}/lib/coder-github.sh"
# shellcheck source=lib/run-coder-agent.sh
source "${REPO_ROOT}/lib/run-coder-agent.sh"

main_review() {
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

main_coder() {
  if ! validate_coder_input; then
    exit "${EXIT_INVALID_INPUT}"
  fi

  local agent_dir="${AGENTS_ROOT:-${REPO_ROOT}/agents}/coder-agent"

  local issue_json
  if ! issue_json="$(fetch_issue "${GITHUB_REPOSITORY}" "${ISSUE_NUMBER}")"; then
    exit "${EXIT_ISSUE_INACCESSIBLE}"
  fi

  local clone_result workspace
  if ! clone_result="$(clone_repo_at_main "${GITHUB_REPOSITORY}")"; then
    exit "${EXIT_CLONE_FAILED}"
  fi
  workspace="$(echo "${clone_result}" | awk '{print $1}')"

  local outcome_json
  if ! outcome_json="$(run_coder_agent "${agent_dir}" "${GITHUB_REPOSITORY}" "${ISSUE_NUMBER}" "${issue_json}" "${workspace}")"; then
    exit "${EXIT_AGENT_FAILED}"
  fi

  local status
  status="$(echo "${outcome_json}" | jq -r '.status')"

  case "${status}" in
    declined)
      echo "${outcome_json}" | jq -r '.reason' >&2
      exit "${EXIT_DECLINED}"
      ;;
    no_op)
      echo "${outcome_json}" | jq -r '.reason' >&2
      exit "${EXIT_NO_OP}"
      ;;
    pr_opened)
      local pr_number
      pr_number="$(echo "${outcome_json}" | jq -r '.pr_number')"
      if ! verify_pr_postconditions "${GITHUB_REPOSITORY}" "${pr_number}" "${CODER_ASSIGNEE}" "${CODER_LABEL}"; then
        echo "${outcome_json}"
        exit "${EXIT_POSTCONDITION_FAILED}"
      fi
      echo "${outcome_json}"
      exit "${EXIT_OK}"
      ;;
  esac
}

main() {
  if [[ "${AGENT_NAME:-code-review}" == "coder-agent" ]]; then
    main_coder
  else
    main_review
  fi
}

main "$@"
