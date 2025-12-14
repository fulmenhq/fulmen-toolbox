# ADR-0004-copyleft-and-runner-images

- Status: Proposed
- Date: 2025-12-14

## Context

Fulmen Toolbox images are used in CI-like contexts and are increasingly treated as “general-purpose runners” rather than single-purpose tool containers.

General-purpose runners typically need a baseline userland (e.g., `bash`, `git`, `make`, `tar`, `gzip`, `coreutils`) that is commonly provided by GNU projects. Many of these components use copyleft licenses (GPLv2/GPLv3).

Separately, the project already standardized in-image locations for license texts and notices (ADR-0003).

## Decision

1. Fulmen Toolbox images MAY include copyleft-licensed tools when needed for runner usability.
2. When copyleft-licensed tools are included, we treat them as **mere aggregation**:
   - They are distributed as separate executables.
   - We do not link proprietary code into GPL libraries as part of the image.
   - We do not vendor/copy GPL code into proprietary source trees.
3. We will follow best practices to make compliance straightforward:
   - Provide license texts and required attributions inside the image under the ADR-0003 paths (`/licenses/*` and `/notices/*`).
   - Document copyleft presence in per-image documentation (e.g. `images/<image>/README.md`) and/or `docs/images/<image>.md`.
   - Maintain SBOMs and checksums as part of releases.
4. We plan to support multiple image “flavors” when it helps downstream consumers:
   - **runner**: includes baseline runner userland (may include copyleft)
   - **slim**: avoids the runner baseline and strives to minimize copyleft components (best-effort; not a guarantee)

## Rationale

- The primary value of these images is to behave reliably as CI runners.
- Excluding all copyleft components would require extensive substitutions and still may not meet user expectations.
- Making licensing discoverable in-image (ADR-0003) reduces audit friction.

## Consequences

- We must explicitly track and disclose copyleft components in runner images.
- Downstream consumers embedding Fulmen Toolbox images into commercial products should align with their own compliance processes.
- “Slim” images (if/when provided) require additional maintenance and user education.

## Implementation Notes

- Runner-baseline package guidance is documented in `docs/sop/runner-baseline.md`.
- License/notice collection process is documented in `docs/sop/licenses-and-notices.md`.

## Alternatives Considered

- Avoid copyleft entirely: not practical for a runner-focused baseline and risks unpredictable breakage.
- Move to Debian/Ubuntu base: changes compatibility surface; does not eliminate copyleft for runner baselines.
