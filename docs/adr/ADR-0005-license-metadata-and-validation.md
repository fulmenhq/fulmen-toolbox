# ADR-0005-license-metadata-and-validation

- Status: Accepted
- Date: 2025-12-14

## Context

Fulmen Toolbox images distribute curated third-party tools. Consumers (and internal maintainers) need a reliable way to audit licensing and required attributions without relying solely on SBOM tooling or manual inspection.

ADR-0003 established standardized in-image paths for license texts and notices:

- `/licenses/...`
- `/notices/...`

However, enforcement was largely manual and ad-hoc (tests asserted only a handful of license files).

## Decision

1. Extend `manifests/tools.json` (SSOT) with optional license metadata fields for curated, top-level tools:

   - `license_spdx`: SPDX expression (e.g. `MIT`, `Apache-2.0`, `Apache-2.0 OR MIT`)
   - `license_source`: where the license text is expected to come from (`apk`, `gomodcache`, `npm`, `upstream-url`, `manual`)
   - `license_path`: a single required in-image path for the license text
   - `license_paths`: multiple required in-image paths (for dual/multi-license projects)
   - `notice_required`: whether a NOTICE file is required
   - `notice_path`: required NOTICE path when `notice_required: true`
   - `copyleft`: optional boolean disclosure for curated tools (informational)

2. Add automated verification:

   - `scripts/validate-licenses.sh` builds each supported image variant and asserts the declared license/notice paths exist.
   - The check is exposed as `make validate-licenses`.
   - CI runs `make validate-licenses` as part of the manifest validation workflow.

3. Scope of enforcement:

   - We only enforce license/notice presence for tools that explicitly declare `license_path`/`license_paths`.
   - This is intentionally limited to curated, top-level tools we intentionally ship (not transitive dependencies).

## Rationale

- Keeps the repo DRY by making `manifests/tools.json` the SSOT for both pins and compliance expectations.
- Provides a deterministic, offline-inspectable compliance artifact in each image.
- Avoids over-claiming completeness for all transitive dependencies while still enforcing correctness for the curated toolset.

## Consequences

- Adding a new curated tool requires adding corresponding license metadata and ensuring the Dockerfile places license texts at the declared paths.
- Dual-licensed tools should use `license_paths` and an SPDX expression like `Apache-2.0 OR MIT`.
- Some tool ecosystems do not publish NOTICE files consistently; we only enforce NOTICE when explicitly marked required.

## References

- ADR-0003: licenses and notices paths
- `docs/sop/licenses-and-notices.md`
- `docs/sop/maintenance-runbook.md`
