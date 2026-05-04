# goneat-tools Images

Purpose: Polyglot code quality, formatting, linting, and build toolkit for CI and local runs.

This doc is intentionally conceptual. It does not enumerate pinned versions (to avoid drift). For the definitive inventory, use:

- `manifests/tools.json` at the release tag (SSOT for curated tools/pins)
- the published SBOM assets for that release (artifact-level truth)

## Variants

- `ghcr.io/fulmenhq/goneat-tools-slim-musl` — Code quality tools only (no build toolchains, no runner baseline)
- `ghcr.io/fulmenhq/goneat-tools-runner-musl` — Full polyglot runner (Alpine/musl)
- `ghcr.io/fulmenhq/goneat-tools-runner-glibc` — Full polyglot runner (Debian/glibc, recommended for arm64)
- Compatibility alias: `ghcr.io/fulmenhq/goneat-tools:*` points to `goneat-tools-runner-musl:*`

See `docs/images/tag-taxonomy.md` for canonical tags and alias mappings.

## What's included

### Code Quality Tools (all variants)

- **Formatting**: Prettier, Biome, yamlfmt, shfmt, taplo
- **Linting**: actionlint, checkmake, yamllint (runner only)
- **Utilities**: jq, yq, ripgrep, minisign, goneat, sfetch

### Polyglot Build Toolchains (runner variants only)

| Toolchain       | Capabilities                                                       |
| --------------- | ------------------------------------------------------------------ |
| **Rust**        | rustup, rustc, cargo, rustfmt, clippy, 7 cross-compilation targets |
| **Cargo tools** | cargo-deny, cargo-audit, cargo-zigbuild, cargo-nextest, cbindgen   |
| **Go**          | Full toolchain with CGO_ENABLED=1                                  |
| **Zig**         | Cross-compilation backend for cargo-zigbuild                       |
| **Python**      | python3, uv, maturin (PyO3/Rust bindings), pytest                  |
| **Node**        | npm, napi-rs CLI for native addon builds                           |
| **SBOM**        | syft, grype                                                        |
| **Shell**       | shellsentry                                                        |

### Runner Variant Comparison

| Feature       | `-runner-musl`   | `-runner-glibc`       |
| ------------- | ---------------- | --------------------- |
| Base          | Alpine 3.21      | Debian bookworm-slim  |
| libc          | musl             | glibc                 |
| CGO           | Yes (build-base) | Yes (build-essential) |
| cargo-audit   | amd64 only       | amd64 + arm64         |
| cargo-nextest | amd64 only       | amd64 + arm64         |

**Recommendation**: Use `-runner-glibc` for full toolchain support on arm64.

## How to see what's included (definitively)

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
# Code quality tools
docker run --rm ghcr.io/fulmenhq/goneat-tools-runner-musl:v<version> -c "prettier --version && biome --version && yamlfmt --version"

# Polyglot toolchains
docker run --rm ghcr.io/fulmenhq/goneat-tools-runner-glibc:v<version> -c "rustc --version && go version && zig version && python3 --version"
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
