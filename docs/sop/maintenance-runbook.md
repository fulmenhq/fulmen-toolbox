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

## GHCR Package Lifecycle (Variants, Aliases, Retirement)

### Variant packages vs alias packages

In v0.2.x we publish explicit variant packages per family:

- `goneat-tools-runner`, `goneat-tools-slim`
- `sbom-tools-runner`, `sbom-tools-slim`

We also publish compatibility aliases (bare names):

- `goneat-tools:*` aliases to `goneat-tools-runner:*`
- `sbom-tools:*` aliases to `sbom-tools-runner:*`

Operational implication:
- GHCR will show multiple **packages** for the repo (variants + aliases).
- A release should apply tags to all intended package namespaces (canonical variants, plus aliases if we want them).

### Verify tags on packages (recommended)

Requires a classic PAT with `read:packages` scope.

```bash
gh api -H "Accept: application/vnd.github+json" \
  "/orgs/fulmenhq/packages?package_type=container&per_page=100" \
  | jq -r '.[].name'

# Example: confirm v0.2.0 tags on runner variant
gh api -H "Accept: application/vnd.github+json" \
  "/orgs/fulmenhq/packages/container/goneat-tools-runner/versions?per_page=100" \
  | jq -r '.[] | [.id, .created_at, (.metadata.container.tags|join(","))] | @tsv'

# Example: confirm v0.2.0 tag exists on alias package
gh api -H "Accept: application/vnd.github+json" \
  "/orgs/fulmenhq/packages/container/goneat-tools/versions?per_page=100" \
  | jq -r '.[] | select((.metadata.container.tags // []) | index("v0.2.0")) | .metadata.container.tags'
```

### Signaling legacy versions are not active

GitHub Packages does not provide a first-class "deprecated" flag for container packages.

Default approach (Option A):

- Keep legacy tags available.
- Make support status obvious in docs and release notes.
- Prefer explicit `-runner` / `-slim` names in all examples.

Selective cleanup (Option B, maintainer judgment):

- After a stability/grace period (typically a few releases), maintainers may delete legacy **package versions** (e.g. `v0.1.x`) from GHCR.
- Prefer leaving at least one rollback anchor version.

Exceptional cleanup (Option C, incident response):

- Remove an entire GHCR package only for security, assurance/compliance, or operational integrity incidents.
- This is disruptive and may break downstream CI/CD pipelines.

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
