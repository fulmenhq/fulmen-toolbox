# goneat-tools Images

Purpose: containerized code quality/formatting/linting toolkit for CI and local runs.

This doc is intentionally conceptual. It does not enumerate pinned versions (to avoid drift). For the definitive inventory, use:

- `manifests/tools.json` at the release tag (SSOT for curated tools/pins)
- the published SBOM assets for that release (artifact-level truth)

## Variants

- `ghcr.io/fulmenhq/goneat-tools-slim` — tool payload only (no runner baseline)
- `ghcr.io/fulmenhq/goneat-tools-runner` — tool payload + runner baseline utilities for CI
- `ghcr.io/fulmenhq/goneat-tools-runner-glibc` — glibc runner + build tools for CGO workloads
- Compatibility alias: `ghcr.io/fulmenhq/goneat-tools:*` points to `goneat-tools-runner:*`

See `docs/images/tag-taxonomy.md` for canonical tags and alias mappings.

## How to see what’s included (definitively)

### Option A: Use the release SBOM (recommended)

Each release publishes SBOM assets. For example (v0.2.1):

- `sbom-goneat-tools-runner-0.2.1.json`
- `sbom-goneat-tools-slim-0.2.1.json`

Download and inspect:

```bash
FULMEN_TOOLBOX_RELEASE_TAG=v0.2.1
curl -LO "https://github.com/fulmenhq/fulmen-toolbox/releases/download/${FULMEN_TOOLBOX_RELEASE_TAG}/sbom-goneat-tools-runner-0.2.1.json"

jq -r '.packages[]?.name' sbom-goneat-tools-runner-0.2.1.json | sort -u | head
```

### Option B: Generate an SBOM from the image you pulled

```bash
syft ghcr.io/fulmenhq/goneat-tools-runner:v0.2.1 -o spdx-json > sbom.json
```

### Option C: Quick interactive spot-check

```bash
docker run --rm ghcr.io/fulmenhq/goneat-tools-runner:v0.2.1 -c "prettier --version && biome --version && yamlfmt --version"
```

## Maintainer tooling: local manifest-derived catalog

For maintainers, `make catalog` generates a local markdown inventory from the manifest SSOT (written under `dist/`, which is gitignored):

```bash
make catalog
make catalog IMAGE=goneat-tools-runner
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
      image: ghcr.io/fulmenhq/goneat-tools-runner:latest
      options: --user 1001
    steps:
      - uses: actions/checkout@v4
      - run: prettier --check "**/*.{md,json,yml,yaml}"
```

Fallback (less secure):

```yaml
container:
  image: ghcr.io/fulmenhq/goneat-tools-runner:latest
  options: --user root
```
