#!/usr/bin/env bash
# Invokes `claude -p` with the selected agent's directory as the working
# directory and a task prompt containing the PR diff/metadata. Enforces a
# run timeout; the caller exits EXIT_REVIEW_FAILED (30) on timeout or crash.
#
# Emits a structured Review Outcome (JSON: {"verdict": ..., "findings": [...]})
# to stdout on success.

RUN_AGENT_TIMEOUT_SECONDS="${RUN_AGENT_TIMEOUT_SECONDS:-300}"

run_agent() {
  local agent_dir="$1"
  local repository="$2"
  local pr_number="$3"
  local diff="$4"

  local prompt
  prompt="$(build_review_prompt "${repository}" "${pr_number}" "${diff}")"

  local output
  local rc

  output="$(cd "${agent_dir}" && timeout "${RUN_AGENT_TIMEOUT_SECONDS}" claude -p "${prompt}" 2>&1)"
  rc=$?

  if (( rc != 0 )); then
    echo "Agent run failed (exit ${rc}): ${output}" >&2
    return 1
  fi

  local outcome_json
  outcome_json="$(extract_outcome_json "${output}")"

  if [[ -z "${outcome_json}" ]] || ! echo "${outcome_json}" | jq -e '.verdict == "pass" or .verdict == "issues_found"' >/dev/null 2>&1; then
    echo "Agent produced an unrecognized outcome: ${output}" >&2
    return 1
  fi

  echo "${outcome_json}"
  return 0
}

# The agent's raw stdout may include prose/reasoning before or after its
# final JSON answer despite the prompt asking for JSON only. Pull out the
# last line that parses as a JSON object with a "verdict" field.
extract_outcome_json() {
  local raw="$1"
  local line

  while IFS= read -r line; do
    if echo "${line}" | jq -e '.verdict == "pass" or .verdict == "issues_found"' >/dev/null 2>&1; then
      echo "${line}"
    fi
  done <<< "${raw}" | tail -n1
}

build_review_prompt() {
  local repository="$1"
  local pr_number="$2"
  local diff="$3"

  cat <<EOF
Review pull request #${pr_number} on ${repository}.

Use \`gh\` to examine the PR's changes if you need more context beyond the
diff below. Apply your review skills and produce a verdict.

Respond with exactly one JSON object on stdout, with this shape and no other
text:
{"verdict": "pass" | "issues_found", "findings": [{"summary": "...", "location": "...", "severity": "..."}]}

"findings" must be empty when verdict is "pass".

--- PR diff ---
${diff}
EOF
}
