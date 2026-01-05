# Fulmen Toolbox 🧰

[![goneat-tools size](https://ghcr-badge.egpl.dev/fulmenhq/goneat-tools/size?label=goneat-tools)](https://github.com/fulmenhq/fulmen-toolbox/pkgs/container/goneat-tools)
[![sbom-tools size](https://ghcr-badge.egpl.dev/fulmenhq/sbom-tools/size?label=sbom-tools)](https://github.com/fulmenhq/fulmen-toolbox/pkgs/container/sbom-tools)
[![Latest Release](https://img.shields.io/github/v/release/fulmenhq/fulmen-toolbox?label=release)](https://github.com/fulmenhq/fulmen-toolbox/releases/latest)

**Fulmen Toolbox** is the official monorepo for FulmenHQ's family of focused, multi-architecture Docker images providing shared, reproducible tooling across our ecosystem (goneat, fulward, pathfinder, etc.).

**Status:** Production-ready. See [releases](https://github.com/fulmenhq/fulmen-toolbox/releases) for latest versions.

## Why Toolbox?

- **Reproducible CI/CD**: No more flakey tool installs – pull a container.
- **Focused & Lean**: One purpose per image (~150-250MB, multi-arch).
- **Team-Stewarded**: FulmenHQ maintains consistency, security, minimal size.
- **Easy Integration**: Drop-in GitHub Actions or local Docker runs.

## Image Variants

Each toolbox image comes in three variants to match your use case:

| Variant | Use Case | Includes | Copyleft? |
|---------|----------|----------|----------|
| **`-runner`** | CI jobs, build tasks | Tools + runner baseline + build tools (gcc, pkg-config) | Yes (by design) |
| **`-slim`** | Tool replacement, local use | Tools only, smaller footprint | Best-effort minimized |
| **`-runner-glibc`** | CGO builds, glibc-only deps | Tools + runner baseline + build tools (gcc, libc6-dev) | Yes (by design) |

**Which should I use?**
- Use **`-runner`** if you're running CI jobs, need `make`/`gcc`, or want a full shell environment (musl/Alpine)
- Use **`-runner-glibc`** if you need `CGO_ENABLED=1` or glibc-only dependencies
- Use **`-slim`** if you just want to run a tool without installing it locally (e.g., `docker run ... prettier --write .`)

**Why no `-slim-glibc`?**
- Glibc variants target CGO and system-library workflows that typically need the runner baseline anyway.
- `-slim` is optimized for minimal local tool use; adding glibc doesn’t provide value without the baseline tools.

See [Container Usage Patterns](docs/user-guide/container-usage-patterns.md) for detailed examples.

## Available Images (Canonical)

Starting with v0.3.0, canonical tags include the libc dimension (e.g., `*-runner-musl`). Short tags that omit libc (e.g., `*-runner`) remain compatibility aliases for a limited transition window.

| Canonical Image | Libc/Distro | Arch | Purpose |
|-----------------|-------------|------|---------|
| `goneat-tools-runner-musl` | musl / Alpine | multi-arch (amd64, arm64) | Code quality + CI runner baseline |
| `goneat-tools-slim-musl` | musl / Alpine | multi-arch (amd64, arm64) | Code quality tools only |
| `goneat-tools-runner-glibc` | glibc / Debian | multi-arch (amd64, arm64) | Code quality + glibc runner baseline |
| `sbom-tools-runner-musl` | musl / Alpine | multi-arch (amd64, arm64) | SBOM/vuln scanning + CI runner baseline |
| `sbom-tools-slim-musl` | musl / Alpine | multi-arch (amd64, arm64) | SBOM/vuln scanning tools only |
| `sbom-tools-runner-glibc` | glibc / Debian | multi-arch (amd64, arm64) | SBOM/vuln scanning + glibc runner baseline |

## Alias Sets (Published)

See `docs/standards/image-taxonomy.md` and `docs/images/tag-taxonomy.md` for the full taxonomy and alias rules.

| Canonical | Type | Alias Tags | Notes |
|-----------|------|------------|-------|
| `goneat-tools-runner-musl` | multi-arch | `goneat-tools-runner`, `goneat-tools`, `goneat-tools-runner-alpine` | Musl runner canonical; shorthand remains a compatibility alias. |
| `goneat-tools-slim-musl` | multi-arch | `goneat-tools-slim`, `goneat-tools-slim-alpine` | Musl slim canonical; shorthand remains a compatibility alias. |
| `goneat-tools-runner-glibc` | multi-arch | `goneat-tools-runner-debian` | Glibc runner uses Debian bookworm-slim. |
| `goneat-tools-runner-musl-amd64` | single-arch (when published) | `goneat-tools-runner-amd64`, `goneat-tools-runner-alpine-amd64` | Force amd64 in CI/debug. |
| `goneat-tools-runner-musl-arm64` | single-arch (when published) | `goneat-tools-runner-arm64`, `goneat-tools-runner-alpine-arm64` | Force arm64 on Apple Silicon/Graviton. |
| `goneat-tools-runner-glibc-amd64` | single-arch (when published) | `goneat-tools-runner-debian-amd64` | Force amd64 glibc in CI/debug. |
| `goneat-tools-runner-glibc-arm64` | single-arch (when published) | `goneat-tools-runner-debian-arm64` | Force arm64 glibc on Apple Silicon/Graviton. |
| `sbom-tools-runner-musl` | multi-arch | `sbom-tools-runner`, `sbom-tools`, `sbom-tools-runner-alpine` | Musl runner canonical; shorthand remains a compatibility alias. |
| `sbom-tools-slim-musl` | multi-arch | `sbom-tools-slim`, `sbom-tools-slim-alpine` | Musl slim canonical; shorthand remains a compatibility alias. |
| `sbom-tools-runner-glibc` | multi-arch | `sbom-tools-runner-debian` | Glibc runner uses Debian bookworm-slim. |
| `sbom-tools-runner-musl-amd64` | single-arch (when published) | `sbom-tools-runner-amd64`, `sbom-tools-runner-alpine-amd64` | Force amd64 in CI/debug. |
| `sbom-tools-runner-musl-arm64` | single-arch (when published) | `sbom-tools-runner-arm64`, `sbom-tools-runner-alpine-arm64` | Force arm64 on Apple Silicon/Graviton. |
| `sbom-tools-runner-glibc-amd64` | single-arch (when published) | `sbom-tools-runner-debian-amd64` | Force amd64 glibc in CI/debug. |
| `sbom-tools-runner-glibc-arm64` | single-arch (when published) | `sbom-tools-runner-debian-arm64` | Force arm64 glibc on Apple Silicon/Graviton. |

Arch suffixes (optional): append `-amd64` or `-arm64` to any canonical or alias tag to target a single-arch manifest when published. Default tags are multi-arch and already include arm64.

Multi-arch tags pull native layers automatically (Apple Silicon/Graviton get arm64 without emulation).

> **Note:** `goneat-tools` and `sbom-tools` (without suffix) are aliases for `-runner` (musl/Alpine) variants.
>
> **Note:** Slim variants aim to avoid adding the runner baseline; the base distro may still include copyleft components. Inspect `/licenses/` in the image for details.

Pinned versions: see `manifests/tools.json` (validated via `make validate-manifest`).

**goneat-tools**: Prettier `3.7.4`, Biome `2.3.8`, yamlfmt `v0.20.0`, shfmt `v3.12.0`, checkmake `0.2.2`, actionlint `v1.7.9`, goneat `v0.4.0`, sfetch `v0.2.9`, minisign `0.12-r0`, jq `1.8.1-r0`, yq-go `4.49.2-r1`, ripgrep `15.1.0-r0`, taplo `0.10.0-r0`, bash `5.3.3-r1`, git `2.52.0-r0`, curl `8.17.0-r1` (all pinned). Glibc runners use `node:22-bookworm-slim` and `golang:1.25-bookworm`.

**sbom-tools**: syft `v1.18.1`, grype `v0.86.1`, trivy `v0.68.1`, jq `1.7.1-r0`, yq-go `4.44.5-r5`, git `2.47.3-r0`. Base: `alpine:3.21` (musl). Glibc runners use `debian:bookworm-slim`.

**Image Registry:** `ghcr.io/fulmenhq/{image}:{tag}`

## Quick Start

### GitHub Actions

```yaml
jobs:
  quality:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/fulmenhq/goneat-tools-runner-musl:latest
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
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim-musl:latest \
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

**CI/CD:** CI verifies on PR/main; publish happens on semver tags (`v*.*.*`). Tag builds push `:latest`, `:v<major>`, and the semver tag. Images are signed with cosign and include SBOM attestations.

## Proposing New Images

1. Open an issue with tool needs, size estimate, Dockerfile sketch.
2. FulmenHQ team reviews → approves → merges.

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT © FulmenHQ
