---
title: goneat v0.6.9, OpenSSL 3.5.9-r1 and jq 1.8.2-r0 cooling exception
date: "2026-11-20"
approved_by: "@3leapsdave"
until: "2026-11-27T14:34:44Z"
---

# goneat v0.6.9, OpenSSL 3.5.9-r1 and jq 1.8.2-r0 cooling exception

These pins are inside the 7-day cooling window. Each pin is approved until the time in its row.

| Package              | Version                | Published / built    | Until                |
| -------------------- | ---------------------- | -------------------- | -------------------- |
| goneat               | v0.6.9                 | 2026-11-20T14:34:44Z | 2026-11-27T14:34:44Z |
| libcrypto3 / libssl3 | 3.5.9-r1 (Alpine 3.24) | 2026-11-18T23:31Z    | 2026-11-25T23:31Z    |
| jq                   | 1.8.2-r0 (Alpine 3.21) | 2026-11-15T23:21Z    | 2026-11-22T23:21Z    |

- **goneat**: the publish time is the GitHub release `published_at` time. The module proxy first saw the tag at 2026-11-20T13:25:46Z, which is earlier, so the exception window also covers the proxy time. The image builds install this tag with `go install`.
- **libcrypto3 / libssl3**: Alpine replaced 3.5.9-r0 with 3.5.9-r1, and 3.5.9-r0 is no longer served. Without a pin the images would fall back to the base image's 3.5.8-r0.
- **jq**: 1.7.1-r0 is no longer served on Alpine 3.21.

## Lapse

Each row's exception elapses at its Until time; all have elapsed after 2026-11-27T14:34:44Z. The pins stay until a later release changes them.
