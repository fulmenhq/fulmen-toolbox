# Release Notes

## v0.2.2 (2025-12-31)

**Glibc Runner Variants + CGO Support**

- Added `goneat-tools-runner-glibc` and `sbom-tools-runner-glibc` for glibc-based CI jobs.
- Introduced an apt-based runner baseline profile that includes build tooling (`gcc`, `libc6-dev`, `pkg-config`).
- Added build tools to the musl runner baseline (`build-base`, `pkgconf`) so CGO workflows can run without root installs.
- Pinned bookworm base image digests for glibc variants.
- Documented multi-arch tagging, alias taxonomy, and Apple Silicon guidance for runners.
- Bumped `goneat` to v0.3.25 and `sfetch` to v0.2.9.

## v0.2.1 (2025-12-15)

**GHCR Auth: Prefer `GITHUB_TOKEN`**

- CI workflows now use `github.token` for GHCR login by default.
- Docs clarify CI vs local auth:
  - CI publishing: `GITHUB_TOKEN` with workflow `permissions: packages: write`
  - Local verification/troubleshooting: packages-only classic PAT
- Added a fallback SOP for a dedicated GHCR bot + packages-only classic PAT.

## v0.2.0 (2025-12-14)

**Variant Split + Compliance Automation**

- Images now publish explicit variants: `goneat-tools-{slim,runner}` and `sbom-tools-{slim,runner}`.
- Bare names remain compatibility aliases for runner:
  - `goneat-tools:*` → `goneat-tools-runner:*`
  - `sbom-tools:*` → `sbom-tools-runner:*`

**Baseline profiles (DRY + enforceable)**

- Added schema-driven baseline profiles in `manifests/profiles.json`.
- `make validate-profiles` enforces that runner baseline packages are present in `-runner` and do not leak into `-slim`.

**Licenses & notices (manifest-driven)**

- Tool manifest now optionally declares `license_spdx` plus required in-image `license_path`/`license_paths`.
- Added `make validate-licenses` to build images and assert curated license/notice paths exist (ADR-0005).
- Enforced NOTICE where explicitly required (e.g. Trivy NOTICE; goneat NOTICE).

**DX tools in goneat-tools**

- Added `goneat` v0.3.20 and `sfetch` v0.2.7 to the goneat-tools payload (both `-slim` and `-runner`).
