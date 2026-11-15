# code-check-action

Run the [code-check](https://github.com/subhiandrews/codecheck) reviewer panel on every pull request in GitHub Actions. It posts one inline review (Critical, Warning, Suggestion) when a PR is opened, updated or marked ready.

Your code and keys stay on your own runners. There is no hosted service.

## Setup

1. Add one repository secret: `ANTHROPIC_API_KEY` (API credits), or `CLAUDE_CODE_OAUTH_TOKEN` (a Claude Pro/Max subscription; create it locally with `claude setup-token` and pass it as `claude-code-oauth-token`). Subscription limits are shared with your own Claude use, and automated use must stay within Anthropic's terms for your plan.
2. Copy [`examples/review.yml`](examples/review.yml) to `.github/workflows/code-check.yml`. It grants `pull-requests: write`, and reviews are posted as `github-actions[bot]`.

### Posting as an account instead

Pass `github-token: ${{ secrets.CODE_CHECK_GH_TOKEN }}`, a fine-grained personal access token (Pull requests: read/write, Contents: read, Metadata: read). code-check then posts as that account and skips PRs it authored, so to review your own PRs use the default bot or a separate reviewer account.

### Identity

code-check refuses to review the PRs of the identity it runs as and normally learns it with `gh api user`. An installation token (`GITHUB_TOKEN`, a GitHub App token) cannot call `/user`, so with the default token the action sets `CODE_CHECK_REVIEW__LOGIN=github-actions[bot]` (code-check 0.1.5 or later). Set `reviewer-login` to override it, for example for a GitHub App token.

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
| `anthropic-api-key` | | API key; this or `claude-code-oauth-token` is required |
| `claude-code-oauth-token` | | subscription token from `claude setup-token`; the key wins if both are set |
| `github-token` | `github.token` | token that posts the review; a PAT posts as its account |
| `reviewer-login` | | identity override; empty means `github-actions[bot]` with the default token |
| `code-check-ref` | `v0.1.5` | tag or commit of code-check to install |
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

The install path and the dry-run of the headless command pass on a clean runner (the `smoke` workflow). A full review has not yet been run end to end. Unverified: `claude -p` behaviour with `--add-dir` on a runner, and the flattening of `runs/` in `collect.yml` against what `shadow collect` expects. Run it on a test PR first.

## License

[Apache-2.0](LICENSE).
