# Image Inventory

## goneat-tools
- Purpose: code quality/formatting toolkit for CI and local use.
- Current tools: Prettier (3.7.4), Biome (2.3.8), yamlfmt (v0.20.0), jq (1.8.1-r0), yq-go (4.49.2-r1), ripgrep (15.1.0-r0), taplo (0.10.0-r0), bash (5.3.3-r1), git (2.52.0-r0).
- Base: `node:22-alpine@sha256:9632533...`; builder `golang:1.23-alpine@sha256:383395...`.
- Version policy: pin all tool versions; curate bumps; expose `:v<major>`, `:latest`, and semver tags.
- Signing: cosign signatures + attestations (planned), GPG/minisign for `SHA256SUMS`.
- Manifest: see `manifests/tools.json` (validated against `schemas/tool-manifest.schema.json` via `make validate-manifest`).

## sbom-tools (planned)
- Purpose: SBOM and vulnerability scanning (e.g., syft, grype).
- Status: placeholder directory only.
- Version policy/signing: same as above once implemented.
