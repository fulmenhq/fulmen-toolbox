# Changelog

Adheres to Keep a Changelog format. Versions follow semver.

## [Unreleased]
- Planned: Add trivy config scanning for Dockerfile best practices.
- Planned: Signing/attestation wiring once secrets are configured.

## [0.1.2] - 2025-12-08
- Added `sbom-tools` image (syft v1.18.1, grype v0.86.1).
- Release workflow now uses matrix to build all images in parallel.
- Dockerfiles are now SSOT for versions (removed build-args from CI).
- Added `lint-dockerfiles` target (docker build --check, optional).
- Makefile: `build-all`, `test-all`, `check-clean` targets; `prepush` now validates all images.

## [0.1.1] - 2025-12-07
- Added release workflow (tag-driven build/push, SBOM generation, optional signing/attestations).
- Guarded cosign/GPG/minisign steps to allow manual signing until secrets are configured.
- Doc updates for CI strategy and version baseline.

## [0.1.0] - 2025-12-07
- Initial structure for `fulmen-toolbox`.
- `goneat-tools` image drafted (Prettier, Biome, yamlfmt, jq, yq-go, rg, taplo).
- Added release docs, version bump helpers, and ADR scaffolding.

[Unreleased]: https://github.com/fulmenhq/fulmen-toolbox/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.2
[0.1.1]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.1
[0.1.0]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.0
