# Image Inventory

This document provides a conceptual overview of available images. For definitive tool versions, refer to:

- `manifests/tools.json` at the release tag (curated tool pins)
- Published SBOM assets for each release (artifact-level truth)

## goneat-tools

**Purpose**: Polyglot code quality, formatting, linting, and build toolkit for CI and local use.

**Variants**:

- `goneat-tools-slim-musl` — Code quality tools only (no build toolchains)
- `goneat-tools-runner-musl` — Full polyglot runner (Alpine/musl)
- `goneat-tools-runner-glibc` — Full polyglot runner (Debian/glibc, recommended for arm64)

**Included toolchains** (runner variants):

- **Rust**: rustc/cargo via rustup, with cross-compilation targets + cargo-deny, cargo-audit, cargo-zigbuild, cargo-nextest, cbindgen
- **Go**: Full toolchain with CGO support
- **Zig**: Cross-compilation backend
- **Python**: python3 + uv, maturin (PyO3/Rust bindings), pytest
- **Node/TypeScript**: npm + napi-rs CLI for native addon builds
- **SBOM**: syft + grype for in-build SBOM generation

**Code quality tools** (all variants):

- Formatting: Prettier, Biome, yamlfmt, shfmt, taplo
- Linting: yamllint (runner only), actionlint, checkmake
- Utilities: jq, yq, ripgrep, minisign, goneat, sfetch

**Base images**:

- musl variants: `node:22-alpine`
- glibc variant: `node:22-bookworm-slim`

**Signing**: cosign signatures + attestations, GPG/minisign for `SHA256SUMS`.

See `docs/images/goneat-tools.md` for usage patterns.

## sbom-tools

**Purpose**: SBOM generation and vulnerability scanning for CI and local use.

**Variants**:

- `sbom-tools-slim-musl` — SBOM tools only
- `sbom-tools-runner-musl` — SBOM tools + runner baseline (Alpine/musl)
- `sbom-tools-runner-glibc` — SBOM tools + runner baseline (Debian/glibc)

**Included tools**:

- syft (SBOM generation)
- grype (vulnerability scanning against SBOM)
- trivy (filesystem/container vulnerability scanning)
- shellsentry (runner only, shell script risk assessment)
- jq, yq (output shaping)
- git, curl (runner only, CI checkouts)

**Base images**:

- musl variants: `alpine:3.21`
- glibc variant: `debian:bookworm-slim`

**Output formats**: CycloneDX JSON (default), SPDX JSON.

**Note**: Grype and Trivy pull vulnerability DBs on first run (~80-150MB each); recommend caching for CI.

See `manifests/tools.json` for current version pins.

## valkey-server-glibc

**Purpose**: Valkey (Redis-compatible) key-value store as vendor-image repack.

**Features**:

- Non-root runtime (valkey user)
- License transparency (`/licenses/`)
- CLI-based configuration

**Base image**: `debian:bookworm-slim`

See `docs/images/valkey.md` for usage guide.

## Subsystems (v0.3.1+)

Multi-container coordinated deployments in `subsystems/`:

- `echo-proxy-fixture` — Evaluation-scale nginx + echo backend
- `authentik-idp` — Enterprise IdP with blueprints, presets, OIDC

See `docs/standards/subsystem-standard.md` for specification.
