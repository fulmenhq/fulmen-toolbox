# Changelog

Adheres to Keep a Changelog format. Versions follow semver.

## [Unreleased]
- Planned: pin all tool versions and base image digests.
- Planned: add CI for multi-arch build, signing, attestations.
- Planned: SBOM + provenance publishing.

## [0.1.1] - 2025-12-07
- Added release workflow (tag-driven build/push, SBOM generation, optional signing/attestations).
- Guarded cosign/GPG/minisign steps to allow manual signing until secrets are configured.
- Doc updates for CI strategy and version baseline.

## [0.1.0] - 2025-12-07
- Initial structure for `fulmen-toolbox`.
- `goneat-tools` image drafted (Prettier, Biome, yamlfmt, jq, yq-go, rg, taplo).
- Added release docs, version bump helpers, and ADR scaffolding.

[Unreleased]: https://github.com/fulmenhq/fulmen-toolbox/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.1
[0.1.0]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.0
