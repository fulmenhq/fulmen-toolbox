# goneat-tools Docker Image

[![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/ghcr.io/fulmenhq/goneat-tools/latest)](https://ghcr.io/fulmenhq/goneat-tools)
[![Docker Pulls](https://img.shields.io/docker/pulls/ghcr.io/fulmenhq/goneat-tools)](https://ghcr.io/fulmenhq/goneat-tools)

Focused Docker image providing code quality and formatting tools for the FulmenHQ ecosystem.

## Included Tools

| Tool     | Purpose                          | Source     |
|----------|----------------------------------|------------|
| Prettier (3.7.4) | JSON, Markdown, YAML formatting | npm        |
| Biome (2.3.8) | JS/TS/JSON lint/format | npm |
| yamlfmt (v0.20.0) | Dedicated YAML formatting/linting | Go binary |
| jq (1.8.1-r0)      | JSON processing/filtering       | Alpine pkg |
| yq-go (4.49.2-r1)  | YAML processing/filtering       | Alpine pkg |
| ripgrep (15.1.0-r0) | Fast text search/search & replace | Alpine pkg |
| taplo (0.10.0-r0) | TOML formatting/linting         | Alpine pkg |
| bash (5.3.3-r1), git (2.52.0-r0) | Shell & Git utilities | Alpine pkg |

**Base Image:** `node:22-alpine@sha256:9632533...` (multi-arch digest pinned)

See `docs/images/goneat-tools.md` and `manifests/tools.json` for pinning details.

**Image Tags:**
- `ghcr.io/fulmenhq/goneat-tools:latest`
- `ghcr.io/fulmenhq/goneat-tools:v0.1.0` (semver tags)

## Usage

### GitHub Actions (Recommended)

```yaml
jobs:
  quality:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/fulmenhq/goneat-tools:latest
    steps:
      - uses: actions/checkout@v4
      - run: prettier --check "**/*.{md,json,yml,yaml}"
      - run: biome check .
      - run: yamlfmt -lint .
      - run: taplo fmt --check
      - run: rg --type md "TODO"  # Example ripgrep usage
```

### Local Docker Run

**Note**: Uses your **local configs** (.prettierrc.json, .yamlfmt.yaml, etc.) via volume mount – image provides tools only.

Mount your repo and run tools:

```bash
# Format files
docker run --rm -v "$(pwd):/work" -w /work \
  ghcr.io/fulmenhq/goneat-tools:latest \
  sh -c "prettier --write '**/*.{md,json,yml,yaml}' && yamlfmt -w ."

# Lint/check only
docker run --rm -v "$(pwd):/work" -w /work \
  ghcr.io/fulmenhq/goneat-tools:latest \
  sh -c "prettier --check '**/*.{md,json,yml,yaml}' && yamlfmt -lint ."

# Preserve user/group ownership
docker run --rm -v "$(pwd):/work" -w /work \
  --user $(id -u):$(id -g) \
  ghcr.io/fulmenhq/goneat-tools:latest \
  sh -c "prettier --write '**/*.{md,json,yml,yaml}'"
```

### Local Build & Test

```bash
make build-goneat-tools  # From repo root
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools:local sh -c "prettier --version; yamlfmt --version"
```

## Development

- Edit `Dockerfile` and run `make build-goneat-tools`.
- Test multi-arch: `make build-goneat-tools-multi`.
- Push tags: Managed by GitHub Actions on path changes.

See [fulmen-toolbox README](../README.md) for monorepo overview.
