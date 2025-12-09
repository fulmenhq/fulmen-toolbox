# Release Notes

## v0.1.4 (2025-12-09)

**sbom-tools CI Workflow Support**

- Added jq 1.7.1, yq-go 4.44.5, git 2.47.3 to sbom-tools image
- Enables JSON/YAML processing and repo cloning in CI jobs
- Supports both "CI container" and "local tool substitute" use cases

**DX Improvements**

- `release-digests` now auto-fetches and displays image digests with ready-to-copy cosign commands
- RELEASE_CHECKLIST.md updated with `PGP_KEY_ID` and `MINISIGN_KEY` env vars
- Backslash line continuations for easier copy-paste

**Image Updates**

- sbom-tools: added jq, yq-go, git (~345MB)
- goneat-tools: unchanged

## v0.1.3 (2025-12-08)

**Trivy Integration**

- Added trivy v0.68.1 to sbom-tools image
- Provides alternative SBOM/vuln workflow to Syft/Grype
- Enables Dockerfile config scanning for best practices

**Manual Signing Workflow**

- New scripts: `release-download.sh`, `release-upload.sh`, `verify-public-key.sh`
- New Makefile targets: `release-download`, `release-digests`, `release-upload`, `verify-release-key`
- Updated RELEASE_CHECKLIST.md with 3-phase workflow (automated/interactive/automated)
- v0.1.2 artifacts signed: cosign keyless + GPG + minisign

**Security Hardening**

- Both images now run as non-root users (security best practice)
- goneat-tools: `node` (uid 1000)
- sbom-tools: `tooluser` (uid 1000)
- Dockerfile lint uses trivy config (replaces docker build --check)

**Image Updates**

- sbom-tools: syft v1.18.1, grype v0.86.1, trivy v0.68.1, curl 8.14.1 (~340MB)
- goneat-tools: added curl 8.17.0, non-root USER (~362MB)

## v0.1.2 (2025-12-08)

**New Image: sbom-tools**

- syft v1.18.1 (SBOM generation, CycloneDX/SPDX)
- grype v0.86.1 (vulnerability scanning)
- Base: alpine:3.21 (multi-arch)

**Release Workflow**

- Matrix build: goneat-tools + sbom-tools in parallel
- Dockerfiles are SSOT for versions
- Per-image artifacts: `sbom-{image}-{version}.json`, `SHA256SUMS-{image}`

**Makefile Improvements**

- `build-all`, `test-all`: build/test all images
- `check-clean`: fail if working tree dirty
- `lint-dockerfiles`: syntax validation (docker build --check)
- `prepush`: validates all images before push

## v0.1.1 (2025-12-07)

- Release workflow added (tag-driven build/push, SBOM generation, optional signing/attestations guarded by secrets).
- Docs updated for CI strategy; version bump script fixed.

## v0.1.0 (2025-12-07)

- Initial repo scaffold and `goneat-tools` image draft.
- Added versioning helpers (`VERSION`, bump script, Make targets).
- Documented release checklist, signing/attestation plan, and ADRs.

Verification (planned):

- Pull by digest: `docker pull ghcr.io/fulmenhq/goneat-tools@sha256:<digest>`
- Cosign verify: `cosign verify ghcr.io/fulmenhq/goneat-tools@sha256:<digest>`
- Check checksums: `sha256sum --check SHA256SUMS` then verify `SHA256SUMS.asc` and `SHA256SUMS.minisig`.
