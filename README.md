# code-check-action

Run the [code-check](https://github.com/subhiandrews/codecheck) reviewer panel on every pull request in GitHub Actions. It posts one inline review (Critical, Warning, Suggestion) when a PR is opened, updated or marked ready.

Your code and keys stay on your own runners. There is no hosted service.

## Setup

1. Add repository secrets:
   - `ANTHROPIC_API_KEY`: your Anthropic key.
   - `CODE_CHECK_GH_TOKEN`: a fine-grained personal access token (Pull requests: read/write, Contents: read, Metadata: read) of the account that should post the reviews.
2. Copy [`examples/review.yml`](examples/review.yml) to `.github/workflows/code-check.yml`.

### Why a personal access token and not `GITHUB_TOKEN`

code-check identifies itself with `gh api user` and refuses to review the PRs of the account it runs as. An installation token (`GITHUB_TOKEN`, a GitHub App token) cannot call `/user`, so those fail. Use a PAT, and use an account that is **not** the PR author: to review your own PRs, create a separate reviewer account and use its token. Supporting `github-actions[bot]` needs a small identity override in code-check itself (not done yet).

## Behaviour

| PR | Result |
| --- | --- |
| Same-repo PR, not a draft | reviewed |
| Draft | skipped (code-check never posts on drafts) |
| From a fork | skipped: `pull_request` gives forks no secrets, and `pull_request_target` would hand secrets to a job that reads untrusted code. Not supported. |
| Dependabot or missing secrets | skipped with a notice |

The action never checks out PR code itself. code-check works in its own clone and worktree. Set `permissions: contents: read` on the job, as in the example. Pin the action to a commit SHA if you need to.

A review failure is a warning, not a red check, unless you set `fail-on-error: "true"`.

## Inputs

| Input | Default | |
| --- | --- | --- |
| `anthropic-api-key` | required | |
| `github-token` | required | PAT, see above |
| `code-check-ref` | `v0.1.4` | tag or commit of code-check to install |
| `security` | `false` | also run the security reviewer |
| `timeout-seconds` | `1800` | bound on one review run |
| `fail-on-error` | `false` | |
| `telemetry` | `false` | see below |
| `telemetry-repo`, `telemetry-token` | | required when `telemetry` is on |

Outputs: `skipped`, `ok`.

## Telemetry (to improve code-check)

Off by default. With `telemetry: "true"` the run sets `CODE_CHECK_SHADOW__HANDOFF=1`, and a final step pushes the hand-off folder to a **private** repo you name:

```
runs/<owner>__<repo>/pr-<n>/<workflow run>-<attempt>/
  <run_id>.handoff/handoff.json   findings per reviewer, aggregator drops, decision, signals, human comparison
  <run_id>.handoff/...            raw reviewer and aggregator outputs, scrubbed transcripts
  action-meta.json                action ref, code-check ref, head SHA, review ok
```

- The push is skipped, with a warning, if the repo is not private. It never fails the job.
- The folders hold code, PR text and transcripts. The secret scrub is pattern-based and best effort.
- Telemetry turns on **blind mode**: reviewers do not see existing PR comments, so their findings can be compared with what humans said. Posted reviews may repeat a human's point.
- Set up the data repo from [`templates/telemetry-repo`](templates/telemetry-repo): its nightly `collect` workflow runs `code-check shadow collect --all` (what humans did with each comment) and `export-golden`.

Data you send is yours: nothing is sent to the action's author.

## Status

Written but not yet run end to end. Unverified: the `install` step (`node installer/cli.js install` on a runner), `claude -p` behaviour with `--add-dir` on a fresh runner, and the flattening of `runs/` in `collect.yml` against what `shadow collect` expects. Run it on a test PR first. License: not chosen yet; add one before publishing.
