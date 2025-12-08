# fulmen-toolbox Architecture

## Repository Layout
- `images/` – one folder per image (`goneat-tools`, `sbom-tools`).
- `Makefile` – local build/test helpers for all images.
- `scripts/` – repo-level utilities (version bumping, release plan).
- `VERSION` – single source of truth for semver.
- `.plans/` – vision/bootstrap docs (internal).

## Build & Release Flow (desired state)
1. Bump `VERSION` (`make bump-*`).
2. Run precommit/push checks (`make precommit`, `make prepush`).
3. Build multi-arch image (`make build-goneat-tools-multi` or CI).
4. Smoke test (`make test-goneat-tools`).
5. Generate SBOM (syft) for the pushed digest.
6. Sign with cosign; attach provenance + SBOM attestations.
7. Produce `SHA256SUMS` for digests; sign with GPG + minisign.
8. Publish tags (`:latest`, `:v<major>`, `:<semver>`) and release artifacts.

## CI/CD Strategy
- PR/main: verification only (manifest validation, workflow lint, optional local build smoke).
- Tags (`v*.*.*`): build-and-push multi-arch image, attach signatures/attestations (future), publish release artifacts.
- Manual `workflow_dispatch` available for build/publish when needed.

## Versioning Strategy
- Primary: semver. Major = breaking defaults/tool changes; Minor = additive tools/options; Patch = rebuilds/security/tool bumps with no breaking defaults.
- Optional alias: calver tag for freshness (does not replace semver).
- `VERSION` file is the SSOT; Docker tags derive from it.
- Tool manifest: `manifests/tools.json` validated by JSON Schema (`schemas/tool-manifest.schema.json`).
- Schema IDs target `https://schema.fulmenhq.dev/...` and can be upstreamed to Crucible when ready.
- Current baseline: v0.1.1 (pre-release; signing/attestations pending).

## Signing & Attestation Strategy
- Cosign signatures on image digests (keyless preferred; FulmenHQ key fallback).
- Cosign attestations: SLSA provenance + SBOM.
- Out-of-band verification: `SHA256SUMS` signed with GPG + minisign.
- Verification guidance lives in `RELEASE_NOTES.md`.
- Release workflow: tag-driven (`v*.*.*`) job builds multi-arch, signs image with cosign, attaches SBOM attestation, signs `SHA256SUMS` (GPG + minisign), and uploads artifacts to the GitHub Release.

## Tooling Expectations
- Minimal host deps: docker + buildx, cosign, gpg, minisign, syft.
- Shell scripts (linted with shellcheck, formatted with shfmt) to avoid heavier runtimes.
