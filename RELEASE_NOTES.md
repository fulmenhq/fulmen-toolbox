# Release Notes

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
