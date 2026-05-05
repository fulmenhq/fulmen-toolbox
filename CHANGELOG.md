# Changelog

Adheres to Keep a Changelog format. Versions follow semver.

## [Unreleased]

## [0.4.0] - 2026-05-04

### Added

- **golangci-lint v2.12.1** bundled in `goneat-tools-runner-{musl,glibc}`. Built in-runner against the pinned Go (1.26.2) so consumer configs targeting that Go version no longer hit "language version too low". License: GPL-3.0-only (runner is copyleft-by-design). NOT included in slim variants.
- **Scheduled trivy CVE-scan workflow** (`.github/workflows/cve-scan.yml`). Twice-weekly (Mon/Thu 06:00 UTC) scan of all 6 published image variants × 3 tags (`:latest` + 2 most recent pinned semver) = 18 cells. Aggregates findings into a single rolling tracker issue labeled `cve-watch`. `workflow_dispatch` supports severity override + dry-run for synthetic tests.
- **YAML config triplet**: `.yamlfmt`, `.yamllint`, `.goneat/assess.yaml` aligned with the goneat appnote on yaml-format-lint-alignment. Sets `pad_line_comments: 2` explicitly to avoid yamlfmt-vs-yamllint oscillation.
- **`make pr-final`**: strict local gate that runs `goneat format` then `goneat assess --check --categories format,lint,security --fail-on medium`.
- `.trivyignore` placeholder for CVE allowlist with rationale + review-by date format.

### Changed

- Repo-wide cosmetic format normalization to the new yaml triplet baseline (markdown table padding, JSON array expansion). No semantic content changes; suitable for `.git-blame-ignore-revs` if desired.

### Migration

⚠ Consumers using `golangci/golangci-lint-action@v7` (or any separate `go install`/install-script step) inside the runner: **drop the separate install step** to use the bundled binary. The bundled binary is the only one built against the runner's pinned Go. See `docs/releases/v0.4.0.md` for migration guidance.

## [0.3.5] - 2026-05-02

### Changed

- **Go pin** 1.26.1 → 1.26.2 (clears CVE-2026-33810 high; unblocks downstream consumers whose `golangci-lint` configs target `go 1.26.2`).
- **Builder image digests** refreshed for `golang:1.26-bookworm` and `golang:1.26-alpine` (now resolve to Go 1.26.2).
- **yq-go (apk)** 4.49.2-r4 → 4.49.2-r5 (Alpine package revision; r4 no longer available upstream).

## [0.3.4] - 2026-03-25

### Changed

- **goneat** v0.5.8 → v0.5.9 (bug fixes)
- **Go pin** 1.26 → 1.26.1 (eliminate dependency vulnerability noise)
- **bootstrap-tools.sh**: Refactored to arg-based interface with env var overrides

## [0.3.3] - 2026-03-18

### Changed

- **Tool updates (6 packages)**:
  - `goneat` v0.5.2 → v0.5.8
  - `sfetch` v0.4.1 → v0.4.5
  - `shellsentry` v0.1.1 → v0.1.4
  - `trivy` v0.69.0 → v0.69.3 (v0.69.0 ARM64 release asset unavailable upstream)
  - `yq-go` (apk) 4.49.2-r2 → 4.49.2-r4 (Alpine package revision)
  - Go builder 1.25 → 1.26.1 (required for shellsentry v0.1.4)
- **AGENTS.md**: Tightened agentic attribution standard; added Default Role and Identity rows, required `noreply@3leaps.net` in `Co-Authored-By`, updated example to Claude Sonnet 4.6.

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

## Older Releases

For earlier history, see GitHub Releases: https://github.com/fulmenhq/fulmen-toolbox/releases

[Unreleased]: https://github.com/fulmenhq/fulmen-toolbox/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.4.0
[0.3.5]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.5
[0.3.4]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.4
[0.3.3]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.3
[0.3.2]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.2
[0.3.1]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.1
[0.3.0]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.0
[0.2.4]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.4
[0.2.3]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.3
[0.2.2]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.2
