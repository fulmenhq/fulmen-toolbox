# SOP: Licenses and Notices in Fulmen Toolbox Images

Purpose: keep third-party license texts and attribution notices discoverable inside each image.

## Locations in the image

- `/licenses/` — license texts
- `/notices/` — NOTICE/attribution files (when upstream provides them)

### Layout conventions

- GitHub upstream projects:
  - `/licenses/github/<owner>/<repo>/LICENSE`
  - `/notices/github/<owner>/<repo>/NOTICE`
- Alpine packages:
  - `/licenses/alpine/` (copied from `/usr/share/licenses` when present)
- npm global tools:
  - `/licenses/npm/<package>/LICENSE` (best effort, top-level only)

## When adding a tool

1. Add the tool pin to `manifests/tools.json`.
2. Add the tool to the relevant Dockerfile.
3. Ensure the tool’s license text ends up in the image:
   - If installed via `apk`, confirm it appears under `/licenses/alpine/`.
   - If installed via Go module, copy module LICENSE into `/licenses/github/...`.
   - If installed via npm global, copy package LICENSE into `/licenses/npm/...`.
   - If installed from a GitHub release binary, fetch LICENSE from the upstream repo at the pinned tag/version.
4. If the upstream requires an attribution NOTICE, copy it into `/notices/...`.
5. Run `make validate-pins` and image smoke tests (`make test-goneat-tools`, `make test-sbom-tools`).

## Review / audit checklist

- `ls /licenses` and `ls /notices` succeed as the default non-root user.
- License paths match the curated tools we intentionally ship.
- Tool pins are stable and license fetches are pinned to matching tags.
