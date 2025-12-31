# Image Tag Taxonomy

This document defines how Fulmen Toolbox image tags are structured and how aliases map to canonical images.

## Dimensions

We use a four-part structure for tag names:

```
<family>-<scope>-<libc>-<arch>
```

- **family**: image family (e.g., `goneat-tools`, `sbom-tools`)
- **scope**: `runner` or `slim`
- **libc**: `musl` (default) or `glibc`
- **arch**: `amd64` or `arm64` (omitted for multi-arch)

We also publish distro aliases that map to libc:

- `musl` == `alpine`
- `glibc` == `debian`

Not all dimensions appear in canonical tags (to preserve existing names). Canonical tags are short; aliases expand the dimensions for clarity. The default interpretation is musl + multi-arch when libc/arch are omitted.

## Canonical Tags (Published)

- `goneat-tools-runner` (musl/Alpine)
- `goneat-tools-slim` (musl/Alpine)
- `goneat-tools-runner-glibc` (glibc/Debian)
- `sbom-tools-runner` (musl/Alpine)
- `sbom-tools-slim` (musl/Alpine)
- `sbom-tools-runner-glibc` (glibc/Debian)

## Why No `-slim-glibc`?

`-slim` targets local, minimal tool replacement where glibc doesn’t add value without the runner baseline. Glibc variants are intentionally paired with `-runner` for CGO and system-library workflows that need build tools and baseline utilities.

## Alias Rules (Published)

Aliases make libc/distro explicit and pair `musl<->alpine` and `glibc<->debian`:

- `*-runner-musl` == `*-runner-alpine` == `*-runner`
- `*-slim-musl` == `*-slim-alpine` == `*-slim`
- `*-runner-glibc` == `*-runner-debian`

Bare family tags remain compatible aliases for the musl runner:

- `goneat-tools` → `goneat-tools-runner`
- `sbom-tools` → `sbom-tools-runner`

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
