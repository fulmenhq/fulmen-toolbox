# sbom-tools Docker Image

[![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/ghcr.io/fulmenhq/sbom-tools/latest)](https://ghcr.io/fulmenhq/sbom-tools)
[![Docker Pulls](https://img.shields.io/docker/pulls/ghcr.io/fulmenhq/sbom-tools)](https://ghcr.io/fulmenhq/sbom-tools)

Focused Docker image providing SBOM generation and vulnerability scanning tools for the FulmenHQ ecosystem.

## Licenses and Notices

This image bundles upstream license texts under `/licenses/` and upstream notice files (when present) under `/notices/` for transparency and compliance support.

## Included Tools

| Tool     | Purpose                          | Source     |
|----------|----------------------------------|------------|
| syft (v1.18.1) | SBOM generation (CycloneDX, SPDX) | GitHub release |
| grype (v0.86.1) | Vulnerability scanning | GitHub release |
| trivy (v0.68.1) | SBOM + vuln + config scanning | GitHub release |
| jq (1.8.1-r0) | JSON shaping for SBOM outputs | apk |
| yq-go (4.49.2-r1) | YAML/JSON filtering | apk |
| git (2.52.0-r0) | Repo checkout inside containerized CI | apk |

**Base Image:** `alpine:3.21@sha256:5405e8f3...` (multi-arch digest pinned)

See `manifests/tools.json` for pinning details and `docs/user-guide/container-usage-patterns.md` for usage patterns.

**Image Tags:**
- `ghcr.io/fulmenhq/sbom-tools:latest`
- `ghcr.io/fulmenhq/sbom-tools:v0.1.1` (semver tags)

## Usage

### Generate SBOM (CycloneDX JSON - default)

```bash
# Scan a directory
docker run --rm -v "$(pwd):/work" ghcr.io/fulmenhq/sbom-tools:latest \
  -c "syft /work -o cyclonedx-json > sbom.cdx.json"

# Scan a container image
docker run --rm ghcr.io/fulmenhq/sbom-tools:latest \
  -c "syft ghcr.io/fulmenhq/goneat-tools:latest -o cyclonedx-json"
```

### Generate SBOM (SPDX JSON)

```bash
docker run --rm -v "$(pwd):/work" ghcr.io/fulmenhq/sbom-tools:latest \
  -c "syft /work -o spdx-json > sbom.spdx.json"
```

### Vulnerability Scan

```bash
# Scan a directory
docker run --rm -v "$(pwd):/work" ghcr.io/fulmenhq/sbom-tools:latest \
  -c "grype /work"

# Scan from SBOM
docker run --rm -v "$(pwd):/work" ghcr.io/fulmenhq/sbom-tools:latest \
  -c "grype sbom:/work/sbom.cdx.json"

# Scan a container image
docker run --rm ghcr.io/fulmenhq/sbom-tools:latest \
  -c "grype ghcr.io/fulmenhq/goneat-tools:latest"
```

### GitHub Actions

```yaml
jobs:
  sbom:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/fulmenhq/sbom-tools:latest
    steps:
      - uses: actions/checkout@v4
      - name: Generate SBOM
        run: syft . -o cyclonedx-json > sbom.cdx.json
      - name: Vulnerability scan
        run: grype sbom:sbom.cdx.json --fail-on high
      - uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: sbom.cdx.json
```

## Grype Database

Grype downloads its vulnerability database on first run (~150MB). For CI pipelines:

- **Accept fresh pull**: Default behavior, ensures latest vulns
- **Cache the DB**: Mount `~/.cache/grype` to persist between runs

```bash
# With DB caching
docker run --rm \
  -v "$(pwd):/work" \
  -v "${HOME}/.cache/grype:/root/.cache/grype" \
  ghcr.io/fulmenhq/sbom-tools:latest \
  -c "grype /work"
```

## Output Formats

### syft

| Format | Flag | Use Case |
|--------|------|----------|
| CycloneDX JSON | `-o cyclonedx-json` | Industry standard, CI/CD integration |
| SPDX JSON | `-o spdx-json` | License compliance, legal |
| Table | `-o table` | Human-readable (default) |

### grype

| Format | Flag | Use Case |
|--------|------|----------|
| Table | (default) | Human-readable |
| JSON | `-o json` | CI/CD integration |
| CycloneDX | `-o cyclonedx` | Attach vulns to SBOM |

## Local Build & Test

```bash
make build-sbom-tools  # From repo root
make test-sbom-tools   # Verify tools work
```

## Development

- Edit `Dockerfile` and run `make build-sbom-tools`.
- Test multi-arch: `make build-sbom-tools-multi`.
- Push tags: Managed by GitHub Actions on path changes.

See [fulmen-toolbox README](../../README.md) for monorepo overview.
