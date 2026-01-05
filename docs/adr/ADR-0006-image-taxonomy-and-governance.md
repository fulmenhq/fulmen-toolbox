# ADR-0006-image-taxonomy-and-governance

- Status: Proposed
- Date: 2026-01-05

## Context

`fulmen-toolbox` publishes multiple Docker image families (toolboxes today; applications/services next).

As the catalog grows (AuthentiK, Mattermost, Valkey/Redis, devops agents/scrapers, etc.), we need:

- A **parsable, stable tag taxonomy** that prevents combinatoric tag sprawl.
- Clear rules for **canonical tags vs aliases** (including a transition plan).
- Governance preventing “arbitrary” image changes (especially packages) that create drift and surprise.

The repo already established:

- Versioning and release conventions (ADR-0001).
- Runner vs slim patterns for tool images.
- Baseline profiles as SSOT for packages (`manifests/profiles.json`).

We are expanding into application/service images, which introduces new scopes (`server`, `harness`) and new composition needs (external vs bundled dependencies).

## Decision

### 1) Canonical tag format (effective v0.3.0)

For new and updated images, canonical tags MUST include the libc dimension:

```
<tag-prefix>-<scope>-<libc>[-<suffix>][-<arch>]
```

Where:

- `tag-prefix`: externally visible family name (may include hyphens).
- `scope`: one of:
  - tool images: `runner`, `slim`
  - application/service images: `server`, `harness`
- `libc`: `musl` or `glibc`
- `suffix`: optional; only from an allowlist (see below)
- `arch`: optional; `amd64` or `arm64` when publishing single-arch manifests (multi-arch is the default)

### 2) Aliases are allowed but time-boxed

To preserve consumer compatibility during the transition, we MAY publish aliases that omit the libc dimension.

- These aliases are temporary and MUST be removed no later than the next minor release after v0.3.0 (i.e., by v0.4.0).
- Bare family tags (e.g., `goneat-tools`) remain aliases only when explicitly documented.

### 3) Suffix governance (no tag sprawl)

`suffix` exists to support rare, cross-cutting discriminators (e.g., compliance/debug).

- By default, canonical tags should have **no suffix**.
- If a suffix is needed, it MUST be selected from an allowlist maintained in repository standards.
- Adding a new suffix token requires updating the standards doc (and any schema/validation that enforces the allowlist).

### 4) No arbitrary packages

Images MUST NOT introduce arbitrary packages.

- Packages MUST come from a baseline profile in `manifests/profiles.json`, or be part of a curated, manifest-tracked component/tool payload.
- If a new baseline capability is required, the correct workflow is to update profiles + docs (and accept the licensing implications), not to add packages ad-hoc in Dockerfiles.

### 5) Manifest ID rules (machine-parsable)

Internal manifest keys/IDs MUST be easy to parse:

- IDs in SSOT manifests (e.g., `apps.<id>`) MUST be free of hyphens and underscores.
- The externally visible tag namespace is provided separately as `tag_prefix`.

## Consequences

- v0.3.0 introduces fully-qualified canonical tags (`*-<scope>-<libc>`). Existing short tags become explicit aliases.
- Catalog growth remains manageable because:
  - `scope` remains a small, stable enum
  - `suffix` is controlled and rare
- The baseline-profile model becomes the only supported mechanism for package additions.

## Alternatives Considered

- Keep implicit libc defaults forever (e.g., `*-runner` implies musl): rejected; it is ambiguous and scales poorly.
- Encode many feature flags into tags: rejected; leads to combinatoric tag sprawl.
- Multiple repos per family: deferred; one repo is acceptable with schema-backed SSOT and consistent documentation patterns.
