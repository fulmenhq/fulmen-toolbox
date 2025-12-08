# ADR-0002-signing-and-attestation

- Status: Accepted
- Date: 2025-12-07

## Context
Consumers need assurance that FulmenHQ built and published images and that they have not been tampered with. Some workflows rely on key-based verification; others prefer modern attestations.

## Decision
- Sign container digests with cosign (keyless OIDC preferred; FulmenHQ signing key as fallback).
- Attach attestations for provenance (SLSA) and SBOM (SPDX/CycloneDX) via cosign.
- Publish `SHA256SUMS` for pushed tags and sign them with both GPG (Fulmen key) and minisign.
- Document verification commands in release artifacts and README/notes.

## Consequences
- Consumers can verify via cosign (attestations + signatures) or via signed checksum files.
- CI must provision cosign, gpg, minisign, and syft; secrets/keys must be managed securely.
- Releases should always surface digests to enable `@sha256:` pinning in downstream configs.
