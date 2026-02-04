# Release Notes

## v0.3.2 (2026-02-04)

**Tool Updates + Bug Fixes**

This release updates 13 packages across goneat-tools and sbom-tools images, including a critical bug fix for sfetch and security updates for uv.

### Critical Fix

- **sfetch v0.4.1**: Fixes 403 errors that occurred when downloading certain GitHub release assets.

### Security Updates

- **uv 0.9.28**: Includes OpenSSL 3.5.5 security fixes.

### Tool Version Updates

| Tool | Previous | Current | Notes |
|------|----------|---------|-------|
| sfetch | v0.4.0 | v0.4.1 | Bug fix: GitHub asset 403s |
| goneat | v0.4.4 | v0.5.2 | Feature release |
| prettier | 3.7.4 | 3.8.0 | Angular v21.1 support |
| biome | 2.3.8 | 2.3.11 | Patch fixes |
| yamlfmt | v0.20.0 | v0.21.0 | stdin reading fixes |
| actionlint | v1.7.9 | v1.7.10 | ubuntu-slim runner support |
| checkmake | 0.2.2 | v0.3.2 | Repo moved to checkmake/checkmake |
| syft | v1.39.0 | v1.41.1 | CycloneDX bug fixes |
| grype | v0.104.3 | v0.107.1 | DB schema v6 improvements |
| trivy | v0.68.1 | v0.69.0 | Patch update |
| cargo-nextest | 0.9.120 | 0.9.122 | Pager support |
| uv | 0.9.24 | 0.9.28 | OpenSSL security fixes |
| yq-go (apk) | 4.49.2-r1 | 4.49.2-r2 | Alpine package revision |

### Breaking Changes

None. Existing image references continue to work.

### Migration Notes

- **checkmake**: Upstream repository moved from `mrtazz/checkmake` to `checkmake/checkmake`. No action required for image users; the tool works identically.

## v0.3.1 (2026-01-12)

**Polyglot Runner + Subsystems + Developer Tooling**

This release expands goneat-tools runners into full polyglot CI images, introduces the subsystems framework for multi-container deployments, and improves local development workflows.

### Polyglot Runner Toolchains

The goneat-tools runner images now include complete build toolchains for multi-language projects:

| Toolchain | Version | Capabilities |
|-----------|---------|--------------|
| **Rust** | 1.92.0 | rustup, rustfmt, clippy, 7 cross-compilation targets |
| **Cargo tools** | — | cargo-deny, cargo-audit, cargo-zigbuild, cargo-nextest, cbindgen |
| **Go** | 1.25.5 | CGO_ENABLED=1, full toolchain |
| **Zig** | 0.15.2 | Cross-compilation backend for cargo-zigbuild |
| **Python** | 3.11+ | uv, maturin (PyO3/Rust bindings), pytest |
| **Node** | 22.x | npm, napi-rs CLI for native addon builds |
| **SBOM** | — | syft 1.39.0, grype 0.104.3 |

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
