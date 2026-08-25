#!/usr/bin/env bash
# Validates the Review Target (contracts/container-input.md, data-model.md).
# On failure, prints a specific stderr message and the caller must exit with
# EXIT_INVALID_INPUT (10).

AGENTS_ROOT="${AGENTS_ROOT:-${REPO_ROOT:-.}/agents}"

validate_input() {
  local missing=()

  [[ -z "${GITHUB_REPOSITORY:-}" ]] && missing+=("GITHUB_REPOSITORY")
  [[ -z "${PR_NUMBER:-}" ]] && missing+=("PR_NUMBER")
  [[ -z "${GITHUB_TOKEN:-}" ]] && missing+=("GITHUB_TOKEN")
  [[ -z "${ANTHROPIC_API_KEY:-}" ]] && missing+=("ANTHROPIC_API_KEY")

  if (( ${#missing[@]} > 0 )); then
    echo "Missing required input: ${missing[*]}" >&2
    return 1
  fi

  if ! [[ "${GITHUB_REPOSITORY}" =~ ^[[:alnum:]._-]+/[[:alnum:]._-]+$ ]]; then
    echo "Malformed input: GITHUB_REPOSITORY must match owner/repo, got '${GITHUB_REPOSITORY}'" >&2
    return 1
  fi

  if ! [[ "${PR_NUMBER}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Malformed input: PR_NUMBER must be a positive integer, got '${PR_NUMBER}'" >&2
    return 1
  fi

  return 0
}

resolve_agent_name() {
  local agent_name="${AGENT_NAME:-code-review}"
  local agent_dir="${AGENTS_ROOT}/${agent_name}"

  if [[ ! -d "${agent_dir}" ]]; then
    echo "Unknown agent: '${agent_name}' (no such directory: ${agent_dir})" >&2
    return 1
  fi

  echo "${agent_dir}"
  return 0
}
