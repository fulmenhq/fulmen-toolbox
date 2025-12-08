# ADR Index

Purpose: record decisions for fulmen-toolbox with clear status and discoverability.

## How to ADR
- Create a new file in `docs/adr/` named `ADR-XXXX-title-slug.md` (zero-padded).
- Use `docs/adr/template.md`.
- Set status (`Proposed`, `Accepted`, `Superseded`, `Rejected`) and date.
- Keep it concise: context, decision, consequences, alternatives (brief).
- Link related ADRs and issues/PRs.

## ADRs
- ADR-0001-versioning — Accepted — Semver as primary, VERSION SSOT, optional calver alias.
- ADR-0002-signing-and-attestation — Accepted — Cosign signatures/attestations + GPG/minisign checksums.
