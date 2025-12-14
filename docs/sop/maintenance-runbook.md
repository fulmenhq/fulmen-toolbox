# SOP: Maintenance Runbook (Pins, Packages, Licenses)

This runbook covers routine maintenance tasks for Fulmen Toolbox images: bumping pinned versions, adding/removing packages/tools, baseline profile updates, and license/notice hygiene.

## Principles

- **Manifests are SSOT**
  - Tool payload + pins: `manifests/tools.json`
  - Baseline profiles: `manifests/profiles.json`
- **Non-root by default**: do not rely on installing packages at runtime.
- **Copyleft is a policy decision**: runner images can include copyleft by design; slim images should avoid adding runner baseline packages.
- **Licenses/notices are part of the deliverable**: changes that add new third-party software must update `/licenses`/`/notices` behavior.

## Routine Tasks

### 1) Bump a pinned tool version

1. Update `manifests/tools.json` entry for the tool/version.
2. Update the corresponding Dockerfile ARG and/or install command.
3. Run:
   - `make validate-manifest`
   - `make validate-pins`
   - `make validate-profiles`
   - `make validate-licenses`
4. Build + test locally:
   - `make build-goneat-tools-runner && make test-goneat-tools-runner`
   - `make build-goneat-tools-slim && make test-goneat-tools-slim`
   - `make build-sbom-tools-runner && make test-sbom-tools-runner`
   - `make build-sbom-tools-slim && make test-sbom-tools-slim`
5. Update `CHANGELOG.md` and release notes as needed.

### 2) Add a new tool (Go/npm/GitHub binary)

1. Add a new entry in `manifests/tools.json`:
   - `name`, `version`, `source`, `images` (choose `*-slim` and/or `*-runner`)
2. Implement installation in the appropriate Dockerfile stage:
   - Prefer adding to `slim` payload (if it’s truly part of the tool image purpose)
   - Only add to `runner` if it’s baseline runner functionality
3. **License/notice requirements** (ADR-0003, ADR-0005):
   - Ensure license text is available in-image under `/licenses/...`
   - For curated tools, set `license_spdx` and `license_path` (or `license_paths`) in `manifests/tools.json`
   - If upstream requires attribution, set `notice_required: true` and `notice_path`, and ensure it exists under `/notices/...`
4. Validate:
   - `make validate-manifest && make validate-pins && make validate-profiles`
   - Local build/test for the affected image(s)

### 3) Add a new runner baseline package

1. Update `manifests/profiles.json` (`profiles.runner_baseline.packages`).
2. Update `docs/sop/runner-baseline.md` rationale table.
3. Update Dockerfiles:
   - ensure `runner` stage installs the new package
   - ensure `slim` stages do not
4. Run:
   - `make validate-profiles`
   - Full local build/test for runner + slim

Copyleft note:
- If the new baseline package is copyleft (especially GPLv3), record it in docs and get maintainer approval before merging.

### 4) Remove a tool or package

1. Remove it from the manifest (`manifests/tools.json` or `manifests/profiles.json`).
2. Remove install steps from Dockerfiles.
3. Check for any references in docs and tests.
4. Run the validation suite and tests.

## License/Notice Audit Approach (Current)

We currently treat license/notice content as **best-effort but enforced for curated top-level tools**.

### Enforced today

- Image contains `/licenses` and `/notices` directories.
- For curated top-level tools (e.g. `minisign`, `syft`, `grype`, `trivy`) we explicitly place license texts under `/licenses/github/...` and assert their presence in `make test-*`.
- For apk packages, we copy `/usr/share/licenses` into `/licenses/alpine` when available.

### Manual reviewer checklist for any new tool/package

- Confirm the tool’s license is captured in `/licenses/...` under ADR-0003 paths.
- If upstream publishes NOTICE/attribution, ensure it’s captured under `/notices/...`.
- Ensure the tool is pinned (version/digest).
- Ensure the install method is deterministic.

### Planned improvements (recommended next step)

- Extend `manifests/tools.json` with optional fields:
  - `license_spdx`, `license_source`, `license_path`, `notice_required`
- Add `scripts/validate-licenses.sh` to:
  - build the image (single-arch) and assert expected `/licenses/...` and `/notices/...` paths exist
  - optionally cross-check SBOM-derived license identifiers as a warning signal

See `docs/adr/ADR-0003-licenses-and-notices.md` and `.plans/active/v0.2.0/manifest-license-metadata-reference.md` for the detailed proposal.
