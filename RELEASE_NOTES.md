# Release Notes

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

## v0.1.6 (2025-12-13)

**Minisign in goneat-tools + License Transparency**

- goneat-tools: added `minisign` (requested by users) and pinned it in `manifests/tools.json`.
- Both images now expose `/licenses/` and `/notices/` with curated license texts for bundled tools (plus best-effort package-manager license copying).
- Added ADR-0003 and SOP documentation for how licenses/notices are collected and where they live.

**Release Process DX**

- `make release-sign` now covers cosign sign + SBOM attest + OCI-attached SBOM publish (`cosign attach sbom`), plus GPG/minisign checksum signatures.
- Added `GPG_HOMEDIR` support for maintainers with multiple GPG keyrings.
- Added optional `make release-notes` staging and updated `release-upload` to upload notes when present.
