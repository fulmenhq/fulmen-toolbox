# Changelog

Adheres to Keep a Changelog format. Versions follow semver.

## [Unreleased]

## [0.3.2] - 2026-02-04

### Changed

- **Tool updates (13 packages)**:
  - `sfetch` v0.4.0 → v0.4.1 (bug fix: 403 errors on certain GitHub asset downloads)
  - `goneat` v0.4.4 → v0.5.2
  - `prettier` 3.7.4 → 3.8.0 (Angular v21.1 support)
  - `biome` 2.3.8 → 2.3.11
  - `yamlfmt` v0.20.0 → v0.21.0 (stdin reading fixes)
  - `actionlint` v1.7.9 → v1.7.10 (ubuntu-slim runner support)
  - `checkmake` 0.2.2 → v0.3.2 (repo moved to checkmake/checkmake)
  - `syft` v1.39.0 → v1.41.1 (CycloneDX bug fixes)
  - `grype` v0.104.3 → v0.107.1 (DB schema v6 improvements)
  - `trivy` v0.68.1 → v0.69.0
  - `cargo-nextest` 0.9.120 → 0.9.122 (pager support)
  - `uv` 0.9.24 → 0.9.28 (OpenSSL 3.5.5 security fixes)
  - `yq-go` (apk) 4.49.2-r1 → 4.49.2-r2

### Fixed

- Updated checkmake import path after upstream repo migration from `mrtazz/checkmake` to `checkmake/checkmake`.

## [0.3.1] - 2026-01-12

### Added

- **Polyglot runner toolchains**: goneat-tools runners now include full build toolchains:
  - Rust 1.92.0 via rustup with 7 cross-compilation targets (linux gnu/musl, darwin, windows-gnu)
  - Cargo tools: cargo-deny, cargo-audit, cargo-zigbuild, cargo-nextest, cbindgen
  - Go 1.25.5 with CGO support
  - Zig 0.15.2 for cross-compilation
  - Python 3 + uv, maturin, pytest
  - Node/TypeScript: napi-rs CLI for native addon builds
  - SBOM tools: syft + grype included in runners
- **Subsystems framework**: New `subsystems/` taxonomy element for multi-container coordinated deployments:
  - `subsystems/echo-proxy-fixture`: Evaluation-scale nginx + echo backend stack
  - `subsystems/authentik-idp`: Enterprise IdP (Authentik) with blueprints, presets, OIDC
  - `schemas/subsystem-manifest.schema.json`: JSON Schema for MANIFEST.yaml validation
  - `make validate-subsystems`: CI validation for subsystem manifests and compose files
  - `docs/standards/subsystem-standard.md`: Normative specification
- **Build infrastructure**:
  - `docker-bake.hcl`: Parallel multi-image builds with shared cache
  - `make prove*` targets: Fast local validation (native arch parallel builds)
  - Local cache support: `make prove CACHE=1` for faster rebuilds
- **Developer tooling**:
  - `make bootstrap`: Uses sfetch -> goneat trust chain to install foundation tools
  - `.goneat/tools.yaml`: Scoped tool definitions for reproducible local environments
  - `docs/user-guide/preflight.md`: Prerequisites documentation
- **shellsentry**: Added to goneat/sbom runner images for static shell script risk assessment.

### Changed

- Replaced manual prereqs checking with goneat doctor tools for consistent cross-platform tool management.
- Container runtime tools (docker, colima) are now advisory-only in bootstrap; users install manually.
- Bumped `goneat` to v0.4.4.
- Bumped `sfetch` to v0.4.0.
- Bumped `syft` to v1.39.0, `grype` to v0.104.3 in sbom images.

### Known Limitations

- **arm64 musl runners**: `cargo-audit` and `cargo-nextest` skip on arm64 musl (upstream glibc-only binaries). Use `-runner-glibc` for full toolchain on arm64.

## [0.3.0] - 2026-01-05

### Added

- **Canonical tag taxonomy (ADR-0006)**: Image names now include libc dimension (`-runner-musl`, `-slim-musl`, `-runner-glibc`). Short-name aliases remain for compatibility.
- **Application image class**: New `manifests/apps.json` schema and `schemas/app-manifest.schema.json` for server/service images (distinct from tool images).
- **valkey-server-glibc**: First application image — Valkey (Redis-compatible) key-value store as vendor-image repack.
- **server_minimal_apt profile**: Minimal baseline for production server images (`ca-certificates`, `tzdata`).
- **Image taxonomy standard**: `docs/standards/image-taxonomy.md` as normative reference for naming conventions.

### Changed

- Renamed tool images to canonical form: `goneat-tools-runner` → `goneat-tools-runner-musl`, etc.
- Release and build workflows updated to publish canonical tags with alias mappings.
- Marked `scripts/release.sh` as legacy (v0.2.x era); CI workflow is the canonical release path.

### Fixed

- Tool manifest schema now enforces valid image ID patterns (`^[a-z0-9][a-z0-9-]*$`).

## [0.2.4] - 2026-01-03

- Bumped `goneat` to v0.4.2.
- Bumped `sfetch` to v0.3.2.

## [0.2.3] - 2026-01-01

- Added `yamllint` (and `python3`) to all runner baselines for semantic YAML linting.
- Updated runner tests to validate `yamllint` presence (and absence in slim variants).
- Documented `yamllint` rationale and runner-baseline guidance updates.
- Wired CI cosign signing to a manifest-derived image list to avoid hardcoded catalog drift.
- Updated agentic docs to use supervised, role-based attribution (no named identities).

## [0.2.2] - 2025-12-31

- Added glibc runner variants (`*-runner-glibc`) with CGO toolchain support (gcc, libc6-dev, pkg-config).
- Introduced `runner_baseline_apt` profile and extended validation/catalog tooling for apt-based runners.
- Added build tools to the musl runner baseline (`build-base`, `pkgconf`) so CGO workflows can run without root installs.
- Pinned bookworm base image digests for glibc variants.
- Documented multi-arch tagging, alias taxonomy, and Apple Silicon guidance for runners.
- Bumped `goneat` to v0.4.0 and `sfetch` to v0.2.9.

## [0.2.1] - 2025-12-15

- Prefer `GITHUB_TOKEN` for GHCR auth in CI workflows (reduces long-lived secrets).
- Clarified GHCR auth guidance across the release checklist and maintenance runbook.
- Added a fallback SOP for a dedicated GHCR bot + packages-only classic PAT.

## [0.2.0] - 2025-12-14

- Split toolbox images into explicit `-slim` and `-runner` variants; bare tags remain as runner aliases.
- Added schema-driven baseline profiles (`manifests/profiles.json`) and CI enforcement to prevent runner-baseline leakage into `-slim`.
- Added license/notice metadata to `manifests/tools.json` plus automated in-image validation (`make validate-licenses`) (ADR-0005).
- Added `goneat` (v0.3.20) and `sfetch` (v0.2.7) to `goneat-tools` as DX payload tools.
- Enforced required NOTICE handling where declared (e.g., Trivy NOTICE; FulmenHQ goneat NOTICE).
- Updated documentation for usage modes, image classes/profiles, and routine maintenance workflows.

## [0.1.6] - 2025-12-13

- Added `scripts/release-sign.sh` and `make release-sign` to consolidate manual signing.
- Added `FULMEN_TOOLBOX_GPG_HOMEDIR` support and clearer preflight failures for multi-keyring setups.
- Added `make release-notes` and updated `release-upload` to optionally include staged release notes.
- Added OCI-attached SBOM publishing via `cosign attach sbom` in the manual signing flow.
- Added `/licenses` and `/notices` conventions in images; seeded curated license texts and best-effort notices.
- Added `minisign` to `goneat-tools` image.
- Added ADR-0003 documenting the license/notice approach.

## Older Releases

For earlier history, see GitHub Releases: https://github.com/fulmenhq/fulmen-toolbox/releases

[Unreleased]: https://github.com/fulmenhq/fulmen-toolbox/compare/v0.3.2...HEAD
[0.3.2]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.2
[0.3.1]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.1
[0.3.0]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.0
[0.2.4]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.4
[0.2.3]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.3
[0.2.2]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.2
[0.2.1]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.1
[0.2.0]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.0
[0.1.6]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.6
