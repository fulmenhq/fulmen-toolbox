# Subsystem Standard

**Version**: 1.0.0-draft  
**Status**: Draft (targeting v0.3.1)

---

## Overview

A **Subsystem** is a multi-container deployment bundle that provides a coordinated service requiring more than one container to function. Subsystems use Docker Compose for orchestration and mounted configuration (not baked images) for flexibility.

This standard defines the structure, conventions, and validation requirements for subsystems in fulmen-toolbox.

## Goals

1. **Predictable structure**: Every subsystem follows the same layout
2. **Boot-and-run**: `docker compose up` yields a working system without manual setup
3. **Configuration agility**: Change settings without rebuilding images
4. **Machine-readable**: Schema-validated manifests enable automation
5. **Ecosystem alignment**: Prefer fulmen-toolbox images where applicable (e.g., valkey over redis)

## Non-Goals

1. Replace Kubernetes/Helm for production orchestration
2. Provide HA/clustering configurations (single-node focus)
3. Package subsystems as OCI artifacts (compose files stay in-repo)

---

## Directory Structure

Each subsystem lives under `subsystems/{name}/` and follows this structure:

```
subsystems/{name}/
├── MANIFEST.yaml              # SSOT: Subsystem metadata (schema-validated)
├── README.md                  # Human documentation
├── compose.yaml               # Primary compose file (runs from subsystem root)
├── compose.{variant}.yaml     # Optional variant overlays
├── config/                    # Mounted configuration (blueprints, templates, etc.)
│   ├── {config-type}/         # Organized by purpose
│   └── ...
├── presets/                   # Named .env files for common configurations
│   ├── dev-fixture.env
│   └── {preset-name}.env
├── secrets/                   # Secrets directory (gitignored contents)
│   ├── .gitignore             # Must contain: *\n!.gitignore\n!README.md
│   └── README.md              # Instructions for populating secrets
└── examples/                  # Optional: integration examples
    └── {example-name}/
```

### Required Files

| File            | Purpose                                             |
| --------------- | --------------------------------------------------- |
| `MANIFEST.yaml` | Machine-readable metadata; validated against schema |
| `README.md`     | Usage documentation, prerequisites, quick start     |
| `compose.yaml`  | Primary Docker Compose file                         |
| `presets/*.env` | At least one preset (typically `dev-fixture.env`)   |

---

## MANIFEST.yaml Specification

The manifest is the **single source of truth** for subsystem metadata. It must validate against `schemas/subsystem-manifest.schema.json`.

### Required Fields

```yaml
# MANIFEST.yaml
$schema: ../../schemas/subsystem-manifest.schema.json
name: authentik-idp # kebab-case, matches directory name
version: 0.1.0 # Subsystem version (semver)
description: >
  Brief description of what this subsystem provides
category: infrastructure # infrastructure | observability | messaging | other
status: prototype # prototype | stable | deprecated

provides: # Capabilities this subsystem offers
  - oidc-provider
  - forward-auth

dependencies: # External images required (not built by this repo)
  - image: postgres # Image reference without tag
    pin: "16-alpine" # Required: pinned tag or digest
    purpose: Database

presets: # At least one preset is required
  dev-fixture:
    description: Development testing with known credentials
    env_file: presets/dev-fixture.env
```

### Optional Fields

```yaml
upstream: # Primary upstream project (if wrapping vendor software)
  project: goauthentik/authentik
  version: "2024.12"
  image: ghcr.io/goauthentik/server
  docs_url: https://docs.goauthentik.io/

ports: # Default exposed ports (informational)
  - port: 9000
    protocol: http
    purpose: Web UI and API

custom_images: [] # Custom images built by this subsystem (rare)
```

---

## Compose File Conventions

### Working Directory

Compose files MUST be runnable from the **subsystem root directory**:

```bash
# Correct: run from subsystem directory
cd subsystems/authentik-idp
docker compose up -d

# Also correct: explicit file path from repo root
docker compose -f subsystems/authentik-idp/compose.yaml up -d
```

### Volume Mounts

Use paths relative to the compose file's directory (subsystem root):

```yaml
# CORRECT: relative to compose.yaml location (subsystem root)
volumes:
  - ./config/blueprints:/blueprints:ro
  - ./secrets:/secrets:ro
```

### Image Pinning Policy

**Rule**: No `:latest` tags except in presets explicitly marked `experimental: true`.

**Fulmen-internal images** (`ghcr.io/fulmenhq/*`): pin to a toolbox release tag (e.g., `v0.3.0`) or a concrete version.

### Health Checks

Health checks are recommended, but avoid depending on ad-hoc tooling inside upstream images (e.g., assuming `curl` or `wget` exists in a vendor image).

When deterministic readiness is important, prefer the **probe container pattern** below.

### Environment Variable Validation

Use shell parameter expansion for required variables:

```yaml
environment:
  # Required: fails fast if not set
  POSTGRES_PASSWORD: ${PG_PASS:?PG_PASS required}

  # Optional with default
  LOG_LEVEL: ${LOG_LEVEL:-info}
```

---

## Probe Container Pattern (Checks-Enabled Variant)

When you want to validate readiness/health semantics without relying on the contents of upstream images, add a small **probe** container in a compose variant overlay.

Benefits:

- Deterministic probing tooling (you pick the probe image)
- Proves container-to-container networking works
- Allows CI to validate “system ready” without browser automation

Recommended approach:

- Keep `compose.yaml` minimal (normal developer usage)
- Add `compose.with-checks.yaml` that adds a `probe` service
- Run with both files:

```bash
docker compose -f compose.yaml -f compose.with-checks.yaml up -d
```

Example overlay:

```yaml
# compose.with-checks.yaml
services:
  probe:
    image: alpine:3.21
    command: ["sh", "-c", "sleep 3600"]
    depends_on:
      - proxy
      - echo
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "wget -q --spider http://proxy/health && wget -q --spider http://echo:80/",
        ]
      interval: 5s
      timeout: 3s
      retries: 10
```

Notes:

- This pattern keeps the “check tooling” responsibility in a dedicated container.
- The subsystem smoke test can still use host-side `curl` for simplicity.

---

## Preset Conventions

Presets are `.env` files that configure a subsystem for a specific use case.

### Naming

- `dev-fixture.env` - Development/testing with known credentials (NOT FOR PRODUCTION)
- `small-scale-ops.env` - Production-ready single-node deployment
- `{custom-name}.env` - Domain-specific configurations

### Multiline Values

Docker Compose `.env` files do NOT support multiline values. For multiline configuration:

1. **Put complex values in config files**, not `.env`
2. **Use multiple variables** if env-based: `REDIRECT_URI_1=...`, `REDIRECT_URI_2=...`

---

## Secrets Management

### Directory Structure

```
secrets/
├── .gitignore          # MUST ignore all except .gitignore and README.md
└── README.md           # Instructions for populating secrets
```

### .gitignore Contents

```gitignore
# Ignore all files in this directory
*
# Except these documentation files
!.gitignore
!README.md
```

---

## CI Validation

Subsystems MUST pass validation before merge.

Recommended Make targets:

- `make validate-subsystems` (schema + compose config)
- `make test-subsystem-echo-proxy-fixture` (fast evaluation-scale smoke test)
- `make test-subsystem-authentik-idp` (complex smoke test; optional/nightly)

---

## Example: Minimal Subsystem (Evaluation-Scale)

We validate the subsystem standard with a minimal **multi-container** subsystem before implementing complex stacks (like identity providers). This ensures the schema, compose conventions, config mounts, and smoke test patterns work end-to-end with fast feedback.

```
subsystems/echo-proxy-fixture/
├── MANIFEST.yaml
├── README.md
├── compose.yaml
├── compose.with-checks.yaml
├── config/
│   └── nginx/
│       └── default.conf
└── presets/
    └── dev-fixture.env
```

**compose.yaml**:

```yaml
name: echo-proxy-fixture

services:
  echo:
    image: ealen/echo-server:0.9.2
    expose:
      - "80"
    environment:
      PORT: "80"

  proxy:
    image: nginx:1.27-alpine
    ports:
      - "${PROXY_PORT:-8080}:80"
    volumes:
      - ./config/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - echo
```

**compose.with-checks.yaml** (probe variant overlay):

```yaml
services:
  probe:
    image: alpine:3.21
    command: ["sh", "-c", "sleep 3600"]
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "wget -q --spider http://proxy/health && wget -q --spider http://echo:80/",
        ]
      interval: 5s
      timeout: 3s
      retries: 10
```

**config/nginx/default.conf**:

```nginx
server {
  listen 80;

  location = /health {
    return 200 "ok";
  }

  location / {
    proxy_set_header X-Fulmen-Proxy echo-proxy-fixture;
    proxy_pass http://echo:80;
  }
}
```

---

## References

- `schemas/subsystem-manifest.schema.json`
- `docs/standards/image-taxonomy.md`
