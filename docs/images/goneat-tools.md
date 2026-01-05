# goneat-tools Images

Purpose: containerized code quality/formatting/linting toolkit for CI and local runs.

This doc is intentionally conceptual. It does not enumerate pinned versions (to avoid drift). For the definitive inventory, use:

- `manifests/tools.json` at the release tag (SSOT for curated tools/pins)
- the published SBOM assets for that release (artifact-level truth)

## Variants

- `ghcr.io/fulmenhq/goneat-tools-slim-musl` — tool payload only (no runner baseline)
- `ghcr.io/fulmenhq/goneat-tools-runner-musl` — tool payload + runner baseline utilities for CI
- `ghcr.io/fulmenhq/goneat-tools-runner-glibc` — glibc runner + build tools for CGO workloads
- Compatibility alias: `ghcr.io/fulmenhq/goneat-tools:*` points to `goneat-tools-runner-musl:*`

See `docs/images/tag-taxonomy.md` for canonical tags and alias mappings.

## How to see what’s included (definitively)

### Option A: Use the release SBOM (recommended)

Each release publishes SBOM assets. For v0.3.0+ releases, musl images include the libc dimension in the image name:

- `sbom-goneat-tools-runner-musl-<version>.json`
- `sbom-goneat-tools-slim-musl-<version>.json`

Download and inspect:

```bash
FULMEN_TOOLBOX_RELEASE_TAG=v<version>
VERSION=<version>
curl -LO "https://github.com/fulmenhq/fulmen-toolbox/releases/download/${FULMEN_TOOLBOX_RELEASE_TAG}/sbom-goneat-tools-runner-musl-${VERSION}.json"

jq -r '.packages[]?.name' sbom-goneat-tools-runner-musl-${VERSION}.json | sort -u | head
```

### Option B: Generate an SBOM from the image you pulled

```bash
syft ghcr.io/fulmenhq/goneat-tools-runner-musl:v<version> -o spdx-json > sbom.json
```

### Option C: Quick interactive spot-check

```bash
docker run --rm ghcr.io/fulmenhq/goneat-tools-runner-musl:v<version> -c "prettier --version && biome --version && yamlfmt --version"
```

## Maintainer tooling: local manifest-derived catalog

For maintainers, `make catalog` generates a local markdown inventory from the manifest SSOT (written under `dist/`, which is gitignored):

```bash
make catalog
make catalog IMAGE=goneat-tools-runner-musl
```

## GitHub Actions runner permissions (container jobs)

GitHub-hosted `ubuntu-latest` runners often mount the workspace under `__w` owned by UID 1001.
If you run as a non-root user inside a job container, this can cause permission errors.

Recommended pattern:

```yaml
jobs:
  quality:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/fulmenhq/goneat-tools-runner-musl:latest
      options: --user 1001
    steps:
      - uses: actions/checkout@v4
      - run: prettier --check "**/*.{md,json,yml,yaml}"
```

Fallback (less secure):

```yaml
container:
  image: ghcr.io/fulmenhq/goneat-tools-runner-musl:latest
  options: --user root
```
