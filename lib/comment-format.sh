#!/usr/bin/env bash
# Renders a Review Outcome (verdict, findings, run_marker, generated_at) into
# the markdown structure defined in contracts/review-comment-format.md.
#
# Findings are passed as a JSON array on stdin (or via $2), each element:
#   {"summary": "...", "location": "...", "severity": "..." (optional)}

render_comment() {
  local agent_name="$1"
  local verdict="$2"
  local generated_at="$3"
  local findings_json="${4:-[]}"

  local marker="<!-- pr-review-agent:${agent_name} -->"

  if [[ "${verdict}" == "pass" ]]; then
    cat <<EOF
${marker}
## 🤖 Automated Code Review — No blocking issues found

_Run at ${generated_at}_

This PR was reviewed automatically and no blocking issues were found.
EOF
    return 0
  fi

  if [[ "${verdict}" != "issues_found" ]]; then
    echo "render_comment: unknown verdict '${verdict}'" >&2
    return 1
  fi

  echo "${marker}"
  echo "## 🤖 Automated Code Review — Issues found"
  echo
  echo "_Run at ${generated_at}_"
  echo
  echo "The following issues were found:"
  echo

  local count
  count=$(echo "${findings_json}" | jq 'length')

  local i
  for (( i = 0; i < count; i++ )); do
    local summary location severity
    summary=$(echo "${findings_json}" | jq -r ".[$i].summary")
    location=$(echo "${findings_json}" | jq -r ".[$i].location")
    severity=$(echo "${findings_json}" | jq -r ".[$i].severity // empty")

    echo "$((i + 1)). **${summary}**"
    echo "   - Location: \`${location}\`"
    if [[ -n "${severity}" ]]; then
      echo "   - Severity: ${severity}"
    fi
    echo
  done
}
