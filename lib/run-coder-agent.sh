#!/usr/bin/env bash
# Invokes `claude -p` with agents/coder-agent/ as the working directory and a
# task prompt naming the cloned workspace's absolute path plus issue
# metadata. Enforces a run timeout; the caller exits EXIT_AGENT_FAILED (30)
# on timeout, crash, or unparseable output.
# Model defaults to Claude Haiku 4.5; override via RUN_AGENT_MODEL.
#
# Emits a structured Agent Outcome (JSON: {"status": ..., ...}) to stdout on
# success (contracts/agent-output.md).

RUN_AGENT_TIMEOUT_SECONDS="${RUN_AGENT_TIMEOUT_SECONDS:-300}"
RUN_AGENT_MODEL="${RUN_AGENT_MODEL:-claude-haiku-4-5-20251001}"

run_coder_agent() {
  local agent_dir="$1"
  local repository="$2"
  local issue_number="$3"
  local issue_json="$4"
  local workspace="$5"

  local prompt
  prompt="$(build_coder_prompt "${repository}" "${issue_number}" "${issue_json}" "${workspace}")"

  local output
  local rc

  output="$(cd "${agent_dir}" && timeout "${RUN_AGENT_TIMEOUT_SECONDS}" claude -p --model "${RUN_AGENT_MODEL}" --add-dir "${workspace}" --allowedTools "Bash,Edit,Write,Read,Glob,Grep" -- "${prompt}" 2>&1)"
  rc=$?

  if (( rc != 0 )); then
    echo "Agent run failed (exit ${rc}): ${output}" >&2
    return 1
  fi

  local outcome_json
  outcome_json="$(extract_coder_outcome_json "${output}")"

  if [[ -z "${outcome_json}" ]]; then
    echo "Agent produced an unrecognized outcome: ${output}" >&2
    return 1
  fi

  echo "${outcome_json}"
  return 0
}

# The agent's raw stdout may include prose/reasoning before or after its
# final JSON answer despite the prompt asking for JSON only. Pull out the
# last line that parses as a JSON object with a recognized "status" field.
extract_coder_outcome_json() {
  local raw="$1"
  local line

  while IFS= read -r line; do
    if echo "${line}" | jq -e '.status == "pr_opened" or .status == "declined" or .status == "no_op"' >/dev/null 2>&1; then
      echo "${line}"
    fi
  done <<< "${raw}" | tail -n1
}

build_coder_prompt() {
  local repository="$1"
  local issue_number="$2"
  local issue_json="$3"
  local workspace="$4"

  local title body url
  title="$(echo "${issue_json}" | jq -r '.title')"
  body="$(echo "${issue_json}" | jq -r '.body')"
  url="$(echo "${issue_json}" | jq -r '.url')"

  cat <<EOF
Address issue #${issue_number} on ${repository}.

Issue title: ${title}
Issue URL: ${url}
Issue body:
${body}

The repository has already been cloned fresh from main's current tip at
this absolute path: ${workspace}

cd into that path for all git/gh/file-editing operations. Apply your
skills and produce exactly one outcome.

Respond with exactly one JSON object on stdout, with this shape and no
other text:
{"status": "pr_opened" | "declined" | "no_op", "reason": "...", "branch": "...", "pr_number": 0, "pr_url": "...", "summary": "..."}

"reason" is required for "declined"/"no_op" and MUST be omitted for
"pr_opened". "branch", "pr_number", "pr_url", "summary" are required for
"pr_opened" and MUST be omitted otherwise.
EOF
}
