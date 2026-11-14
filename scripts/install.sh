#!/usr/bin/env bash
# Install the code-check CLI and plugin from one pinned clone, plus the claude CLI.
set -euo pipefail

src="${RUNNER_TEMP}/code-check-src"
git clone --quiet --depth 1 --branch "$CODE_CHECK_REF" https://github.com/subhiandrews/codecheck.git "$src" ||
  { # a commit SHA cannot be passed to --branch
    git clone --quiet https://github.com/subhiandrews/codecheck.git "$src"
    git -C "$src" checkout --quiet "$CODE_CHECK_REF"
  }
echo "code-check at $(git -C "$src" rev-parse --short HEAD)"

python -m pip install --quiet "$src"
npm install --global --silent @anthropic-ai/claude-code

# The headless process is only told to use the code-check:review-pr skill, so the plugin must be installed for it.
(cd "$src" && node installer/cli.js install)

code-check doctor || echo "::warning::code-check doctor reported a problem; see the log above"
