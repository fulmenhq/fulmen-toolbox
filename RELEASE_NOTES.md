# Release Notes

## v0.2.3 (2026-01-01)

**Runner Baseline: yamllint**

- Added `yamllint` (and `python3`) to all runner baselines for semantic YAML linting.
- Updated runner tests to validate `yamllint` presence and ensure slim variants stay minimal.
- Documented yamllint rationale and runner baseline guidance.
- CI cosign signing now reads the image list from the manifest to avoid hardcoded drift.

## v0.2.2 (2025-12-31)

**Glibc Runner Variants + CGO Support**

- Added `goneat-tools-runner-glibc` and `sbom-tools-runner-glibc` for glibc-based CI jobs.
- Introduced an apt-based runner baseline profile that includes build tooling (`gcc`, `libc6-dev`, `pkg-config`).
- Added build tools to the musl runner baseline (`build-base`, `pkgconf`) so CGO workflows can run without root installs.
- Pinned bookworm base image digests for glibc variants.
- Documented multi-arch tagging, alias taxonomy, and Apple Silicon guidance for runners.
- Bumped `goneat` to v0.4.0 and `sfetch` to v0.2.9.

## v0.2.1 (2025-12-15)

**GHCR Auth: Prefer `GITHUB_TOKEN`**

- CI workflows now use `github.token` for GHCR login by default.
- Docs clarify CI vs local auth:
  - CI publishing: `GITHUB_TOKEN` with workflow `permissions: packages: write`
  - Local verification/troubleshooting: packages-only classic PAT
- Added a fallback SOP for a dedicated GHCR bot + packages-only classic PAT.
