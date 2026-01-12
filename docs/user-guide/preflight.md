# Preflight (Local Development)

This guide covers the minimum local prerequisites to develop and validate changes in `fulmen-toolbox`.

If you are running Docker via Colima on macOS, this guide is the quickest way to ensure you have **Docker Compose v2** available (`docker compose`).

## Quick Checklist

You should be able to run:

- `docker version` (client + server)
- `docker compose version` (Compose v2)
- `docker buildx version` (for multi-arch builds)
- `make bootstrap` (sanity checks)

## Required (Day-to-Day)

- Docker runtime (Colima, Docker Desktop, etc.)
- Docker CLI (`docker`)
- Docker Compose v2 (`docker compose`)
- buildx plugin (`docker buildx`) for multi-arch builds
- `jq` (used by validation scripts)
- `yamlfmt` (workflow formatting/linting)
- `trivy` (Dockerfile linting)

Notes:
- Schema validation uses a Dockerized Node runtime, so you generally do **not** need Node.js installed locally.
- Some targets require a running Docker daemon (see `CONTRIBUTING.md`).

## macOS

### Recommended: Colima

1) Install core tooling:

```bash
brew install colima docker docker-compose docker-buildx jq trivy
```

2) Start Colima:

```bash
colima start
```

3) Ensure Docker can find CLI plugins (buildx/compose)

With Homebrew, plugins typically live at `/opt/homebrew/lib/docker/cli-plugins`. Add that directory to Docker’s plugin search path:

```bash
jq '. + {"cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"]}' \
  ~/.docker/config.json > ~/.docker/config.json.tmp && \
  mv ~/.docker/config.json.tmp ~/.docker/config.json
```

4) Verify:

```bash
docker compose version
docker buildx version
docker info
```

If `docker compose` is missing, Compose is not installed or Docker can’t find the plugin.

### Alternative: Docker Desktop

Docker Desktop includes Compose v2 and buildx by default.

## Linux

Install Docker Engine + Compose v2 plugin using your distro packages.

Typical requirements:
- `docker` (Engine)
- Compose plugin package (often `docker-compose-plugin`)
- `jq`
- `trivy`

Verify:

```bash
docker version
docker compose version
docker info
```

For multi-arch builds, ensure buildx is available:

```bash
docker buildx version
```

## Windows

### Recommended: WSL2 + Linux tooling

Use WSL2 for the smoothest path (Make targets, shell scripts, curl/jq usage).

Options:
- Docker Desktop with WSL2 integration (Compose v2 included)
- Rancher Desktop (configure for `dockerd` compatibility)

Verify inside WSL:

```bash
docker version
docker compose version
```

If you run Make targets outside WSL, expect extra friction around GNU tooling and shell scripts.

## Tool Install Notes

### `yamlfmt`

Install via Go:

```bash
go install github.com/google/yamlfmt/cmd/yamlfmt@v0.20.0
```

### Sanity checks

From repo root:

```bash
make bootstrap
make check-quick
```

For full validation (Docker required):

```bash
make prepush
```
