# GitHub Actions Standards

This document defines lightweight conventions for GitHub Actions workflows in this repository (files under `.github/workflows/*.yml`).

The goal is consistent, readable workflows without pulling in heavy ecosystem tooling. Prefer repository-native targets (`make quality`, `make test-all`) over re-implementing logic in YAML.

## YAML Style

- Indentation: 2 spaces.
- Prefer <= 160 characters per line (URLs and long digests are common).
- Do not require `---` document markers.
- GitHub Actions requires the `on:` key; `.yamllint.yml` is configured so this is treated as valid.

## Linting

Before opening a PR that touches workflows, run:

- `make lint-workflows`

Notes:
- `yamllint` and `actionlint` are optional locally (the Makefile will skip if missing).
- CI runs `actionlint` as part of workflow validation, so installing it locally is recommended if you edit workflows.

## Shell / Script Hygiene

- Prefer multi-line scripts (`run: |`) for readability.
- For multi-line bash scripts, prefer `set -euo pipefail`.
- Quote special GitHub Action paths to satisfy shellcheck:
  - `echo "..." >> "$GITHUB_ENV"`
  - `echo "..." >> "$GITHUB_OUTPUT"`
  - `echo "..." >> "$GITHUB_PATH"`

## Structure Guidelines

Recommended top-level order (not a hard requirement):

1. `name`
2. `on`
3. `permissions` (when needed)
4. `env` (rare)
5. `jobs`

## Runners and Containers

- `runs-on: ubuntu-latest` is acceptable for most workflows.
- Pinning to a specific runner image (e.g. `ubuntu-24.04`) is encouraged only when reproducibility requires it.
- If you use containers, document why (e.g., glibc vs musl requirements).
