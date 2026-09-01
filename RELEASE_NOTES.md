# Release Notes

## v0.5.4 (2026-09-01)

**Go 1.26.6 runner rebuild + security pin refresh**

Image contents change. Rebuilds the goneat-tools images with Go 1.26.6 — clearing the Go-stdlib HIGH advisory cluster carried by every in-runner-built binary and the shipped `/opt/go` — plus refreshed node base digests (node 22.23.2) and the checksum-verified jq 1.8.2 binary on the glibc runner. goneat stays at v0.5.16.

### Changes

| Area | Change |
| ---- | ------ |
| Go toolchain | **`1.26.5` → `1.26.6`** (version + tarball checksums + coupled `GO_IMAGE`) on slim + both full runners |
| Builder digests | Pinned to patch-specific `golang:1.26.6-alpine` / `golang:1.26.6-bookworm` (floating `1.26-*` tags already at 1.26.7) |
| Node bases | Digest refresh on both images → node **22.23.2** (base npm 10.9.8 < pinned 12.0.1 → npm override stays) |
| `goneat-tools-runner-glibc` | **`jq` `1.8.1` → `1.8.2`** upstream binary, **checksum-verified per-arch in the build** |
| musl `jq` | **Held at `1.8.1-r0`** — Alpine 3.24 has no 1.8.2 package yet |
| goneat | Unchanged at **v0.5.16**. |
| musl `libssl3`/`libcrypto3` | **Pinned to `3.5.8-r0`** — the pinned node:22-alpine digest bundles 3.5.7-r0 and `apk add` does not upgrade satisfied dependencies, so explicit apk pins pull the patched build, clearing `CVE-2026-63073` (CRITICAL) + 7 HIGH per lib. |

### Updated Images

goneat-tools slim + both full runners rebuild. sbom-tools and valkey images are unchanged in content (retag only if the release matrix republishes them). Floating tags `:latest` / `:v0` move on GA.

### Known residuals (not clean)

- Prebuilt `syft`/`grype`/`yq` binaries retain Go stdlib HIGHs (upstream ships them built with older Go).
- Embedded module advisories in `goneat` (go-git, x/crypto, x/mod) — owned by the goneat dependency-refresh task, re-embedded on the next goneat pin bump.
- Debian bookworm OS criticals on the glibc runner (`curl`, `libc6`, `perl`, `libssh2-1`, `openssh-client`) — no-fix upstream in bookworm; base migration deferred to its own cut.
- musl jq held at `1.8.1-r0` until Alpine 3.24 publishes 1.8.2.

### Upgrade notes

Consumers pinned to `:v0.5.3` should retag to `:v0.5.4` for the Go 1.26.6 toolchain and stdlib fixes. No interface change — same binaries and paths, patched builds. Downstream consumers (including goneat's CI) retag their runner references to `:v0.5.4` after GA.

### Non-goals (this cut)

Debian trixie migration, Alpine rebase beyond 3.24, sbom-tools rebuild, syft/grype/yq bumps, golangci-lint 2.13, biome 2.5.x, ruff 0.16, cargo-deny 0.20, goneat newer than v0.5.16.

Full detail: `docs/releases/v0.5.4.md`.

## v0.5.3 (2026-08-31)

**Runner content pins — Prettier 3.9.6 + goneat-aligned linter patches**

Image contents change. Rebuilds the goneat-tools images so hosted CI ships Prettier 3.9.6 (goneat v0.5.16 recommended) instead of 3.8.0, and folds three matching patch alignments into the same rebuild.

### Changes

| Area | Change |
| ---- | ------ |
| slim + both full runners | **`prettier` `3.8.0` → `3.9.6`** |
| slim + both full runners | **`actionlint` `v1.7.10` → `v1.7.12`** |
| slim + both full runners | **`shfmt` `v3.12.0` → `v3.13.1`** |
| both full runners | **`golangci-lint` `v2.12.1` → `v2.12.2`** (not slim) |
| OS APK/APT pins | Unchanged. |
| goneat | Unchanged at **v0.5.16**. |

### Updated Images

goneat-tools slim + both full runners rebuild. sbom-tools and valkey images are unchanged in content (retag only if the release matrix republishes them). Floating tags `:latest` / `:v0` move on GA.

### Upgrade notes

Consumers pinned to `:v0.5.2` must move to `:v0.5.3` to get the new pins. Prettier 3.9.x may rewrite Markdown/JSON differently than 3.8.0 — re-run format on consumer trees.

### Non-goals (this cut)

Biome, uv, ruff 0.16, cargo-deny 0.20, shfmt 3.14, golangci-lint 2.13, scanners, OS pin refreshes, and goneat newer than v0.5.16.

Full detail: `docs/releases/v0.5.3.md`.

## v0.5.2 (2026-08-19)

**Runner content pins — Rust 1.94.1, goneat v0.5.16, pytest 9.1.1**

Image contents change. v0.5.1 was pipeline-only; this cut rebuilds the goneat-tools images so CI runners can compile crates whose transitive `rust-version` is 1.94.1, and folds two already-reviewed companion pins into the same rebuild.

### Changes

| Area | Change |
| ---- | ------ |
| `goneat-tools-runner-{glibc,musl}` | **Rust `1.92.0` → `1.94.1`** (rustc, cargo, rustfmt, clippy). rustup default toolchain only — no `RUSTUP_TOOLCHAIN` env. Slim stays Rust-free. 7 cross targets unchanged. |
| `goneat-tools-slim-musl` + both runners | **`goneat` `v0.5.15` → `v0.5.16`**. Fail-closed formatter preflight is unchanged from v0.5.15. |
| `goneat-tools-runner-{glibc,musl}` | **`pytest` `9.0.2` → `9.1.1`**. |
| OS APK/APT pins | Unchanged. |

### Updated Images

goneat-tools slim + both full runners rebuild. sbom-tools and valkey images are unchanged in content (retag only if the release matrix republishes them). Floating tags `:latest` / `:v0` move on GA.

### Upgrade notes

Consumers pinned to `:v0.5.1` must move to `:v0.5.2` to get the new toolchain. rustfmt/clippy may emit different diagnostics or formatting than 1.92.0. Repos that pin an older channel in `rust-toolchain.toml` can still rustup-install that channel; the image default is 1.94.1.

### Non-goals (this cut)

Prettier/Biome, uv, ruff, cargo-deny, scanner (syft/grype/trivy), and OS pin refreshes. Not a jump to Rust 1.97. Slim does not gain Rust.

Full detail: `docs/releases/v0.5.2.md`.

## v0.5.1 (2026-07-31)

**Release-pipeline hygiene — manifest matrix concurrency + imagetools retry**

No image content change from v0.5.0. Hardens the release workflow against GHCR write throttling observed when composing multi-arch manifests and copying aliases under full 7-way concurrency.

### Changes

| Area | Change |
| ---- | ------ |
| `.github/workflows/release.yml` (`manifest` job) | **`max-parallel: 2`** on the strategy matrix — lowers concurrent GHCR blob/manifest writes |
| Compose step (`docker buildx imagetools create`) | **429/5xx-only retry** with exponential backoff + jitter (5 attempts, 15s base); permanent errors fail immediately |

### Updated Images

All images rebuilt and re-tagged as `v0.5.1` (content identical to v0.5.0). Floating tags `:latest` / `:v0` move on GA.

### Verification

Workflow change only; validated against the v0.5.0 failure mode (3/7 concurrent manifests failed on 429; single-cell re-run passed).

Full detail: `docs/releases/v0.5.1.md`.

## v0.5.0 (2026-07-30)

**Runner content delta + full fixable-CVE sweep — `ruff` Python parity, `zip`, `CGO_ENABLED` docs, deterministic OS-security pins, Go 1.26.5, scanner/tool currency**

First image-content rebuild since v0.4.x. Started as a downstream ask (add `zip`, document `CGO_ENABLED`) and was deliberately widened — since any image touch forces a full rebuild + downstream adoption cascade — to sweep every **fixable** HIGH/CRITICAL CVE across the image set. All six images scan to **0 fixable HIGH/CRITICAL** (trivy `--ignore-unfixed`, with documented `.trivyignore` exceptions). Versioned minor: `ruff` and `zip` are new tools consumers can rely on.

> **Read this before upgrading.** goneat v0.5.15 changes `goneat format` to **fail closed** when an external formatter it would dispatch to is missing, rather than completing with silently incomplete coverage. `ruff` ships in this release for exactly that reason — without it, any repository containing `.py` files would move from _quietly unformatted_ to a _hard CI failure_. If your pipeline depends on a formatter that is not installed, expect a new failure and either install it or pass `--ignore-missing-tools`. `goneat assess` is unaffected and still reports such files as skipped.

### Changes

| Area                                                      | Change                                                                                                                                                                                                                                                                                                                               |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `goneat-tools-runner-{glibc,musl}`                        | **`ruff 0.15.22` added** — the Python formatter/linter `goneat` dispatches to. The runners shipped python3/uv/maturin/pytest but not `ruff`, so any repository with `.py` files failed in hosted CI. Matches goneat's recommended foundation version. Not added to the slim images.                                                  |
| `goneat-tools-runner-{glibc,musl}`                        | **`zip` CLI added** (beside `unzip`). Closes a Windows-`.zip` packaging gap.                                                                                                                                                                                                                                                         |
| Docs (`container-usage-patterns.md`, `goneat-tools.md`)   | **`CGO_ENABLED=1` documented** — preset is intentional (CGO-capable runner); set `CGO_ENABLED=0` (use `:=`/`override`) for static/cross builds. Revisiting the preset tracked in #14.                                                                                                                                                |
| `goneat-tools-glibc`, `sbom-tools-glibc`                  | **`libgnutls30` pinned to `3.7.9-2+deb12u7`** (CRITICAL CVE-2026-33845/42010 + 3 HIGH). Base lags the security repo; explicit apt pin forces the patched build.                                                                                                                                                                      |
| `scripts/validate-apt-pins.sh` + `make validate-apt-pins` | **New** deterministic apt-security-pin validator (apt analog of `validate-apk-pins`); wired into `make quality`. `validate-pins` enforces pin presence. First `source:"apt"` entry in `tools.json`.                                                                                                                                  |
| Go toolchain                                              | **`1.26.2 → 1.26.5`** (version + checksums + coupled `GO_IMAGE`); clears Go-stdlib CVEs in the in-house tools + shipped `/opt/go`.                                                                                                                                                                                                   |
| `goneat`                                                  | **`v0.5.9 → v0.5.15`** — patched go-git/go-billy/OpenTelemetry deps, plus the fail-closed formatter behavior described above.                                                                                                                                                                                                        |
| `syft`/`grype`/`trivy`/`yq`                               | **`v1.41.1→v1.50.0` / `v0.107.1→v0.116.1` / `v0.69.3→v0.72.0` / `v4.49.2→v4.53.3`** (glibc yq); clear vendored-dependency CVEs. syft/grype were initially held one release back for soak time, then adopted once `v1.50.0`/`v0.116.1` were confirmed to carry `grpc v1.82.1` (closes `GHSA-hrxh-6v49-42gf`).                         |
| `sfetch`/`shellsentry`                                    | **`v0.4.5→v0.4.9` / `v0.1.4→v0.1.5`** — both move to `x/crypto v0.54.0`, clearing nine HIGH advisories. The two carried the same CVE set from different `x/crypto` versions, so both had to move before any cleared.                                                                                                                 |
| `npm` (goneat runners)                                    | **Pinned to `12.0.1`**, overriding the node base's bundled npm 10.9.x whose dependency tree carries a CRITICAL (`tar`) plus HIGH `sigstore`/`brace-expansion` advisories. Those live inside npm's own `node_modules` and are unreachable except by updating npm. Re-verify on every base digest bump; drop once the base catches up. |
| musl runner base                                          | **Alpine `3.23 → 3.24.1`** via the `node:22-alpine` upstream rebase, rotating four pinned apk packages (`bash`, `curl`, `git`, `minisign`) and `yq-go → 4.53.3-r0` — the musl `yq` now converges with the glibc binary pin. (`sbom-tools` stays on `alpine:3.21`.)                                                                   |
| Final-stage base digests                                  | Refreshed (`node:22-alpine`, `node:22-bookworm-slim`, `alpine:3.21`, `debian:bookworm-slim`) — rebuild on patched OS package sets. The two glibc images had drifted onto different `debian:bookworm-slim` digests and are now converged.                                                                                             |

### Updated Images

All six tool images rebuilt; `valkey-server-glibc` unchanged (base already current). No interface change beyond the new `ruff` and `zip` binaries and patched package/tool versions — but note the `goneat format` behavior change called out above.

### CVE posture

All six images scan to **0 fixable HIGH/CRITICAL**. Residuals: (1) no-fix class gate-excluded by `ignore-unfixed: true` (`linux-libc-dev` kernel headers not-applicable, Debian won't-fix, unfixed-upstream python/perl); (2) fixes that exist in a dependency but ship in no upstream release of the tool we carry — embedded Go stdlib in the prebuilt `syft`/`grype`/`trivy`/`yq` binaries, `x/text` in `golangci-lint`/`yq`/`trivy`, `docker/docker` vendored by `grype`, `oras-go` and `grpc` vendored by `trivy`, and `brace-expansion` inside the pinned npm. We are on the latest release of every one of these. Tracked via time-boxed `.trivyignore` entries (review by 2026-10-30), each attributed to the specific binary carrying it and re-verified against this build.

### Verification

`make quality` green (incl. new `validate-apt-pins`); all six images built; `make test-all` green — including the new Python parity e2e, which asserts that `goneat format --check` fails on an unformatted fixture for _format drift_ rather than for a missing executable, so a `ruff`-less image cannot pass it vacuously; trivy `--ignore-unfixed` = 0 HIGH/CRITICAL on all six images. Validated via a `v0.5.0-rc.1` prerelease (pilot: `forge-microtool-gimlet`) before GA.

Full detail: `docs/releases/v0.5.0.md`.

## v0.4.2 (2026-05-18)

**Release-Pipeline Hygiene — Native arm64 Runners + Forced apk Pin Refresh**

CI plumbing release. No new tools, no Dockerfile architecture changes, no API or interface delta for consumers — but the release pipeline itself was rebuilt: per-arch builds now run on native runners instead of QEMU-emulated amd64, eliminating the qemu-user aarch64 SIGILL roulette that left v0.4.1 partially published. Two tightly-scoped apk pin bumps were also forced by alpine 3.23 upstream rotation between v0.4.1 and now.

### Changes

| Area                             | Change                                                                                                                                                                                                                                                                                                                                           |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `.github/workflows/release.yml`  | Single `release` job → three jobs (`build` per-arch × 14 cells / `manifest` aggregator × 7 / `cosign` × 7). amd64 cells on `ubuntu-latest-m`, arm64 cells on `ubuntu-latest-arm64-s`. Per-arch push-by-digest; `docker buildx imagetools create` composes the multi-arch manifest at every canonical and alias tag. No QEMU in the release path. |
| Pre-release tag guard            | New: when `$VERSION` contains `-` (e.g. `v0.4.2-rc.1`), publish only `:v$VERSION` and skip `:latest` / `:v<major>`; mark release as prerelease + non-latest. Removes a long-standing foot-gun.                                                                                                                                                   |
| `images/goneat-tools/Dockerfile` | `CURL_VERSION` 8.17.0-r1 → 8.19.0-r0; `YQ_VERSION` 4.49.2-r5 → 4.49.2-r6. Forced by alpine upstream rotation.                                                                                                                                                                                                                                    |
| `manifests/tools.json`           | Canonical `curl` and `yq-go` entries bumped to match.                                                                                                                                                                                                                                                                                            |
| **v0.4.1 release page**          | Deleted. Tag remains in git history; consumers should resolve to `:v0.4.2`.                                                                                                                                                                                                                                                                      |

### Updated Images

- `goneat-tools-runner-musl` — curl 8.17.0-r1 → 8.19.0-r0, yq-go 4.49.2-r5 → 4.49.2-r6 (alpine 3.23 forced bumps). **Re-publishes the image that v0.4.1 failed to ship**; `:v0` and `:latest` floats unstick from the v0.4.0 digest.
- `goneat-tools-slim-musl` — same yq-go bump (no curl in slim variant).
- All 7 other image variants: no content change vs v0.4.1.

### Verification

```bash
# Confirm goneat-tools-runner-musl is now published at v0.4.2 (was missing on v0.4.1):
docker pull ghcr.io/fulmenhq/goneat-tools-runner-musl:v0.4.2

# Confirm multi-arch manifest contains both amd64 and arm64:
docker buildx imagetools inspect ghcr.io/fulmenhq/goneat-tools-runner-musl:v0.4.2

# Confirm bumped pin versions inside the image:
docker run --rm ghcr.io/fulmenhq/goneat-tools-runner-musl:v0.4.2 curl --version | head -1
# expect: curl 8.19.0 ...
docker run --rm ghcr.io/fulmenhq/goneat-tools-runner-musl:v0.4.2 yq --version
# expect: yq (https://github.com/mikefarah/yq/) version v4.49.2
```

### Breaking Changes

None.

### Operational Notes

- Release wall-clock is substantially shorter under native runners. Reference data point: the largest image (`goneat-tools-runner-glibc`) arm64 build took ~1h+ under QEMU on v0.4.0; native took ~12 min on the rc.1 dry-run.
- The rc.1 dry-run (since deleted) successfully validated 12 of 14 build cells before surfacing the alpine pin drift; the manifest aggregator was separately validated locally before tagging v0.4.2.

## v0.4.1 (2026-05-05)

**Hygiene Patch — namelens Review Nits + Makefile checkmake Re-Enable**

No image-content changes. Consumers tracking `:v0` see no functional delta vs v0.4.0; this release is repo hygiene driven by the namelens devlead's v0.4.0 PR review plus our own v0.4.0-deferred Makefile cleanup.

### Changes

| Area                | Change                                                                                                                                                                                                     |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cve-scan` workflow | Tracker now reports `**Total findings:** N (M unique CVE IDs)` so readers don't have to dedup mentally. New `include_prereleases` `workflow_dispatch` input for one-shot RC scans (cron unchanged).        |
| `Makefile`          | `.PHONY:` block rewritten as multiple grouped directives so `checkmake` parses correctly; 16 previously-missing targets added. `checkmake` re-enabled in `.goneat/assess.yaml` with `max_body_length=120`. |
| `Dockerfile` ARGs   | Comment block above `ARG GO_IMAGE` documents the `GO_IMAGE` ↔ `GO_VERSION` coupling so future Go bumps don't desync builder Go vs runtime Go.                                                              |
| `AGENTS.md`         | New "Post-Mutation Tree Check" mandatory section: agents must `git status` after running mutating make targets (`pr-final`, `fmt-sh`).                                                                     |

### Updated Images

None. Image content identical to v0.4.0.

### Verification

```bash
docker run --rm ghcr.io/fulmenhq/goneat-tools-runner-glibc:v0.4.1 \
  golangci-lint --version
# expect: golangci-lint has version 2.12.1 built with go1.26.2
```

## v0.4.0 (2026-05-04)

**Runner Self-Sufficiency — golangci-lint Bundled, Plus Scheduled CVE Scan + YAML Hygiene**

`goneat-tools-runner-{musl,glibc}` now ship `golangci-lint v2.12.1` pre-built against the runner's pinned Go (1.26.2). This closes the recurring "user `go install`s a Go-built linter inside the runner and inherits an older Go" failure pattern that produced the v0.3.5 unblock for namelens — and that namelens reproduced post-v0.3.5 because their CI cache still held an older binary. Three deliverables in this release: D1 (golangci-lint bundling, headline), D2 (scheduled CVE scan), D3 (YAML config triplet + `make pr-final`).

### Tool Version Updates

| Tool          | Previous      | Current | Notes                                                                                                              |
| ------------- | ------------- | ------- | ------------------------------------------------------------------------------------------------------------------ |
| golangci-lint | (not bundled) | v2.12.1 | Built in-runner against Go 1.26.2; runner image is copyleft-by-design (per README). NOT included in slim variants. |

### ⚠ Migration: drop separate `golangci-lint` install steps

If your CI workflow installs `golangci-lint` _inside_ this runner via any of the patterns below, **the bundled binary is bypassed and you may continue to hit the "language version too low" error** that v0.3.5 was meant to solve:

- `golangci/golangci-lint-action@v7` (or any `golangci-lint-action` version)
- `go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@<ver>`
- Hand-rolled `curl ... | sh` install scripts

The fix landing in v0.4.0 is only realized when you **drop the separate install step** and call `golangci-lint` directly. Suggested replacement:

```yaml
# Before (bypasses bundled binary):
- uses: golangci/golangci-lint-action@v7
  with:
    version: v2.12.1

# After (uses bundled binary built against runner's Go 1.26.2):
- run: golangci-lint run ./...
```

If your config targets a Go version newer than the runner's pinned Go, you'll still hit the version mismatch — pin to a runner whose Go is `>=` your config target. As of v0.4.0 that's Go 1.26.2.

### New ops surfaces

- **CVE-scan workflow** (`.github/workflows/cve-scan.yml`): runs trivy twice weekly against published runner + sbom-tools images (`:latest` plus the two most recent pinned semver tags per variant). Findings update a single rolling tracking issue rather than spawning per-finding noise. `workflow_dispatch` supports severity override + dry-run for synthetic tests.
- **YAML config triplet**: `.yamlfmt`, `.yamllint`, `.goneat/assess.yaml` land with explicit `pad_line_comments: 2`. New `make pr-final` strict local gate runs `goneat format` then `goneat assess --check --categories format,lint,security --fail-on medium` so maintainers catch drift before pushing.

### Updated Images

| Image                       | New Content                                     |
| --------------------------- | ----------------------------------------------- |
| `goneat-tools-runner-musl`  | golangci-lint v2.12.1 (built against Go 1.26.2) |
| `goneat-tools-runner-glibc` | golangci-lint v2.12.1 (built against Go 1.26.2) |
| `goneat-tools-slim-musl`    | unchanged (golangci-lint is runner-only)        |

### Image Size Delta

- `goneat-tools-runner-{glibc,musl}`: ~+30 MB compressed, ~+110 MB uncompressed (golangci-lint binary is unstripped Go).
- `goneat-tools-slim-musl`: unchanged.

### Breaking Changes

None for `goneat-tools-slim-musl` or `sbom-tools-*` consumers. For `goneat-tools-runner-*` consumers: the bundled `golangci-lint` is the recommended path; existing separate-install patterns continue to work but bypass the v0.4.0 fix (see Migration above).

### Verification

```bash
docker run --rm ghcr.io/fulmenhq/goneat-tools-runner-glibc:v0.4.0 \
  golangci-lint --version
# expect: golangci-lint has version 2.12.1 built with go1.26.2
```

## v0.3.5 (2026-05-02)

**Go 1.26.2 Patch — CVE-2026-33810 Remediation**

Bumps the runner Go toolchain from 1.26.1 to 1.26.2 to clear CVE-2026-33810 (high) and unblock downstream consumers whose `golangci-lint` configs target `go 1.26.2`. No behavior change beyond the toolchain bump.

### Tool Version Updates

| Tool        | Previous  | Current   | Notes                                                                           |
| ----------- | --------- | --------- | ------------------------------------------------------------------------------- |
| Go pin      | 1.26.1    | 1.26.2    | Clears CVE-2026-33810 (high); unblocks `golangci-lint` configs targeting 1.26.2 |
| yq-go (apk) | 4.49.2-r4 | 4.49.2-r5 | Alpine package revision; r4 no longer available upstream                        |

### Updated Images

| Image                       | Updated Tools          |
| --------------------------- | ---------------------- |
| `goneat-tools-runner-musl`  | Go pin, builder digest |
| `goneat-tools-slim-musl`    | builder digest         |
| `goneat-tools-runner-glibc` | Go pin, builder digest |

### Breaking Changes

None. Existing image references continue to work. Consumers tracking `:v0` get the fix automatically; explicit pinners should bump to `:v0.3.5`.

### Verification

```bash
docker run --rm ghcr.io/fulmenhq/goneat-tools-runner-glibc:v0.3.5 go version
# expect: go version go1.26.2 linux/<arch>
```

## v0.3.4 (2026-03-25)

**Goneat Patch + Bootstrap Refactor**

Bumps goneat to v0.5.9 for bug fixes, pins Go to 1.26.1 to clear dependency vulnerability noise, and refactors `bootstrap-tools.sh` to an arg-based interface.

### Tool Version Updates

| Tool   | Previous | Current | Notes                              |
| ------ | -------- | ------- | ---------------------------------- |
| goneat | v0.5.8   | v0.5.9  | Bug fixes                          |
| Go pin | 1.26     | 1.26.1  | Eliminates dep vulnerability noise |

### Infrastructure

- **`scripts/bootstrap-tools.sh`**: Refactored from env-only to arg-based interface with env var overrides for better ergonomics and discoverability.

### Updated Images

| Image                       | Updated Tools  |
| --------------------------- | -------------- |
| `goneat-tools-runner-musl`  | goneat, Go pin |
| `goneat-tools-slim-musl`    | goneat, Go pin |
| `goneat-tools-runner-glibc` | goneat, Go pin |

### Breaking Changes

None. Existing image references continue to work.

### Verification

```bash
docker run --rm ghcr.io/fulmenhq/goneat-tools-runner-musl:v0.3.4 sh -c "goneat version"
```

## v0.3.3 (2026-03-18)

**Tool Updates + Go Builder Bump**

This release updates 6 packages across goneat-tools and sbom-tools images and bumps the Go builder to 1.26.1.

### Tool Version Updates

| Tool        | Previous  | Current   | Notes                                    |
| ----------- | --------- | --------- | ---------------------------------------- |
| goneat      | v0.5.2    | v0.5.8    | Feature release                          |
| sfetch      | v0.4.1    | v0.4.5    | Patch release                            |
| shellsentry | v0.1.1    | v0.1.4    | Requires Go 1.26.1+                      |
| trivy       | v0.69.0   | v0.69.3   | v0.69.0 ARM64 asset unavailable upstream |
| yq-go (apk) | 4.49.2-r2 | 4.49.2-r4 | Alpine package revision                  |
| Go builder  | 1.25      | 1.26.1    | Required for shellsentry v0.1.4          |

### Updated Images

| Image                       | Updated Tools                                  |
| --------------------------- | ---------------------------------------------- |
| `goneat-tools-runner-musl`  | goneat, sfetch, shellsentry, yq-go, Go builder |
| `goneat-tools-slim-musl`    | goneat, sfetch, yq-go, Go builder              |
| `goneat-tools-runner-glibc` | goneat, sfetch, shellsentry, Go builder        |
| `sbom-tools-runner-musl`    | shellsentry, trivy, Go builder                 |
| `sbom-tools-runner-glibc`   | shellsentry, trivy, Go builder                 |

### Breaking Changes

None. Existing image references continue to work.

### Verification

```bash
docker run --rm ghcr.io/fulmenhq/goneat-tools-runner-musl:v0.3.3 sh -c "goneat version && sfetch --version && shellsentry --version"
docker run --rm ghcr.io/fulmenhq/sbom-tools-runner-musl:v0.3.3 sh -c "trivy version && shellsentry --version"
```

## v0.3.2 (2026-02-04)

**Tool Updates + Bug Fixes**

This release updates 13 packages across goneat-tools and sbom-tools images, including a critical bug fix for sfetch and security updates for uv.

### Critical Fix

- **sfetch v0.4.1**: Fixes 403 errors that occurred when downloading certain GitHub release assets.

### Security Updates

- **uv 0.9.28**: Includes OpenSSL 3.5.5 security fixes.

### Tool Version Updates

| Tool          | Previous  | Current   | Notes                             |
| ------------- | --------- | --------- | --------------------------------- |
| sfetch        | v0.4.0    | v0.4.1    | Bug fix: GitHub asset 403s        |
| goneat        | v0.4.4    | v0.5.2    | Feature release                   |
| prettier      | 3.7.4     | 3.8.0     | Angular v21.1 support             |
| biome         | 2.3.8     | 2.3.11    | Patch fixes                       |
| yamlfmt       | v0.20.0   | v0.21.0   | stdin reading fixes               |
| actionlint    | v1.7.9    | v1.7.10   | ubuntu-slim runner support        |
| checkmake     | 0.2.2     | v0.3.2    | Repo moved to checkmake/checkmake |
| syft          | v1.39.0   | v1.41.1   | CycloneDX bug fixes               |
| grype         | v0.104.3  | v0.107.1  | DB schema v6 improvements         |
| trivy         | v0.68.1   | v0.69.0   | Patch update                      |
| cargo-nextest | 0.9.120   | 0.9.122   | Pager support                     |
| uv            | 0.9.24    | 0.9.28    | OpenSSL security fixes            |
| yq-go (apk)   | 4.49.2-r1 | 4.49.2-r2 | Alpine package revision           |

### Breaking Changes

None. Existing image references continue to work.

### Migration Notes

- **checkmake**: Upstream repository moved from `mrtazz/checkmake` to `checkmake/checkmake`. No action required for image users; the tool works identically.

## v0.3.1 (2026-01-12)

**Polyglot Runner + Subsystems + Developer Tooling**

This release expands goneat-tools runners into full polyglot CI images, introduces the subsystems framework for multi-container deployments, and improves local development workflows.

### Polyglot Runner Toolchains

The goneat-tools runner images now include complete build toolchains for multi-language projects:

| Toolchain       | Version | Capabilities                                                     |
| --------------- | ------- | ---------------------------------------------------------------- |
| **Rust**        | 1.92.0  | rustup, rustfmt, clippy, 7 cross-compilation targets             |
| **Cargo tools** | —       | cargo-deny, cargo-audit, cargo-zigbuild, cargo-nextest, cbindgen |
| **Go**          | 1.25.5  | CGO_ENABLED=1, full toolchain                                    |
| **Zig**         | 0.15.2  | Cross-compilation backend for cargo-zigbuild                     |
| **Python**      | 3.11+   | uv, maturin (PyO3/Rust bindings), pytest                         |
| **Node**        | 22.x    | npm, napi-rs CLI for native addon builds                         |
| **SBOM**        | —       | syft 1.39.0, grype 0.104.3                                       |

### Subsystems Framework

New `subsystems/` taxonomy element for multi-container coordinated deployments:

- **`echo-proxy-fixture`**: Evaluation-scale nginx + echo backend (fast smoke testing)
- **`authentik-idp`**: Enterprise IdP with blueprints, presets, OIDC discovery
- **Schema validation**: `schemas/subsystem-manifest.schema.json` for MANIFEST.yaml
- **CI integration**: `make validate-subsystems` validates manifests and compose files
- **Standard**: `docs/standards/subsystem-standard.md` normative specification

### Build Infrastructure

- **`docker-bake.hcl`**: Parallel multi-image builds with shared cache
- **`make prove*` targets**: Fast local validation (native arch parallel builds)
- **Local cache support**: `make prove CACHE=1` for faster rebuilds

### Developer Tooling

- **`make bootstrap`**: Uses sfetch -> goneat trust chain to install foundation tools
- **`.goneat/tools.yaml`**: Scoped tool definitions for reproducible local environments
- **`docs/user-guide/preflight.md`**: Prerequisites documentation

### Known Limitations

- **arm64 musl runners**: `cargo-audit` and `cargo-nextest` are not available on arm64 musl (upstream only publishes glibc binaries for aarch64). Use `-runner-glibc` for full toolchain on arm64. This is tracked for potential source-build resolution in a future patch.

Run `make bootstrap` after cloning to set up your development environment.

## v0.3.0 (2026-01-05)

**Canonical Tag Taxonomy + Application Images**

This release introduces a significant information-model evolution:

- **Canonical tags now include libc dimension**: `-runner-musl`, `-slim-musl`, `-runner-glibc`. Short-name aliases (e.g., `goneat-tools:v0.3.0`) remain for backward compatibility but are time-boxed.
- **Application image class**: New `manifests/apps.json` and `schemas/app-manifest.schema.json` for server/service images distinct from tool images.
- **valkey-server-glibc**: First application image — Valkey (Redis-compatible) key-value store as a vendor-image repack with non-root runtime, license transparency, and CLI-based configuration.

**Migration**: Image references should migrate to canonical names (e.g., `goneat-tools-runner-musl` instead of `goneat-tools`). Aliases continue to work during the transition period.

See `docs/standards/image-taxonomy.md` and `docs/adr/ADR-0006-image-taxonomy-and-governance.md` for details.
