#!/usr/bin/env bash
# Run one headless review of the PR. Never checks out PR code: code-check works in its own clone and worktree.
set -euo pipefail

if [[ "$TELEMETRY" == "true" ]]; then
  export CODE_CHECK_SHADOW__HANDOFF=1
fi

args=(run-pr --mode review --pr "${REPO}#${PR}")
[[ "$SECURITY" == "true" ]] && args+=(--security)

result="${RUNNER_TEMP}/review-result.json"
set +e
code-check "${args[@]}" >"$result"
status=$?
set -e
cat "$result"

ok=$(jq -r '.ok // false' "$result" 2>/dev/null || echo false)
echo "ok=$ok" >>"$GITHUB_OUTPUT"

if [[ "$ok" == "true" && $status -eq 0 ]]; then
  jq -r '"code-check: \(.summary) (cost $\(.cost_usd // "n/a"), \(.duration_s)s)"' "$result" >>"$GITHUB_STEP_SUMMARY"
  exit 0
fi

msg="code-check review failed (exit $status): $(jq -r '.summary // "no output"' "$result" 2>/dev/null | head -c 300)"
if [[ "$FAIL_ON_ERROR" == "true" ]]; then
  echo "::error::$msg"
  exit 1
fi
echo "::warning::$msg"
