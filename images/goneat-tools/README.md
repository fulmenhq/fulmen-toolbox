# goneat-tools Docker Image

[![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/ghcr.io/fulmenhq/goneat-tools/latest)](https://ghcr.io/fulmenhq/goneat-tools)
[![Docker Pulls](https://img.shields.io/docker/pulls/ghcr.io/fulmenhq/goneat-tools)](https://ghcr.io/fulmenhq/goneat-tools)

Focused Docker image providing code quality and formatting tools for the FulmenHQ ecosystem.

## Licenses and Notices

This image bundles upstream license texts under `/licenses/` and upstream notice files (when present) under `/notices/` for transparency and compliance support.

## Included Tools

| Tool                                               | Purpose                           | Source     |
| -------------------------------------------------- | --------------------------------- | ---------- |
| Prettier (3.9.6)                                   | JSON, Markdown, YAML formatting   | npm        |
| Biome (2.3.11)                                     | JS/TS/JSON lint/format            | npm        |
| yamlfmt (v0.21.0)                                  | Dedicated YAML formatting/linting | Go binary  |
| shfmt (v3.13.1)                                    | Shell script formatting           | Go binary  |
| checkmake (v0.3.2)                                 | Makefile linting                  | Go binary  |
| actionlint (v1.7.12)                               | GitHub Actions workflow linting   | Go binary  |
| jq (1.8.1-r0)                                      | JSON processing/filtering         | Alpine pkg |
| yq-go (4.53.3-r0)                                  | YAML processing/filtering         | Alpine pkg |
| ripgrep (15.1.0-r0)                                | Fast text search/search & replace | Alpine pkg |
| taplo (0.10.0-r0)                                  | TOML formatting/linting           | Alpine pkg |
| bash (5.3.9-r1), git (2.54.0-r0), curl (8.21.0-r0) | Shell & Git utilities (runner)    | Alpine pkg |
| minisign (0.12-r2)                                 | File signing/verification         | Alpine pkg |

**Base Image:** `node:22-alpine@sha256:16e22a550f3863206a3f701448c45f7912c6896a62de43add43bb9c86130c3e2` (multi-arch digest pinned)

See `docs/images/goneat-tools.md` and `manifests/tools.json` for pinning details.

**Image Tags:**

- `ghcr.io/fulmenhq/goneat-tools-runner-musl:latest`
- `ghcr.io/fulmenhq/goneat-tools-slim-musl:v0.5.3` (semver tags)

## Usage

### GitHub Actions (Recommended)

```yaml
jobs:
  quality:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/fulmenhq/goneat-tools-runner-musl:latest
      options: --user 1001 # Match GHA runner mount ownership
    steps:
      - uses: actions/checkout@v4
      - run: prettier --check "**/*.{md,json,yml,yaml}"
      - run: biome check .
      - run: yamlfmt -lint .
      - run: taplo fmt --check
      - run: shfmt -d scripts/ # Check shell formatting
      - run: actionlint # Lint workflows
      - run: checkmake Makefile # Lint Makefile
```

#### Container Permissions (Important)

This image runs as a non-root user by default. GitHub Actions mounts workspace directories (`/__w`) owned by UID 1001. To avoid permission errors:

```yaml
container:
  image: ghcr.io/fulmenhq/goneat-tools-runner-musl:latest
  options: --user 1001 # Required for GHA runner mounts
```

**Symptoms without `--user 1001`:**

```
EACCES: permission denied, open '/__w/_temp/_runner_file_commands/save_state_...'
```

**Diagnostics step** (optional, for debugging):

```yaml
- name: Check container permissions
  run: |
    id
    ls -ld /__w /__w/_temp /__w/_temp/_runner_file_commands || true
```

### Local Docker Run

**Note**: Uses your **local configs** (.prettierrc.json, .yamlfmt.yaml, etc.) via volume mount – image provides tools only.

Mount your repo and run tools:

```bash
# Format files
docker run --rm -v "$(pwd):/work" -w /work \
  ghcr.io/fulmenhq/goneat-tools-runner-musl:latest \
  sh -c "prettier --write '**/*.{md,json,yml,yaml}' && yamlfmt -w ."

# Lint/check only
docker run --rm -v "$(pwd):/work" -w /work \
  ghcr.io/fulmenhq/goneat-tools-runner-musl:latest \
  sh -c "prettier --check '**/*.{md,json,yml,yaml}' && yamlfmt -lint ."

# Preserve user/group ownership
docker run --rm -v "$(pwd):/work" -w /work \
  --user $(id -u):$(id -g) \
  ghcr.io/fulmenhq/goneat-tools-runner-musl:latest \
  sh -c "prettier --write '**/*.{md,json,yml,yaml}'"
```

### Local Build & Test

```bash
make build-goneat-tools  # From repo root
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-runner-musl:local sh -c "prettier --version; yamlfmt --version"
```

## Development

- Edit `Dockerfile` and run `make build-goneat-tools`.
- Test multi-arch: `make build-goneat-tools-multi`.
- Push tags: Managed by GitHub Actions on path changes.

See [fulmen-toolbox README](../README.md) for monorepo overview.
