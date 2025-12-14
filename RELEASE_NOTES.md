# Release Notes

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

## v0.1.4 (2025-12-09)

**sbom-tools CI Workflow Support**

- Added jq 1.7.1, yq-go 4.44.5, git 2.47.3 to sbom-tools image
- Enables JSON/YAML processing and repo cloning in CI jobs
- Supports both "CI container" and "local tool substitute" use cases

**DX Improvements**

- `release-digests` now auto-fetches and displays image digests with ready-to-copy cosign commands
- RELEASE_CHECKLIST.md updated with `PGP_KEY_ID` and `MINISIGN_KEY` env vars
- Backslash line continuations for easier copy-paste

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
