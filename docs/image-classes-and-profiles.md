# Image Classes and Baseline Profiles

Fulmen Toolbox images are built from two orthogonal concepts:

- **Image family (purpose)**: what the image is for (toolbox, sbom, appserver, etc.)
- **Baseline profile (capabilities)**: what baseline system utilities are present (runner vs server vs minimal)

This separation keeps the repo DRY: when baseline needs change, we update a single profile manifest and validate that images conform.

## Layering Model

```mermaid
graph TD
  subgraph "Manifests (SSOT)"
    T[manifests/tools.json\nTool payload + pins] -->|per-image| I
    P[manifests/profiles.json\nBaseline profiles] -->|baseline rules| I
  end

  subgraph "Build Outputs"
    I[Image family Dockerfile(s)] --> S[<family>-slim\nTools only]
    S --> R[<family>-runner\nSlim + runner_baseline]
    B[<app>-server\nServer profile + runtime + app]
  end

  subgraph "Profiles"
    RB[runner_baseline\nCI job container expectations]
    SB[server_* (planned)\nProduction runtime expectations]
  end

  RB --> R
  SB --> B
```

ASCII view (same idea):

- `base` (pinned distro + non-root + licenses/notices)
  - `tool payload` (from `manifests/tools.json`) => `<family>-slim`
    - `runner_baseline` (from `manifests/profiles.json`) => `<family>-runner`
  - `server_*` (planned profiles) + runtime + app => `<app>-server`

## Baseline Profiles (Package Sets)

### `runner_baseline` (SSOT)

The source of truth is `manifests/profiles.json`.

- Goal: behave like a reliable CI job container (shell scripts, checkout, archives, HTTPS fetch).
- Copyleft: expected (by design); disclose via `/licenses` and `/notices` and treat as mere aggregation.

Current `runner_baseline` (apk packages):

| Package |
|--------:|
| `bash` |
| `ca-certificates` |
| `coreutils` |
| `curl` |
| `diffutils` |
| `findutils` |
| `git` |
| `gzip` |
| `make` |
| `openssh-client` |
| `tar` |
| `unzip` |
| `xz` |

Notes:
- We intentionally include `openssh-client` in the runner baseline; appserver images should not inherit it by default.
- Candidate additions seen in real CI workflows (not yet baseline): `grep` (GNU grep), `zstd`.

### Server profiles (planned)

Server images are **production runtime containers**, not CI runners.

- Goal: minimal footprint + minimal attack surface.
- Default stance: avoid adding shells and build tooling; avoid adding GPLv3 best-effort.

Planned profiles (not yet in `manifests/profiles.json`):

| Profile | Intended packages |
|--------|-------------------|
| `server_minimal` | `ca-certificates`, `tzdata` |
| `server_standard` (optional) | `server_minimal` + `curl` (and possibly a minimal shell, if explicitly required) |
| `server_debug` (non-production) | explicit debug tooling only |

## Image Classes

### Toolbox images (Fulmen Toolbox)

Examples: `goneat-tools`, `sbom-tools`.

- `*-slim`: tool payload only (best-effort minimized baseline)
- `*-runner`: `*-slim` + `runner_baseline`

### Runner images (CI job containers)

Runner images are meant to be used directly in CI systems as the job container.

- Assumption: users run as non-root; do not rely on `apk add` at runtime.
- If you need additional packages, derive your own image.

### Appserver images (production runtime)

Appserver images are designed for running FulmenHQ applications in production.

- Do **not** treat appserver images as CI runners.
- Do **not** include runner baseline packages by default (e.g., `openssh-client`, `git`, `make`).
- Provide the minimal runtime needed by the application (Go/TS/Python runtime strategy is app-specific).

## Download and Verification Tooling (`curl` vs `sfetch`)

These tools serve different roles:

- `curl` is a pragmatic baseline tool for runners (ubiquitous; used by many scripts).
- `sfetch` (from `~/dev/3leaps/sfetch`) is a **trust anchor / foundation layer** for downloads:
  - It defaults to requiring **signature and checksum verification** for GitHub release assets.
  - It reduces the "curl + verify" bash glue in CI by making verification the default behavior.
  - It has no runtime deps for minisign/raw-ed25519 modes; it requires `gpg` only for PGP verification.

Recommendation:
- Keep `curl` in `runner_baseline`.
- Consider adding `sfetch` as a curated tool in specific runner-focused images (not a baseline package) once we decide on its pinning model and how we distribute/manage its trust anchors.

## Non-root Extension Pattern (Recommended)

If you need extra packages or tools:

```dockerfile
FROM ghcr.io/fulmenhq/goneat-tools-runner:latest
USER root
RUN apk add --no-cache <your-extra-packages>
USER 65534:65534
```

For production appserver images, prefer building a dedicated image family (`<app>-server`) rather than extending a toolbox runner.
