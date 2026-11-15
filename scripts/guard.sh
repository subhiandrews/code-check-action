#!/usr/bin/env bash
# Decide whether to review. Writes skip, reason, pr and head_sha to $GITHUB_OUTPUT.
# Everything from the event payload is read with jq and never interpolated into shell code.
set -euo pipefail

skip() {
  echo "skip=true" >>"$GITHUB_OUTPUT"
  echo "::notice title=code-check skipped::$1"
  exit 0
}

[[ "$EVENT_NAME" == "pull_request" ]] || skip "only pull_request events are supported (got $EVENT_NAME)"
[[ "$HAVE_KEY" == "true" ]] || skip "no anthropic-api-key or claude-code-oauth-token, or github-token is empty (fork PRs and Dependabot get no secrets)"

pr=$(jq -r '.pull_request.number' "$EVENT_PATH")
draft=$(jq -r '.pull_request.draft' "$EVENT_PATH")
head_repo=$(jq -r '.pull_request.head.repo.full_name // ""' "$EVENT_PATH")
head_sha=$(jq -r '.pull_request.head.sha' "$EVENT_PATH")

[[ "$pr" =~ ^[0-9]+$ ]] || skip "no pull request number in the event"
[[ "$draft" != "true" ]] || skip "draft PR"
[[ "$head_repo" == "$REPO" ]] || skip "PR comes from a fork ($head_repo)"

{
  echo "skip=false"
  echo "pr=$pr"
  echo "head_sha=$head_sha"
} >>"$GITHUB_OUTPUT"
