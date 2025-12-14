# Changelog

Adheres to Keep a Changelog format. Versions follow semver.

## [Unreleased]

- Planned: CI-automated signing once secrets are configured.

## [0.1.6] - 2025-12-13

- Added `scripts/release-sign.sh` and `make release-sign` to consolidate manual signing.
- Added `GPG_HOMEDIR` support and clearer preflight failures for multi-keyring setups.
- Added `make release-notes` and updated `release-upload` to optionally include staged release notes.
- Added OCI-attached SBOM publishing via `cosign attach sbom` in the manual signing flow.
- Added `/licenses` and `/notices` conventions in images; seeded curated license texts and best-effort notices.
- Added `minisign` to `goneat-tools` image.
- Added ADR-0003 documenting the license/notice approach.

## [0.1.5] - 2025-12-10

- Added `scripts/validate-pins.sh` and `make validate-pins`; `make quality` now fails if Dockerfiles drift from `manifests/tools.json`.
- Expanded `test-sbom-tools` to exercise jq/yq/git presence plus syft→grype→trivy fixture scans.
- Fixed minisign public key export to use 0644 perms; `bootstrap` now requires jq for validation tooling.

## [0.1.4] - 2025-12-09

- Added jq, yq-go, and git to sbom-tools image for CI workflow support.
- Improved release-digests target to auto-fetch and display digests.
- Updated RELEASE_CHECKLIST.md with env vars (PGP_KEY_ID, MINISIGN_KEY) for easier copy-paste.

## [0.1.3] - 2025-12-08

- Added trivy v0.68.1 to sbom-tools image (SBOM + vuln + config scanning).
- Added curl to both images for CI workflows (MIT-like license).
- Added manual signing workflow scripts and Makefile targets.
- Updated RELEASE_CHECKLIST.md with 3-phase signing workflow.
- Replaced docker build --check with trivy config in lint-dockerfiles.
- Added non-root USER to both images (security hardening).
- v0.1.2 artifacts manually signed (cosign keyless + GPG + minisign).

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

[Unreleased]: https://github.com/fulmenhq/fulmen-toolbox/compare/v0.1.6...HEAD
[0.1.6]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.6
[0.1.5]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.5
[0.1.4]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.4
[0.1.3]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.3
[0.1.2]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.2
[0.1.1]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.1
[0.1.0]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.1.0
