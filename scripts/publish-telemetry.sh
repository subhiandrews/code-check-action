#!/usr/bin/env bash
# Push the run's hand-off folders to a private telemetry repo. Best-effort: never fails the job.
# The data holds code, PR text and transcripts; the scrub is best-effort, so the repo must be private.
set -uo pipefail

warn() { echo "::warning title=telemetry::$1"; exit 0; }

[[ -n "$TELEMETRY_REPO" && -n "$TELEMETRY_TOKEN" ]] || warn "telemetry-repo and telemetry-token are required"
[[ -d "$SHADOW_DIR" ]] && compgen -G "$SHADOW_DIR/*" >/dev/null || warn "no shadow data was recorded"

export GH_TOKEN="$TELEMETRY_TOKEN"
visibility=$(gh repo view "$TELEMETRY_REPO" --json isPrivate --jq '.isPrivate' 2>/dev/null) || warn "cannot read $TELEMETRY_REPO"
[[ "$visibility" == "true" ]] || warn "$TELEMETRY_REPO is not private; refusing to push"

work="${RUNNER_TEMP}/telemetry"
rm -rf "$work"
git clone --quiet --depth 1 "https://x-access-token:${TELEMETRY_TOKEN}@github.com/${TELEMETRY_REPO}.git" "$work" ||
  warn "cannot clone $TELEMETRY_REPO"

dest="$work/runs/${REPO//\//__}/pr-${PR}/${RUN_ID}-${RUN_ATTEMPT}"
mkdir -p "$dest"
cp -R "$SHADOW_DIR"/. "$dest"/

# Build identity next to the data, so findings can be compared across versions.
jq -n \
  --arg repo "$REPO" --arg pr "$PR" --arg head "$HEAD_SHA" --arg run "$RUN_ID" --arg attempt "$RUN_ATTEMPT" \
  --arg action_ref "$ACTION_REF" --arg code_check_ref "$CODE_CHECK_REF" --arg ok "${REVIEW_OK:-}" \
  '{repo:$repo, pr:($pr|tonumber), head_sha:$head, workflow_run:$run, attempt:($attempt|tonumber),
    action_ref:$action_ref, code_check_ref:$code_check_ref, review_ok:($ok == "true")}' >"$dest/action-meta.json"

cd "$work" || warn "cannot enter clone"
git config user.name "code-check-action"
git config user.email "code-check-action@users.noreply.github.com"
git add -A
git commit --quiet -m "telemetry: ${REPO}#${PR} run ${RUN_ID}" || warn "nothing to commit"

for attempt in 1 2 3; do
  git push --quiet origin HEAD && exit 0
  git pull --quiet --rebase origin HEAD || break
done
warn "push to $TELEMETRY_REPO failed"
