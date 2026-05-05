# Release Notes

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
