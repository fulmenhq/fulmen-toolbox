# Image Taxonomy Standard

This standard defines how Fulmen Toolbox image tags, manifests, and documentation stay consistent as the catalog grows.

## Goals

- Make tags easy to parse for humans and automation.
- Keep canonical tags stable.
- Prevent uncontrolled tag proliferation.
- Ensure package/tool drift is caught early (SSOT + validation).

## Dimensions

Canonical tags use the following structure:

```
<tag-prefix>-<scope>-<libc>[-<suffix>][-<arch>]
```

- `tag-prefix`: family name (externally visible; may include hyphens).
- `scope`:
  - Tool images: `slim`, `runner`
  - Application/service images: `server`, `harness`
- `libc`: `musl` or `glibc`
- `suffix`: optional; only from the allowlist below
- `arch`: optional `amd64|arm64` for single-arch publishing (multi-arch is default)

## Canonical vs aliases

- Canonical tags MUST include `libc`.
- Aliases MAY omit `libc` only during an explicit transition window.
- Aliases must be documented and time-boxed.

## Suffix allowlist

Suffix tokens exist for rare, cross-cutting variants.

Allowed suffixes (initial set):

- `debug`
- `fips`

Rule:

- If a new suffix is required, update this file and any schema/validation that enforces it.

## SSOT manifests

The SSOT for catalog metadata is stored in JSON manifests:

- `manifests/tools.json` — tool payload pins + license metadata
- `manifests/profiles.json` — baseline profiles (apk/apt)
- `manifests/apps.json` — application/service catalog (variants, contracts, upstream pins)

## Subsystems

Subsystems are coordinated **multi-container** deployments (Docker Compose + mounted config) stored in-repo under `subsystems/`.

- Subsystems use a per-subsystem `MANIFEST.yaml` (SSOT) validated against `schemas/subsystem-manifest.schema.json`.
- Subsystems are not published as single images; they primarily reference existing images (including fulmen-toolbox images) and provide compose-based fixtures.

Internal IDs must be machine-friendly:

- Manifest keys/IDs MUST match `^[a-z0-9]+$` (no hyphens/underscores).
- External tag namespaces are stored separately as `tag_prefix`.

## “No arbitrary packages” rule

Packages must be introduced via baseline profiles, not ad-hoc Dockerfile installs.

- Add/remove baseline packages only by updating `manifests/profiles.json`.
- Document rationale in the relevant SOP/ADR.

## Taxonomy diagram

```mermaid
graph TD
  subgraph SSOT
    Tools[manifests/tools.json]\n(tool payload)
    Profiles[manifests/profiles.json]\n(baselines)
    Apps[manifests/apps.json]\n(app catalog)
  end

  subgraph Images
    ToolSlim[<tag-prefix>-slim-<libc>]
    ToolRunner[<tag-prefix>-runner-<libc>]
    AppServer[<tag-prefix>-server-<libc>]
    AppHarness[<tag-prefix>-harness-<libc>]
  end

  Tools --> ToolSlim
  Tools --> ToolRunner
  Profiles --> ToolRunner

  Apps --> AppServer
  Apps --> AppHarness
  Profiles --> AppServer
  Profiles --> AppHarness
```

## Examples

Tool images:

- `goneat-tools-slim-musl`
- `goneat-tools-runner-musl`
- `goneat-tools-runner-glibc`

Application images:

- `authentik-server-glibc`
- `authentik-harness-glibc`
- `mattermost-server-glibc`

Single-arch examples (optional):

- `authentik-server-glibc-arm64`

## How to add a new family

1. Choose an internal ID (no hyphens): e.g., `mattermost`.
2. Choose a `tag_prefix`: e.g., `mattermost`.
3. Add SSOT entry (`manifests/apps.json` for apps; `manifests/tools.json` for tools).
4. Add per-image documentation under `docs/images/<tag_prefix>.md`.
5. Add Make targets + validation hooks as needed.
