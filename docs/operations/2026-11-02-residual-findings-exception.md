---
title: Residual HIGH/CRITICAL findings in upstream tool binaries (v0.5.15)
date: "2026-11-02"
updated: "2026-11-10"
approved_by: "@3leapsdave"
recheck: "2026-11-16"
---

# Residual HIGH/CRITICAL findings in upstream tool binaries

This is not a cooling exception. The findings remain because the newest upstream release of each tool still ships the vulnerable dependency or was built with an older Go toolchain, or because the only fixed package is inside the 7-day cooling window. The images do not rebuild these tools from source.

Approved 2026-11-10 by @3leapsdave for v0.5.15, until the 2026-11-16 recheck.

Source of the findings: `trivy image` with no `.trivyignore`, HIGH and CRITICAL, today's vulnerability DB, run on 2026-11-10 against the images built for v0.5.15. Debian base-image packages with no fixed version are not listed; the scheduled CVE scan (`ignore-unfixed`) does not count them.

## Carriers

| Tool  | Pinned version | Newest upstream release | Images                                                                                                                               | Path in image          |
| ----- | -------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ---------------------- |
| syft  | v1.56.0        | v1.57.1 (2026-11-09)    | `sbom-tools-slim-musl`, `sbom-tools-runner-musl`, `sbom-tools-runner-glibc`, `goneat-tools-runner-musl`, `goneat-tools-runner-glibc` | `/usr/local/bin/syft`  |
| grype | v0.121.1       | v0.121.3 (2026-11-09)   | same as syft                                                                                                                         | `/usr/local/bin/grype` |
| trivy | v0.76.1        | v0.76.2 (2026-11-05)    | `sbom-tools-slim-musl`, `sbom-tools-runner-musl`, `sbom-tools-runner-glibc`                                                          | `/usr/local/bin/trivy` |
| yq    | v4.53.3        | v4.54.3 (2026-11-09)    | `goneat-tools-runner-glibc`, `sbom-tools-runner-glibc`                                                                               | `/usr/local/bin/yq`    |
| zlib  | 1.3.2-r0       | 1.4-r0 (2026-11-06)     | `goneat-tools-slim-musl`, `goneat-tools-runner-musl`                                                                                 | Alpine package         |

The musl sbom-tools images use the Alpine 3.21 `yq-go` package, which has no findings.

## Remaining findings

| Tool  | Finding                                                                                                                                                                                                         | Component and installed version | Fixed in                         |
| ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- | -------------------------------- |
| syft  | CVE-2026-78661                                                                                                                                                                                                  | golang.org/x/net v0.61.0        | v0.62.0                          |
| grype | CVE-2026-78661                                                                                                                                                                                                  | golang.org/x/net v0.61.0        | v0.62.0                          |
| grype | CVE-2026-41567, CVE-2026-42306                                                                                                                                                                                  | docker/docker v28.5.2           | no fixed version published       |
| trivy | CVE-2026-116587                                                                                                                                                                                                 | go-jose/v4 v4.1.5               | v4.1.6                           |
| trivy | CVE-2026-78661                                                                                                                                                                                                  | golang.org/x/net v0.60.0        | v0.62.0                          |
| yq    | CVE-2026-46600, CVE-2026-78661, CVE-2026-78669                                                                                                                                                                  | golang.org/x/net v0.55.0        | v0.56.0, v0.62.0, v0.60.0        |
| yq    | CVE-2026-56851, CVE-2026-56852                                                                                                                                                                                  | golang.org/x/text v0.37.0       | v0.41.0, v0.39.0                 |
| yq    | CVE-2026-111943, CVE-2026-33818, CVE-2026-39821, CVE-2026-39822, CVE-2026-46600, CVE-2026-56853, CVE-2026-56858, CVE-2026-56859, CVE-2026-56860, CVE-2026-56862, CVE-2026-78667, CVE-2026-78669, CVE-2026-97031 | Go stdlib go1.26.4              | go1.26.10 or earlier patch lines |
| zlib  | CVE-2026-85091                                                                                                                                                                                                  | zlib 1.3.2-r0 (Alpine 3.24)     | 1.4-r0                           |

The two docker/docker findings have no fixed version, so the scheduled CVE scan does not count them. CVE-2026-34040 (docker/docker, fixed in 29.3.1) is waived in `.trivyignore`; grype v0.121.1 still vendors v28.5.2. CVE-2026-39822 and CVE-2026-56852 are also waived in `.trivyignore`.

## Cleared since the 2026-11-02 scan

- syft v1.56.0 and grype v0.121.1 are built with go1.27.3 and use go-jose v4.1.6. Their Go standard-library findings (CVE-2026-111943, CVE-2026-78667, CVE-2026-78669, CVE-2026-97031) and CVE-2026-116587 are cleared.
- `musl` and `musl-utils` 1.2.6-r3 are pinned in the goneat musl images (CVE-2026-107891, built 2026-10-21).
- `apt` and `libapt-pkg6.0` 2.6.2 are pinned in both glibc runners (CVE-2026-109518, DSA-6607-1, 2026-11-02).

## Why the newest upstream release still carries them

- **syft and grype**: CVE-2026-78661 (golang.org/x/net/html) was published 2026-10-27 with the fix in x/net v0.62.0. syft v1.56.0 and grype v0.121.1 use v0.61.0. syft v1.57.1 and grype v0.121.3 select x/net v0.62.0, and grype v0.121.3 no longer depends on docker/docker; both are inside the cooling window until 2026-11-16.
- **trivy v0.76.1** is built with go1.27.3, so its stdlib findings are clear. It pins go-jose v4.1.5 and x/net v0.60.0. trivy v0.76.2 (2026-11-05) is inside the cooling window.
- **yq v4.53.3** is the pinned release binary, built with go1.26.4. Newer yq releases are built with newer Go and x/net but have not been reassessed for this release; the pin stays at v4.53.3.
- **zlib**: Alpine 3.24 ships the fix only as zlib 1.4-r0, a minor-version bump built 2026-11-06, inside the cooling window. It can be pinned after 2026-11-13.

No self-builds: these tools stay on the upstream release binaries.

## Recheck

Recheck date: 2026-11-16. Then:

1. Check for syft, grype, trivy and yq releases newer than the pins above, and for Alpine zlib 1.4-r0 leaving the cooling window.
2. If a release clears its findings and is outside the 7-day cooling window, take it and rescan.
3. Rescan every image with no `.trivyignore` and update this document, or remove it when no fixable HIGH/CRITICAL findings remain.
