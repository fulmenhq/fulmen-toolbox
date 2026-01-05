# Image Tag Taxonomy

This document defines how Fulmen Toolbox image tags are structured and how aliases map to canonical images.

## Dimensions

We use a controlled, parseable structure for tag names:

```
<tag-prefix>-<scope>-<libc>[-<suffix>][-<arch>]
```

- **tag-prefix**: image family namespace (e.g., `goneat-tools`, `sbom-tools`, `authentik`)
- **scope**:
  - tool images: `runner` or `slim`
  - application/service images: `server` or `harness`
- **libc**: `musl` or `glibc`
- **suffix**: optional; from a controlled allowlist (see `docs/standards/image-taxonomy.md`)
- **arch**: `amd64` or `arm64` (omitted for multi-arch)

We also publish distro aliases that map to libc:

- `musl` == `alpine`
- `glibc` == `debian`

Starting in v0.3.0, canonical tags include the libc dimension (e.g., `*-runner-musl`).

During a transition window, we may continue to publish aliases that omit `libc` for compatibility. These aliases are time-boxed and will be removed by the next minor release after v0.3.0.

## Canonical Tags

Canonical tags include the libc dimension.

Tool images (current families):

- `goneat-tools-runner-musl`
- `goneat-tools-slim-musl`
- `goneat-tools-runner-glibc`
- `sbom-tools-runner-musl`
- `sbom-tools-slim-musl`
- `sbom-tools-runner-glibc`

Application/service images (future families):

- `<tag-prefix>-server-glibc`
- `<tag-prefix>-harness-glibc`

## Why No `-slim-glibc`?

`-slim` targets local, minimal tool replacement where glibc doesn’t add value without the runner baseline. Glibc variants are intentionally paired with `-runner` for CGO and system-library workflows that need build tools and baseline utilities.

## Alias Rules

We publish a limited set of aliases for compatibility and readability.

### Distro aliases

- `musl` == `alpine`
- `glibc` == `debian`

Examples:

- `*-runner-musl` == `*-runner-alpine`
- `*-runner-glibc` == `*-runner-debian`

### Compatibility aliases (time-boxed)

For a transition window, we may publish aliases that omit libc:

- `goneat-tools-runner` → `goneat-tools-runner-musl`
- `goneat-tools-slim` → `goneat-tools-slim-musl`
- `sbom-tools-runner` → `sbom-tools-runner-musl`
- `sbom-tools-slim` → `sbom-tools-slim-musl`

Bare family tags remain compatibility aliases only when explicitly documented:

- `goneat-tools` → `goneat-tools-runner-musl`
- `sbom-tools` → `sbom-tools-runner-musl`

## Architecture Suffixes

Default tags are multi-arch and include `linux/amd64` and `linux/arm64`.

Single-arch tags append `-amd64` or `-arm64` to any canonical or alias tag when published.

Examples:

- `goneat-tools-runner-glibc-arm64`
- `sbom-tools-slim-amd64`

Fully-dimensioned examples:

- `goneat-tools-runner-musl` (explicit libc, multi-arch)
- `goneat-tools-runner-musl-amd64` (explicit libc + arch)

See `README.md` for the canonical and alias tables.
