---
title: Residual HIGH/CRITICAL findings in upstream tool binaries (v0.5.15)
date: "2026-11-02"
approved_by: "pending"
recheck: "2026-11-16"
---

# Residual HIGH/CRITICAL findings in upstream tool binaries

This is not a cooling exception. Every fixed dependency version listed here is older than 7 days. The findings remain because the newest upstream release of each tool still ships the vulnerable dependency or was built with an older Go toolchain. The images do not rebuild these tools from source.

Approval is pending. Until it is recorded in `approved_by`, the findings below are unapproved residuals.

Source of the findings: `trivy image` with no `.trivyignore`, HIGH and CRITICAL, today's vulnerability DB, run on 2026-11-02 against the images built for v0.5.15.

## Carriers

| Tool    | Pinned version | Newest upstream release | Images                                                                                           | Path in image                |
| ------- | -------------- | ----------------------- | ------------------------------------------------------------------------------------------------ | ---------------------------- |
| syft    | v1.55.0        | v1.55.0 (2026-10-19)    | `sbom-tools-slim-musl`, `sbom-tools-runner-musl`, `sbom-tools-runner-glibc`, `goneat-tools-runner-musl`, `goneat-tools-runner-glibc` | `/usr/local/bin/syft`        |
| grype   | v0.121.0       | v0.121.0 (2026-10-19)   | same as syft                                                                                     | `/usr/local/bin/grype`       |
| trivy   | v0.76.1        | v0.76.1 (2026-10-21)    | `sbom-tools-slim-musl`, `sbom-tools-runner-musl`, `sbom-tools-runner-glibc`                      | `/usr/local/bin/trivy`       |
| yq      | v4.53.3        | v4.54.1 (2026-09-29)    | `goneat-tools-runner-glibc`, `sbom-tools-runner-glibc`                                           | `/usr/local/bin/yq`          |

The musl images use the Alpine `yq-go` package, which has no findings.

## Remaining findings

| Tool  | Finding                                                             | Component and installed version | Fixed in            |
| ----- | ------------------------------------------------------------------- | ------------------------------- | ------------------- |
| syft  | CVE-2026-111943                                                     | Go stdlib go1.26.8              | go1.26.10, go1.27.3 |
| syft  | CVE-2026-78667, CVE-2026-78669, CVE-2026-97031                      | Go stdlib go1.26.8              | go1.26.9, go1.27.2  |
| syft  | CVE-2026-116587                                                     | go-jose/v4 v4.1.5               | v4.1.6              |
| grype | CVE-2026-111943                                                     | Go stdlib go1.26.8              | go1.26.10, go1.27.3 |
| grype | CVE-2026-78667, CVE-2026-78669, CVE-2026-97031                      | Go stdlib go1.26.8              | go1.26.9, go1.27.2  |
| grype | CVE-2026-116587                                                     | go-jose/v4 v4.1.5               | v4.1.6              |
| grype | CVE-2026-41567, CVE-2026-42306 (new with v0.121.0 scans)            | docker/docker v28.5.2           | no fixed version published |
| trivy | CVE-2026-116587                                                     | go-jose/v4 v4.1.5               | v4.1.6              |
| yq    | CVE-2026-46600, CVE-2026-78669                                      | golang.org/x/net v0.55.0        | v0.56.0, v0.60.0    |
| yq    | CVE-2026-56851, CVE-2026-56852                                      | golang.org/x/text v0.37.0       | v0.41.0, v0.39.0    |
| yq    | CVE-2026-111943, CVE-2026-33818, CVE-2026-39821, CVE-2026-39822, CVE-2026-46600, CVE-2026-56853, CVE-2026-56858, CVE-2026-56859, CVE-2026-56860, CVE-2026-56862, CVE-2026-78667, CVE-2026-78669, CVE-2026-97031 | Go stdlib go1.26.4 | go1.26.10 or earlier patch lines |

The two docker/docker findings have no fixed version, so the scheduled CVE scan (`ignore-unfixed`) does not count them. They are listed because they are new in grype scans. CVE-2026-39822 and CVE-2026-56852 are also waived in `.trivyignore`.

## Why the newest upstream release still carries them

- **syft v1.55.0 and grype v0.121.0** are built with go1.26.8 (`go.mod` `go 1.26.8`). Their stdlib fixes need go1.26.9 and go1.26.10. Both tags pin go-jose v4.1.5. Upstream `main` already requires go-jose v4.1.6 for both, but no release includes it.
- **trivy v0.76.1** is built with go1.27.3, so its stdlib findings are clear. It pins go-jose v4.1.5; upstream `main` requires v4.1.6 and is unreleased.
- **yq v4.53.3** is the pinned release binary, built with go1.26.4. The newest yq release v4.54.1 is built with go1.27.1 and golang.org/x/net v0.59.0, so it would still report 5 HIGH findings (x/net CVE-2026-78669 and stdlib CVE-2026-111943, CVE-2026-78667, CVE-2026-78669, CVE-2026-97031). The pin stays at v4.53.3 for this release. yq `master` already uses x/net v0.61.0 and is unreleased.
- go-jose v4.1.6 was published 2026-10-14; the advisory CVE-2026-116587 was published 2026-10-26. The Go standard-library fixes are 14 or more days old.

No self-builds: these tools stay on the upstream release binaries.

## Recheck

Recheck date: 2026-11-16. Then:

1. Check for syft, grype, trivy and yq releases newer than the pins above.
2. If a release carries go-jose v4.1.6 and a Go toolchain at or above go1.26.10 (or go1.27.3), take it, subject to the 7-day cooling window, and rescan.
3. Rescan every image with no `.trivyignore` and update this document, or remove it when no fixable HIGH/CRITICAL findings remain.
