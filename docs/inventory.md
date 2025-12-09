# Image Inventory

## goneat-tools
- Purpose: code quality/formatting toolkit for CI and local use.
- Current tools: Prettier (3.7.4), Biome (2.3.8), yamlfmt (v0.20.0), jq (1.8.1-r0), yq-go (4.49.2-r1), ripgrep (15.1.0-r0), taplo (0.10.0-r0), bash (5.3.3-r1), git (2.52.0-r0).
- Base: `node:22-alpine@sha256:9632533...`; builder `golang:1.23-alpine@sha256:383395...`.
- Version policy: pin all tool versions; curate bumps; expose `:v<major>`, `:latest`, and semver tags.
- Signing: cosign signatures + attestations (planned), GPG/minisign for `SHA256SUMS`.
- Manifest: see `manifests/tools.json` (validated against `schemas/tool-manifest.schema.json` via `make validate-manifest`).

## sbom-tools
- Purpose: SBOM generation and vulnerability scanning for CI and local use.
- Current tools: syft (v1.18.1), grype (v0.86.1), trivy (v0.68.1); jq (1.8.1-r0), yq-go (4.49.2-r1), git (2.52.0-r0) for shaping outputs and CI checkouts.
- Base: `alpine:3.21@sha256:5405e8f3...`.
- Size target: ~80-120MB.
- Output formats: CycloneDX JSON (default), SPDX JSON.
- Note: Grype pulls vulnerability DB on first run (~150MB); recommend caching for CI.
- Version policy: pin all tool versions; curate bumps; expose `:v<major>`, `:latest`, and semver tags.
- Signing: same as goneat-tools (cosign + GPG/minisign).
- Manifest: see `manifests/tools.json`.
