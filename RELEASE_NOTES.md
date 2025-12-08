# Release Notes

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
