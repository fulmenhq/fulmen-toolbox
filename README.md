# Fulmen Toolbox 🧰

[![Docker Image Size (goneat-tools)](https://img.shields.io/docker/image-size/ghcr.io/fulmenhq/goneat-tools/latest)](https://ghcr.io/fulmenhq/goneat-tools)
[![Docker Pulls (goneat-tools)](https://img.shields.io/docker/pulls/ghcr.io/fulmenhq/goneat-tools)](https://ghcr.io/fulmenhq/goneat-tools)

**Fulmen Toolbox** is the official monorepo for FulmenHQ's family of focused, multi-architecture Docker images providing shared, reproducible tooling across our ecosystem (goneat, fulward, pathfinder, etc.).

**Status:** 🚀 Phase 1 – `goneat-tools` ready for testing (v0.1.1).

## Why Toolbox?

- **Reproducible CI/CD**: No more flakey tool installs – pull a container.
- **Focused & Lean**: One purpose per image (~150-250MB, multi-arch).
- **Team-Stewarded**: FulmenHQ maintains consistency, security, minimal size.
- **Easy Integration**: Drop-in GitHub Actions or local Docker runs.

## Available Images

| Image              | Purpose                          | Tags                  | Size   |
|--------------------|----------------------------------|-----------------------|--------|
| [goneat-tools](images/goneat-tools/) | Code quality/format/lint (Prettier, Biome, yamlfmt, shfmt, checkmake, actionlint, jq, yq, rg, taplo) | `:latest`, `:v0`     | ~150MB |
| [sbom-tools](images/sbom-tools/) | SBOM generation & vuln scanning (syft, grype) | `:latest`, `:v0` | ~80-120MB |
| security-tools     | (Phase 3: Coming soon)           |                       |        |

Pinned versions: see `manifests/tools.json` (validated via `make validate-manifest`).

**goneat-tools**: Prettier `3.7.4`, Biome `2.3.8`, yamlfmt `v0.20.0`, shfmt `v3.12.0`, checkmake `0.2.2`, actionlint `v1.7.9`, jq, yq-go, ripgrep, taplo, bash, git, curl (all pinned).

**sbom-tools**: syft `v1.18.1`, grype `v0.86.1`, trivy `v0.68.1`, jq `1.8.1-r0`, yq-go `4.49.2-r1`, git `2.52.0-r0`. Base: `alpine:3.21`.

**Image Registry:** `ghcr.io/fulmenhq/{image}:{tag}`

## Quick Start

### GitHub Actions

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
      - run: biome check .
      - run: yamlfmt -lint .
      - run: taplo fmt --check
```

> **Note:** The `--user 1001` option ensures the container user matches GitHub Actions runner mount ownership. Without this, non-root containers may fail with `EACCES` errors on `/__w/_temp/_runner_file_commands/`.

### Local

**Note**: Uses your **local configs** (.prettierrc.json, .yamlfmt.yaml, etc.) via volume mount – image provides tools only.

```bash
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools:latest \
  sh -c "prettier --write '**/*.{md,json,yml,yaml}' && yamlfmt -w ."
```

## Local Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for full setup guide, Docker runtime options, and troubleshooting.

From repo root:
```bash
make build-goneat-tools    # Single arch
make build-goneat-tools-multi  # Multi-arch
make test-goneat-tools     # Verify tools
make quality               # Validate manifest + lint workflows (needs yamlfmt)
make precommit             # Quality bundle
make prepush               # Quality + build + test (requires docker)
make size                  # Check sizes
make bootstrap             # Check required tooling (docker, cosign, gpg, minisign, syft, yamlfmt)
```

Requires a local Docker daemon for builds/tests and manifest validation (uses Dockerized ajv). GitHub Actions runners are the primary CI path; local builds are optional but recommended for quick checks.

**CI/CD:** CI verifies on PR/main; publish happens on semver tags (`v*.*.*`). Tag builds push `:latest`, `:v<major>`, and the semver tag once release signing is wired. Current baseline: v0.1.1.

## Proposing New Images

1. Open an issue with tool needs, size estimate, Dockerfile sketch.
2. FulmenHQ team reviews → approves → merges.

See [.plans/fulmen-toolbox-vision.md](.plans/fulmen-toolbox-vision.md) (internal) & [.plans/fulmen-toolbox-bootstrap.md](.plans/fulmen-toolbox-bootstrap.md).

## License

MIT © FulmenHQ
