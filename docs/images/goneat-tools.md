# goneat-tools Image

Purpose: containerized code quality/formatting toolkit for CI and local runs.

## Versions (Pinned)
- Base: `node:22-alpine@sha256:9632533eda8061fc1e9960cfb3f8762781c07a00ee7317f5dc0e13c05e15166f`
- Builder: `golang:1.23-alpine@sha256:383395b794dffa5b53012a212365d40c8e37109a626ca30d6151c8348d380b5f`
- Prettier: `3.7.4` (npm global)
- Biome: `2.3.8` (npm global)
- yamlfmt: `v0.20.0` (Go install)
- jq: `1.8.1-r0` (apk)
- yq-go: `4.49.2-r1` (apk)
- ripgrep: `15.1.0-r0` (apk)
- taplo: `0.10.0-r0` (apk)
- bash: `5.3.3-r1` (apk)
- git: `2.52.0-r0` (apk)

See `manifests/tools.json` for SSOT and `make validate-manifest` for schema validation.

## Pinning Strategy
- All tool versions and base images pinned explicitly (Dockerfile ARGs).
- Bumps are curated; bump manifest + Dockerfile together, update CHANGELOG/RELEASE_NOTES.
- Tagging: semver from `VERSION`; `:latest` and `:v<major>` track the newest for that line.

## Usage Notes
- CI can pull by digest for reproducibility.
- yamlfmt required locally for workflow linting (`make lint-workflows` / `make quality`).
- Docker daemon required for builds/tests and manifest validation (uses Dockerized ajv).
