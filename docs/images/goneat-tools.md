# goneat-tools Image

Purpose: containerized code quality/formatting/linting toolkit for CI and local runs.

## Versions (Pinned)
- Base: `node:22-alpine@sha256:9632533eda8061fc1e9960cfb3f8762781c07a00ee7317f5dc0e13c05e15166f`
- Builder: `golang:1.24-alpine@sha256:06545cc1ff10ddf04aebe20db1352ec7c96d1e43135767931c473557d0378202`
- Prettier: `3.7.4` (npm global)
- Biome: `2.3.8` (npm global)
- yamlfmt: `v0.20.0` (Go install)
- shfmt: `v3.12.0` (Go install) - shell formatter (BSD-3)
- checkmake: `0.2.2` (Go install) - Makefile linter (MIT)
- actionlint: `v1.7.9` (Go install) - GitHub Actions linter (MIT)
- jq: `1.8.1-r0` (apk)
- yq-go: `4.49.2-r1` (apk)
- ripgrep: `15.1.0-r0` (apk)
- taplo: `0.10.0-r0` (apk)
- bash: `5.3.3-r1` (apk)
- git: `2.52.0-r0` (apk)
- curl: `8.17.0-r1` (apk)
- minisign: `0.12-r0` (apk)

See `manifests/tools.json` for SSOT and `make validate-manifest` for schema validation.

## Pinning Strategy
- All tool versions and base images pinned explicitly (Dockerfile ARGs).
- Bumps are curated; bump manifest + Dockerfile together, update CHANGELOG/RELEASE_NOTES.
- Tagging: semver from `VERSION`; `:latest` and `:v<major>` track the newest for that line.

## Usage Notes
- CI can pull by digest for reproducibility.
- yamlfmt required locally for workflow linting (`make lint-workflows` / `make quality`).
- Docker daemon required for builds/tests and manifest validation (uses Dockerized ajv).

## Excluded Tools (GPL)
The following tools are intentionally excluded due to GPL licensing:
- **shellcheck** (GPL-3): Use sidecar pattern or install separately in CI
- **yamllint** (GPL): Use sidecar pattern or install separately in CI

These tools can be used alongside goneat-tools via sidecar containers or pre-installed in CI runners.

## GitHub Actions Runner Permissions

### The Problem

This image runs as a non-root user for security. However, GitHub Actions mounts workspace directories (`/__w`) owned by UID 1001 on `ubuntu-latest` runners. This mismatch causes permission errors:

```
EACCES: permission denied, open '/__w/_temp/_runner_file_commands/save_state_...'
```

### Solution

Always specify `--user 1001` when using this image in GitHub Actions:

```yaml
jobs:
  quality:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/fulmenhq/goneat-tools:latest
      options: --user 1001  # Match GHA runner mount ownership
    steps:
      - uses: actions/checkout@v4
      - run: prettier --check "**/*.{md,json,yml,yaml}"
```

### Why UID 1001?

GitHub-hosted `ubuntu-latest` runners create workspace mounts owned by UID 1001. Using `--user 1001` ensures the container process can write to:
- `/__w/_temp/_runner_file_commands/` (runner state)
- `/__w/<repo>/` (checkout directory)

### Fallback (root)

If UID 1001 doesn't work (e.g., self-hosted runners with different ownership):

```yaml
container:
  image: ghcr.io/fulmenhq/goneat-tools:latest
  options: --user root  # Works but loses non-root security
```

### Diagnostics

Add this step to debug permission issues:

```yaml
- name: Check container permissions
  run: |
    echo "=== Container identity ==="
    id
    echo "=== Runner-mounted directories ==="
    ls -ld /__w /__w/_temp /__w/_temp/_runner_file_commands || true
```
