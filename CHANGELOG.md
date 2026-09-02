# Changelog

Adheres to Keep a Changelog format. Versions follow semver.

## 0.5.6 - 2026-09-02

### Changed

- **`goneat` `v0.5.16` -> `v0.6.0`** on `goneat-tools-slim-musl` and both full runners (`ARG GONEAT_VERSION` + `manifests/tools.json`).
- **musl `jq` `1.8.1-r0` -> `1.8.2-r0`** after Alpine 3.24 rotated the prior package revision out of its repositories. All other tool, OS, and base-image pins are unchanged.
- Applied goneat v0.6.0's whitespace-only Markdown table formatting to existing documentation.

### Notes

- Image contents change this cut. Consumers pinned to `:v0.5.4` should retag to pick up goneat v0.6.0. Floating `:latest` / `:v0` move on GA.
- v0.5.5 was not released. Its workflow failed before manifest publication, and this release supersedes it.

## 0.5.5 - Not released (2026-09-01)

This release candidate was not published. Its workflow failed before manifest publication and was superseded by v0.5.6.

## [0.5.4] - 2026-09-01

### Changed

- **Go toolchain `1.26.5` → `1.26.6`** on slim and both full goneat-tools runners (`GO_VERSION` + tarball checksums + the coupled `GO_IMAGE` builder digest, kept in sync). Builder digests are pinned to the patch-specific `golang:1.26.6-alpine` / `golang:1.26.6-bookworm` tags (verified `go1.26.6`); the floating `golang:1.26-*` tags have moved to 1.26.7. Clears the Go-stdlib HIGH advisory cluster embedded in every in-runner-built binary and the shipped `/opt/go`.
- **Node base digests refreshed** (`node:22-alpine`, `node:22-bookworm-slim`) to digests shipping node 22.23.2 (was 22.23.1; clears 3 HIGH). Base npm is 10.9.8, still below the pinned npm 12.0.1 override — override stays.
- **`jq` `1.8.1` → `1.8.2`** on `goneat-tools-runner-glibc` (upstream binary), now **checksum-verified per-arch in the build** (`JQ_SHA256_AMD64`/`JQ_SHA256_ARM64` + `sha256sum -c`); SHA256s recorded in `manifests/tools.json`. The shared glibc jq row was split so `sbom-tools-runner-glibc` stays at 1.8.1.

### Notes

- Image **contents** change this cut. Consumers pinned to `:v0.5.3` should retag to pick up the Go 1.26.6 stdlib fixes. Floating `:latest` / `:v0` move on GA.
- **musl jq held at `1.8.1-r0`**: Alpine 3.24 does not carry jq 1.8.2 yet (`validate-apk-pins` green against upstream); bump when it lands.
- **musl `libssl3`/`libcrypto3` pinned to `3.5.8-r0`**: the pinned node:22-alpine digest bundles 3.5.7-r0 and `apk add` does not upgrade satisfied dependencies; explicit apk pins pull the patched build from the Alpine 3.24 repos, clearing `CVE-2026-63073` (CRITICAL) + 7 HIGH per lib.
- **Residuals (not clean)**: prebuilt syft/grype/yq binaries retain Go stdlib HIGHs (upstream-built with older Go); goneat embedded module advisories (go-git/x/crypto/x/mod) ride the next goneat pin; Debian bookworm OS criticals on the glibc runner are no-fix upstream (base migration deferred); musl jq held at 1.8.1-r0.
- goneat **unchanged at `v0.5.16`**; Rust, ruff, biome, uv, pytest, and scanners unchanged.

## [0.5.3] - 2026-08-31

### Changed

- **`prettier` `3.8.0` → `3.9.6`** on slim and both full goneat-tools runners (`ARG PRETTIER_VERSION` + `manifests/tools.json`). Aligns the image with goneat v0.5.16 foundation recommended version. Markdown/JSON format output may differ from 3.8.0.
- **`actionlint` `v1.7.10` → `v1.7.12`** on slim and both full runners.
- **`shfmt` `v3.12.0` → `v3.13.1`** on slim and both full runners.
- **`golangci-lint` `v2.12.1` → `v2.12.2`** on both full runners (not slim). Still built in-runner against the pinned Go toolchain (1.26.5). Not a jump to 2.13.x.
- **`scripts/validate-pins.sh`** now checks `ARG GOLANGCI_LINT_VERSION` against `tools.json` on both goneat-tools Dockerfiles.

### Notes

- Image **contents** change this cut. Consumers pinned to `:v0.5.2` must retag to pick up the new formatter/linter pins.
- OS APK/APT pins, goneat (`v0.5.16`), Rust, ruff, biome, uv, cargo-deny, and scanners are **unchanged**.

## [0.5.2] - 2026-08-19

### Changed

- **Rust toolchain `1.92.0` → `1.94.1`** on `goneat-tools-runner-{glibc,musl}` (`ARG RUST_VERSION` + rustc/cargo/rustfmt/clippy in `manifests/tools.json`). rustup still installs this as the default toolchain; the image does **not** set `RUSTUP_TOOLCHAIN`, so a consumer `rust-toolchain.toml` continues to win. Slim images remain Rust-free. Existing 7 rustup targets and rustfmt/clippy components are unchanged. 1.94.1 is the floor needed for crates whose transitive `rust-version` is 1.94.1 (notably AWS SDK / smithy 1.3+); this is not a jump to current stable.
- **`goneat` `v0.5.15` → `v0.5.16`** on slim and both full runners. v0.5.16 is a dogfood pin of goneat's own CI onto toolbox `v0.5.1`; formatter fail-closed behavior is unchanged from v0.5.15.
- **`pytest` `9.0.2` → `9.1.1`** on both full runners (pip pin + `tools.json`).

### Notes

- Image **contents** change this cut (unlike v0.5.1, which was release-pipeline hygiene only). Consumers pinned to `:v0.5.1` must retag to pick up the new toolchain.
- OS APK/APT pins are **unchanged**.
- rustfmt and clippy are not covered by the Rust language stability promise; `goneat format --check` / clippy-deny-warnings on older repos may differ from 1.92.0 output.

## [0.5.1] - 2026-07-31

### Fixed

- **Release manifest matrix concurrency** — `max-parallel: 2` on the `manifest` job in `.github/workflows/release.yml`. Full 7-way concurrent alias/manifest publish hit GHCR write throttling (HTTP 429 on blob upload / manifest PUT) on both `v0.5.0-rc.1` and `v0.5.0`; re-running a single failed cell alone always passed. Caps concurrent GHCR writes while keeping release wall-clock reasonable.
- **`docker buildx imagetools create` retry/backoff** — up to 5 attempts with exponential sleep (15s → 30s → 60s → 120s) plus full jitter, **only** when the failure looks like GHCR throttle (429 / `toomanyrequests`) or transient 5xx. Auth, 403, missing digests, and other permanent errors fail immediately (no backoff burn). Pairs with `max-parallel` rather than replacing it.

### Notes

- Image contents are unchanged from v0.5.0. This is a release-pipeline hygiene cut so the next content release does not re-hit the same throttle.

## [0.5.0] - 2026-07-30

### Added

- **`zip` CLI** in `goneat-tools-runner-{glibc,musl}` (alongside the existing `unzip`). Closes a packaging gap where release tooling building a Windows `.zip` failed with `zip: command not found` (the image shipped `python3` but no `zip`). Reported from a downstream consumer (`forge-microtool-gimlet`) validating against `goneat-tools-runner-glibc:v0.4.2`.
- **`scripts/validate-apt-pins.sh` + `make validate-apt-pins`** — the apt analog of `validate-apk-pins`. Verifies that apt security pins in `manifests/tools.json` are available in the Debian repos (incl. bookworm-security) and warns when a newer candidate exists. Wired into `make quality`. Establishes a deterministic OS-security-pin model on the glibc runners (previously apt packages were installed unpinned).
- **`ruff` in `goneat-tools-runner-{glibc,musl}`** (pinned to `0.15.22`, goneat's recommended foundation version). `goneat format` / `goneat assess` auto-detect Python sources and dispatch to `ruff`; the runners previously shipped python3/uv/maturin/pytest but not the formatter goneat actually invokes, so any repository that added `.py` files failed in hosted CI. Reported by a downstream consumer running against `goneat-tools-runner-glibc`.
- **Python lint/format e2e coverage** — `make test-goneat-tools-runner-python` (and its `-glibc` twin) via `scripts/test-runner-python.sh`, backed by `tests/fixtures/python/{good,bad}`. Asserts that `goneat format --check` passes on a ruff-clean fixture and fails on an unformatted one **for format drift rather than for a missing executable** — the distinction that separates a working ruff from an absent one. `tests/fixtures/python/bad/` is listed in a new `.goneatignore` so the repository's own formatting runs cannot quietly fix the fixture.
- **`GO_VERSION` pin validation** — `scripts/validate-pins.sh` now checks the Go toolchain version in both goneat runner Dockerfiles against `manifests/tools.json`. This pin was previously unchecked, and the manifest had silently drifted to `1.26.2` while the Dockerfiles carried `1.26.4`.

### Changed

- **`libgnutls30` security-pinned to `3.7.9-2+deb12u7`** on both glibc runners (`goneat-tools-runner-glibc`, `sbom-tools-runner-glibc`), closing CRITICAL `CVE-2026-33845` / `CVE-2026-42010` and HIGH `CVE-2026-33846` / `CVE-2026-3833` / `CVE-2026-42009`. The bookworm-slim base lags the security repo (ships `deb12u6`); a base-digest refresh alone cannot close this — the explicit apt pin forces the patched build. Pin presence is enforced by `validate-pins`, availability by `validate-apt-pins`.
- **Go toolchain `1.26.2 → 1.26.5`** (`GO_VERSION` + checksums + the coupled `GO_IMAGE` builder digest, kept in sync) on both goneat runners. Rebuilds the in-house Go tools (goneat, golangci-lint, shfmt, yamlfmt, checkmake, actionlint, shellsentry) and ships the patched `/opt/go` toolchain, clearing the Go-stdlib CVE class embedded in those binaries.
- **`goneat v0.5.9 → v0.5.15`** — picks up patched `go-git` (v5.19.0), `go-billy` (v5.9.0), and OpenTelemetry (v1.43.0) dependencies, clearing `CVE-2026-44973`, `CVE-2026-45022`, `CVE-2026-29181`, `CVE-2026-39883`. (v0.5.13/v0.5.14 were drop-ins over v0.5.12 — YAML check/apply fidelity + markdown-lint additions; CVE-relevant deps unchanged.)
- **Behavior change — `goneat format` now fails closed on a missing formatter.** As of goneat v0.5.15, standalone `goneat format` preflights the external formatters it would dispatch to and exits non-zero if one is unavailable, instead of completing with silently incomplete coverage. `goneat assess` still reports such files as skipped, and `--ignore-missing-tools` opts out. This is why `ruff` ships in the same release: without it, a repository containing `.py` files would go from _quietly unformatted_ to a _hard CI failure_ on upgrade. Consumers who relied on the previous silent-skip for a formatter that is not installed in their own pipeline should expect a new failure and either install the tool or pass `--ignore-missing-tools`.
- **Bundled scanner/tool bumps** to clear vendored-dependency CVEs (grpc, docker/cli, containerd, go-git, OpenTelemetry, and their stdlib): `syft v1.41.1 → v1.50.0`, `grype v0.107.1 → v0.116.1`, `trivy v0.69.3 → v0.72.0` (sbom-tools), `yq v4.49.2 → v4.53.3` (glibc fetched binary). Updated in lockstep across the Dockerfiles and `manifests/tools.json`. syft and grype were initially held one release back for soak time; they were subsequently adopted because `v1.50.0`/`v0.116.1` carry `google.golang.org/grpc v1.82.1`, which closes `GHSA-hrxh-6v49-42gf`.
- **`sfetch v0.4.5 → v0.4.9` and `shellsentry v0.1.4 → v0.1.5`** — both pick up `golang.org/x/crypto v0.54.0`, clearing nine HIGH advisories (`CVE-2026-39828`/`-39829`/`-39830`/`-39831`/`-39832`/`-39835`/`-42508`/`-46595`/`-46597`). The two binaries carried the same CVE set from different `x/crypto` versions, so both had to move before any of the nine cleared.
- **`npm` pinned to `12.0.1`** on both goneat runners, overriding the npm bundled in the node base image. The base's npm 10.9.x bundles a dependency tree carrying CRITICAL `CVE-2026-59873` (`tar`) plus HIGH `CVE-2026-59874`, `CVE-2026-48815` (`sigstore`) and `CVE-2026-13149` (`brace-expansion`); those packages live under `/usr/local/lib/node_modules/npm/node_modules/` and are unreachable except by updating npm itself. Covered by `validate-pins` and `manifests/tools.json`. This pin must be re-verified on every node base digest bump and dropped once the base catches up — see `RELEASE_CHECKLIST.md`.
- **musl `yq-go` `4.49.2-r6 → 4.53.3-r0`**, converging the musl runner with the glibc binary pin (`v4.53.3`). The previous release noted that no newer build existed in the alpine repos; one has since landed.
- **Alpine runner base moved `3.23 → 3.24`** (`node:22-alpine` upstream rebase, now Alpine 3.24.1), which rotated the packaged versions of several pinned apk packages: `bash 5.3.3-r1 → 5.3.9-r1`, `curl 8.19.0-r0 → 8.21.0-r0`, `git 2.52.0-r0 → 2.54.0-r0`, `minisign 0.12-r1 → 0.12-r2`. Caught deterministically by `make validate-apk-pins`. (sbom-tools stays on `alpine:3.21`; its pins are unaffected.)
- **Final-stage base image digests refreshed** so the runtime bases rebuild on patched OS package sets: `node:22-alpine`, `node:22-bookworm-slim` (goneat musl/glibc), `debian:bookworm-slim` (sbom glibc + valkey), and the `golang:1.26-{alpine,bookworm}` builders. Lockstep across `manifests/tools.json` and the Dockerfiles. The two glibc images had drifted onto _different_ `debian:bookworm-slim` digests and are now converged. (`alpine:3.21` was already current.)

### Notes

- **`CGO_ENABLED=1` runner preset documented.** The `-runner-{glibc,musl}` images preset `CGO_ENABLED=1` (intentional — the runner is CGO-capable). This overrides Go's per-target default of `0`, so a plain `go build` for a non-native `GOOS`/`GOARCH` fails (`gcc: error: unrecognized command-line option '-m64'`), and a Makefile `CGO_ENABLED ?= 0` is silently overridden by the image env. Consumers building static or cross-compiled binaries should set `CGO_ENABLED=0` explicitly (use `:=`/`override`, not `?=`). See `docs/user-guide/container-usage-patterns.md` and `docs/images/goneat-tools.md`. Whether to drop the preset entirely is tracked in #14 for a future minor.
- **CVE posture:** this release sweeps every _actionable_ HIGH/CRITICAL on the published images (OS security pin + toolchain + bundled-tool bumps). Two residual categories remain, neither a regression: (1) the _no-fix_ class already excluded by the cve-scan gate (`ignore-unfixed: true`) — dominated by `linux-libc-dev` (kernel-header package; not applicable in-container) plus Debian won't-fix entries (`zlib1g` CVE-2023-45853, `libsqlite3`) and unfixed-upstream `python3.11`/`perl`; and (2) a small set of findings that are fixed in a dependency but for which **no upstream release of the prebuilt tool ships the fix yet** — currently one `grype` vendored dependency (`docker/docker`, unchanged through the newest `v0.116.1`) and `picomatch` inside the node base's bundled npm. We ship the latest reviewed upstream version of each; these are tracked with time-boxed, rationale-bearing entries in `.trivyignore` (review by 2026-10-28) and will be dropped as upstream rebuilds land. The eight `yq` Go-stdlib entries carried previously have been **dropped** — `yq v4.53.3` is built with go1.26.4, past the fix line.
- First tagged release to carry the post-v0.4.2 CI/curation fixes (#6 trivy-action pin, #7 RELEASE_CHECKLIST hardening, #11 valkey curation parity, #12 cve-scan hardening).

## [0.4.2] - 2026-05-18

### Changed

- **`.github/workflows/release.yml`** — split the previous single `release` job into three jobs (`build` → `manifest` → `cosign`). Per-arch builds now run on **native runners** (`ubuntu-latest-m` for amd64, `ubuntu-latest-arm64-s` for arm64) and push by digest only; a new `manifest` aggregator job composes the multi-arch manifest at every canonical and alias tag via `docker buildx imagetools create`. Removes QEMU emulation from the release path entirely. Motivated by v0.4.1's `goneat-tools-runner-musl` arm64 build failing with exit-132 (SIGILL) during qemu-user aarch64 emulation — Azure VM physical-host placement lottery that re-runs could not reliably escape.
- **`images/goneat-tools/Dockerfile`** — `CURL_VERSION` 8.17.0-r1 → 8.19.0-r0, `YQ_VERSION` 4.49.2-r5 → 4.49.2-r6. Forced by alpine 3.23 (`node:22-alpine` base) package-repo rotation between v0.4.1 (2026-05-05) and now; the older pins are no longer available upstream. Caught and fixed deterministically thanks to the rc.1 dry-run of the workflow change.
- **`manifests/tools.json`** — corresponding canonical `curl` and `yq-go` version entries bumped to match.

### Added

- **Pre-release tag guard** in the release workflow's tag-computation step: when `$VERSION` contains a `-` (e.g. `v0.4.2-rc.1`), publish only the exact `:v$VERSION` tag and skip `:latest` / `:v<major>`; mark the GitHub release as prerelease and non-latest. Removes a long-standing foot-gun where any pre-release tag would have moved consumer-visible floating tags.

### Removed

- **v0.4.1 GitHub Release page** — deleted to avoid showing a partial release (the `goneat-tools-runner-musl:v0.4.1` image was never published due to the SIGILL). The `v0.4.1` git tag remains in history for traceability. Consumers should resolve to `:v0.4.2` (or `:v0` / `:latest`) for the full image set.

### Notes

- Image content for the 5 successfully-published v0.4.1 image variants is functionally identical to v0.4.2 modulo the two apk pin bumps in `goneat-tools-runner-musl`. Consumers tracking `:v0` see no functional delta beyond those package revisions.
- The `:v0` and `:latest` floating tags for `goneat-tools-runner-musl` were stuck on the v0.4.0 digest since v0.4.1's partial-release; v0.4.2 unblocks them.
- arm64 release wall-clock dropped from ≈1h+ (per-image QEMU emulation) to ≈12 min native at the largest image (`goneat-tools-runner-glibc`). Per-arch jobs run in parallel; net release wall-clock substantially reduced.

## [0.4.1] - 2026-05-05

### Added

- **`include_prereleases` workflow_dispatch input** on `cve-scan.yml`: when set true, widens tag regex to also include `vX.Y.Z-*` (RC, beta) for one-shot manual scans. Cron behavior unchanged (prereleases still excluded).
- **AGENTS.md "Post-Mutation Tree Check" section**: mandatory `git status` after running mutating make targets (`pr-final`, `fmt-sh`) so agent runs don't silently leave drift behind.

### Changed

- **`.github/workflows/cve-scan.yml`** tracker rendering now reports both per-cell sum and unique-CVE count: `**Total findings:** N (M unique CVE IDs)`. Per-image visibility unchanged; the unique count answers the "how many root issues" question without mental dedup. (Per namelens v0.4.0 PR review.)
- **Makefile**: `.PHONY:` block rewritten from a single backslash-continuation directive to multiple grouped directives so `checkmake`'s `phonydeclared` rule parses correctly. Sixteen previously-missing target names added in the audit.
- **`.goneat/assess.yaml`**: re-enabled `make.checkmake` with `max_body_length=120` and `min_phony_targets=[all, clean]` (`test` dropped because this repo uses `test-all`). Disabled in v0.4.0 because of the `phonydeclared` parser issue; the Makefile rewrite resolves it.
- **`images/goneat-tools{-glibc,}/Dockerfile`**: comment block above `ARG GO_IMAGE` documenting the `GO_IMAGE` ↔ `GO_VERSION` coupling so future Go-toolchain bumps don't desync builder Go vs runtime Go.
- **Markdown italic style** in `RELEASE_NOTES.md` / `docs/releases/v0.4.0.md` / `docs/images/goneat-tools.md` normalized to triplet baseline (`_foo_` not `*foo*`). Cosmetic only.

### Notes

No image-content changes. Consumers tracking `:v0` see no functional delta vs v0.4.0; this is repo hygiene.

## [0.4.0] - 2026-05-04

### Added

- **golangci-lint v2.12.1** bundled in `goneat-tools-runner-{musl,glibc}`. Built in-runner against the pinned Go (1.26.2) so consumer configs targeting that Go version no longer hit "language version too low". License: GPL-3.0-only (runner is copyleft-by-design). NOT included in slim variants.
- **Scheduled trivy CVE-scan workflow** (`.github/workflows/cve-scan.yml`). Twice-weekly (Mon/Thu 06:00 UTC) scan of all 6 published image variants × 3 tags (`:latest` + 2 most recent pinned semver) = 18 cells. Aggregates findings into a single rolling tracker issue labeled `cve-watch`. `workflow_dispatch` supports severity override + dry-run for synthetic tests.
- **YAML config triplet**: `.yamlfmt`, `.yamllint`, `.goneat/assess.yaml` aligned with the goneat appnote on yaml-format-lint-alignment. Sets `pad_line_comments: 2` explicitly to avoid yamlfmt-vs-yamllint oscillation.
- **`make pr-final`**: strict local gate that runs `goneat format` then `goneat assess --check --categories format,lint,security --fail-on medium`.
- `.trivyignore` placeholder for CVE allowlist with rationale + review-by date format.

### Changed

- Repo-wide cosmetic format normalization to the new yaml triplet baseline (markdown table padding, JSON array expansion). No semantic content changes; suitable for `.git-blame-ignore-revs` if desired.

### Migration

⚠ Consumers using `golangci/golangci-lint-action@v7` (or any separate `go install`/install-script step) inside the runner: **drop the separate install step** to use the bundled binary. The bundled binary is the only one built against the runner's pinned Go. See `docs/releases/v0.4.0.md` for migration guidance.

## [0.3.5] - 2026-05-02

### Changed

- **Go pin** 1.26.1 → 1.26.2 (clears CVE-2026-33810 high; unblocks downstream consumers whose `golangci-lint` configs target `go 1.26.2`).
- **Builder image digests** refreshed for `golang:1.26-bookworm` and `golang:1.26-alpine` (now resolve to Go 1.26.2).
- **yq-go (apk)** 4.49.2-r4 → 4.49.2-r5 (Alpine package revision; r4 no longer available upstream).

## [0.3.4] - 2026-03-25

### Changed

- **goneat** v0.5.8 → v0.5.9 (bug fixes)
- **Go pin** 1.26 → 1.26.1 (eliminate dependency vulnerability noise)
- **bootstrap-tools.sh**: Refactored to arg-based interface with env var overrides

## [0.3.3] - 2026-03-18

### Changed

- **Tool updates (6 packages)**:
  - `goneat` v0.5.2 → v0.5.8
  - `sfetch` v0.4.1 → v0.4.5
  - `shellsentry` v0.1.1 → v0.1.4
  - `trivy` v0.69.0 → v0.69.3 (v0.69.0 ARM64 release asset unavailable upstream)
  - `yq-go` (apk) 4.49.2-r2 → 4.49.2-r4 (Alpine package revision)
  - Go builder 1.25 → 1.26.1 (required for shellsentry v0.1.4)
- **AGENTS.md**: Tightened agentic attribution standard; added Default Role and Identity rows, required `noreply@3leaps.net` in `Co-Authored-By`, updated example to Claude Sonnet 4.6.

## [0.3.2] - 2026-02-04

### Changed

- **Tool updates (13 packages)**:
  - `sfetch` v0.4.0 → v0.4.1 (bug fix: 403 errors on certain GitHub asset downloads)
  - `goneat` v0.4.4 → v0.5.2
  - `prettier` 3.7.4 → 3.8.0 (Angular v21.1 support)
  - `biome` 2.3.8 → 2.3.11
  - `yamlfmt` v0.20.0 → v0.21.0 (stdin reading fixes)
  - `actionlint` v1.7.9 → v1.7.10 (ubuntu-slim runner support)
  - `checkmake` 0.2.2 → v0.3.2 (repo moved to checkmake/checkmake)
  - `syft` v1.39.0 → v1.41.1 (CycloneDX bug fixes)
  - `grype` v0.104.3 → v0.107.1 (DB schema v6 improvements)
  - `trivy` v0.68.1 → v0.69.0
  - `cargo-nextest` 0.9.120 → 0.9.122 (pager support)
  - `uv` 0.9.24 → 0.9.28 (OpenSSL 3.5.5 security fixes)
  - `yq-go` (apk) 4.49.2-r1 → 4.49.2-r2

### Fixed

- Updated checkmake import path after upstream repo migration from `mrtazz/checkmake` to `checkmake/checkmake`.

## [0.3.1] - 2026-01-12

### Added

- **Polyglot runner toolchains**: goneat-tools runners now include full build toolchains:
  - Rust 1.92.0 via rustup with 7 cross-compilation targets (linux gnu/musl, darwin, windows-gnu)
  - Cargo tools: cargo-deny, cargo-audit, cargo-zigbuild, cargo-nextest, cbindgen
  - Go 1.25.5 with CGO support
  - Zig 0.15.2 for cross-compilation
  - Python 3 + uv, maturin, pytest
  - Node/TypeScript: napi-rs CLI for native addon builds
  - SBOM tools: syft + grype included in runners
- **Subsystems framework**: New `subsystems/` taxonomy element for multi-container coordinated deployments:
  - `subsystems/echo-proxy-fixture`: Evaluation-scale nginx + echo backend stack
  - `subsystems/authentik-idp`: Enterprise IdP (Authentik) with blueprints, presets, OIDC
  - `schemas/subsystem-manifest.schema.json`: JSON Schema for MANIFEST.yaml validation
  - `make validate-subsystems`: CI validation for subsystem manifests and compose files
  - `docs/standards/subsystem-standard.md`: Normative specification
- **Build infrastructure**:
  - `docker-bake.hcl`: Parallel multi-image builds with shared cache
  - `make prove*` targets: Fast local validation (native arch parallel builds)
  - Local cache support: `make prove CACHE=1` for faster rebuilds
- **Developer tooling**:
  - `make bootstrap`: Uses sfetch -> goneat trust chain to install foundation tools
  - `.goneat/tools.yaml`: Scoped tool definitions for reproducible local environments
  - `docs/user-guide/preflight.md`: Prerequisites documentation
- **shellsentry**: Added to goneat/sbom runner images for static shell script risk assessment.

### Changed

- Replaced manual prereqs checking with goneat doctor tools for consistent cross-platform tool management.
- Container runtime tools (docker, colima) are now advisory-only in bootstrap; users install manually.
- Bumped `goneat` to v0.4.4.
- Bumped `sfetch` to v0.4.0.
- Bumped `syft` to v1.39.0, `grype` to v0.104.3 in sbom images.

### Known Limitations

- **arm64 musl runners**: `cargo-audit` and `cargo-nextest` skip on arm64 musl (upstream glibc-only binaries). Use `-runner-glibc` for full toolchain on arm64.

## [0.3.0] - 2026-01-05

### Added

- **Canonical tag taxonomy (ADR-0006)**: Image names now include libc dimension (`-runner-musl`, `-slim-musl`, `-runner-glibc`). Short-name aliases remain for compatibility.
- **Application image class**: New `manifests/apps.json` schema and `schemas/app-manifest.schema.json` for server/service images (distinct from tool images).
- **valkey-server-glibc**: First application image — Valkey (Redis-compatible) key-value store as vendor-image repack.
- **server_minimal_apt profile**: Minimal baseline for production server images (`ca-certificates`, `tzdata`).
- **Image taxonomy standard**: `docs/standards/image-taxonomy.md` as normative reference for naming conventions.

### Changed

- Renamed tool images to canonical form: `goneat-tools-runner` → `goneat-tools-runner-musl`, etc.
- Release and build workflows updated to publish canonical tags with alias mappings.
- Marked `scripts/release.sh` as legacy (v0.2.x era); CI workflow is the canonical release path.

### Fixed

- Tool manifest schema now enforces valid image ID patterns (`^[a-z0-9][a-z0-9-]*$`).

## [0.2.4] - 2026-01-03

- Bumped `goneat` to v0.4.2.
- Bumped `sfetch` to v0.3.2.

## Older Releases

For earlier history, see GitHub Releases: https://github.com/fulmenhq/fulmen-toolbox/releases

[Unreleased]: https://github.com/fulmenhq/fulmen-toolbox/compare/v0.4.2...HEAD
[0.4.2]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.4.2
[0.4.1]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.4.1
[0.4.0]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.4.0
[0.3.5]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.5
[0.3.4]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.4
[0.3.3]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.3
[0.3.2]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.2
[0.3.1]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.1
[0.3.0]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.3.0
[0.2.4]: https://github.com/fulmenhq/fulmen-toolbox/releases/tag/v0.2.4
