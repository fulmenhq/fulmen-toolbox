# Release Checklist

This is the SOP for publishing a new `fulmen-toolbox` release (semver-driven).

## Pre-flight
- Confirm working tree clean and CI green.
- Ensure `VERSION` reflects the intended semver (`make bump-*` to adjust).
- Update `CHANGELOG.md` and `RELEASE_NOTES.md` with the release entry.
- Sync pins: update `manifests/tools.json`, Dockerfile ARGs, and `docs/images/goneat-tools.md`.
- Run local checks: `make precommit` (manifest + workflows lint) and `make prepush` (quality + build + test).
- Validate docs reflect current tooling (inventory, architecture, ADRs).

## Build & Verify
- Build multi-arch image: `make build-goneat-tools-multi` (or tag-driven CI release workflow).
- Smoke test image: `make test-goneat-tools`.
- Capture image digest(s) from the build output (needed for SHA256SUMS and signing).
- Generate SBOM (syft) for the digest.

## Sign & Attest
- Sign image digest with cosign (keyless preferred; fallback FulmenHQ key).
- Attach attestations: provenance (SLSA) + SBOM.
- Produce `SHA256SUMS` with digests for all pushed tags.
- Sign `SHA256SUMS` with Fulmen GPG key AND minisign.
- Store SBOM + signatures as release assets; publish digest in release notes.
 - If secrets are not configured, perform signing manually after release artifacts are produced.

## Publish
- Push image tags (`:latest`, `:v<major>`, and semver tag). CI release workflow handles tagged pushes.
- Tag repo: `git tag v$(cat VERSION)`; `git push origin --tags`.
- Upload SBOM, `SHA256SUMS`, `.asc`, and `.minisig` to the GitHub Release (CI does this).
- Document verification commands in `RELEASE_NOTES.md`.

## Post-release
- Bump `VERSION` to next `-dev`? (if/when adopted).
- Open follow-up issue/PR for dependency/tool bumps if needed.
