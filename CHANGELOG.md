# Changelog

Adheres to Keep a Changelog format. Versions follow semver.

## [Unreleased]

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

[Unreleased]: https://github.com/fulmenhq/fulmen-toolbox/compare/v0.2.4...HEAD
[0.2.4]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.4
[0.2.3]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.3
[0.2.2]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.2
[0.2.1]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.1
[0.2.0]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.0
[0.1.6]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.6
