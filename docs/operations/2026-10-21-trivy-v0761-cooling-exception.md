---
title: Trivy v0.76.1 cooling exception
date: "2026-10-21"
published_at: "2026-10-21T11:18:34Z"
until: "2026-10-28T11:18:34Z"
approved_by: "@3leapsdave"
---

# Trivy v0.76.1 cooling exception

Trivy v0.76.1 is inside the 7-day cooling window. The pin is approved until 2026-10-28T11:18:34Z.

## Archives

| Archive     | SHA256                                                             |
| ----------- | ------------------------------------------------------------------ |
| Linux-64bit | `c7cbe3137fb8a48a17574bede3dd6beb16742d1e9772929940fc90082c39d9c0` |
| Linux-ARM64 | `e174dff2a6dba5e3ae41f8d0537a6324405bd08132497340304c6b20e0f16a1f` |

`trivy_0.76.1_checksums.txt` lists those digests. The SHA256 of each downloaded archive matches that file. The sbom-tools Dockerfiles check the same digest before unpacking.

## Signatures

`cosign verify-blob` accepted the sigstore bundle for the checksum file and for both Linux archives.

- Identity: `https://github.com/aquasecurity/trivy/.github/workflows/reusable-release.yaml@refs/tags/v0.76.1`
- Issuer: `https://token.actions.githubusercontent.com`

## Lapse

After 2026-10-28T11:18:34Z this exception is elapsed. The pin stays until a later release changes it.
