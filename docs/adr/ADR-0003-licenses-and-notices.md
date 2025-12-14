# ADR-0003-licenses-and-notices

- Status: Accepted
- Date: 2025-12-13

## Context

Fulmen Toolbox images curate and distribute third-party tooling (apk packages, Go-built binaries, npm global tools, and GitHub release binaries). Consumers often need to audit licensing and required attributions without chasing upstream repositories or needing a network connection.

Historically we relied on:
- SBOMs generated in CI
- The implicit license metadata inside package managers

…but we didn’t provide a predictable in-image location for license texts or NOTICE files.

## Decision

All Fulmen Toolbox images MUST provide standardized, human-browsable locations for third-party license texts and (when applicable) NOTICE/attribution files.

- License texts live under `/licenses/`
- NOTICE/attribution files live under `/notices/`

### Layout

- GitHub upstream projects: `/licenses/github/<owner>/<repo>/LICENSE`
  - Example: `/licenses/github/jedisct1/minisign/LICENSE`
- Alpine packages (best effort): `/licenses/alpine/` (copied from `/usr/share/licenses` when present)
- npm global installs (best effort, top-level only): `/licenses/npm/<package>/LICENSE`

Corresponding notice locations mirror the same structure:
- `/notices/github/<owner>/<repo>/NOTICE`
- `/notices/alpine/` (reserved)
- `/notices/npm/` (reserved)

### How content gets added

- **apk packages**: copy `/usr/share/licenses` (when present) into `/licenses/alpine/`.
- **Go-installed tools**: copy the module LICENSE from the Go module cache into `/licenses/github/...` during the build.
- **npm global tools**: copy the top-level package LICENSE (when present) into `/licenses/npm/...`.
- **Curated upstream projects** not covered by package managers: fetch LICENSE from the upstream repo at a pinned tag/version and store under `/licenses/github/...`.

### Policy

- This is a transparency mechanism, not a legal guarantee of completeness.
- We prioritize curated, top-level tools (the ones we intentionally ship).
- We avoid GPL tools in these images unless explicitly approved (sidecar pattern preferred).

## Consequences

- Users can inspect licensing offline by running `ls /licenses` and `ls /notices`.
- Image build steps may include additional copying/fetching to stage license texts.
- We must keep license paths aligned with tool pins to avoid drift.

## Alternatives Considered

- **Rely on SBOM only**: good for automation, but not a convenient human workflow and may not include full license texts.
- **Ship a single combined NOTICE file**: harder to maintain, and attribution requirements differ per dependency.
- **Do nothing**: increases friction during audits and weakens supply-chain transparency.
