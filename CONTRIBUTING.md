# Contributing to Fulmen Toolbox

This guide covers local development setup for maintainers and contributors.

## Prerequisites

### Core Tools (day-to-day development)

| Tool | Purpose | Install |
|------|---------|---------|
| Docker runtime | Build/test images | See [Docker Runtime Setup](#docker-runtime-setup) |
| docker-buildx | Multi-arch builds | `brew install docker-buildx` (separate with Colima) |
| jq | JSON processing, pin validation | `brew install jq` |
| yamlfmt | Workflow linting | `go install github.com/google/yamlfmt/cmd/yamlfmt@v0.20.0` |
| trivy | Dockerfile linting | `brew install trivy` |

**Quick install:**
```bash
brew install colima docker docker-buildx jq trivy
go install github.com/google/yamlfmt/cmd/yamlfmt@v0.20.0
colima start
```

**Configure docker-buildx plugin** (required for Colima):
```bash
# Add plugin path to Docker config (one-time setup)
jq '. + {"cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"]}' \
  ~/.docker/config.json > ~/.docker/config.json.tmp && \
  mv ~/.docker/config.json.tmp ~/.docker/config.json

# Verify
docker buildx version
```

> **Note:** `docker-buildx` is required for multi-arch builds. With Colima, it's a separate brew package that needs the config above. Docker Desktop includes it automatically.

### Release Tools (signing workflow only)

These are only needed when cutting releases, not for day-to-day development:

| Tool | Purpose | Install |
|------|---------|---------|
| cosign | Image signing | `brew install cosign` |
| gpg | Artifact signing | `brew install gnupg` |
| minisign | Artifact signing | `brew install minisign` |
| syft | SBOM generation | `brew install syft` |

### Optional Tools

| Tool | Purpose | Install |
|------|---------|---------|
| shellcheck | Shell script analysis (GPL) | `brew install shellcheck` |
| shfmt | Shell formatting | `go install mvdan.cc/sh/v3/cmd/shfmt@latest` |

Run `make bootstrap` to check your setup.

## Docker Runtime Setup

You need a Docker-compatible runtime. We recommend **Colima** for macOS (free, lightweight).

### Option 1: Colima (Recommended for macOS)

```bash
# Install
brew install colima docker

# Start (creates ~/.colima/default/docker.sock)
colima start

# Verify
docker info
```

**Starting Colima:**

```bash
# Interactive (blocks terminal)
colima start

# Background (returns immediately)
colima start &

# Or with nohup (persists after terminal close)
nohup colima start > /dev/null 2>&1 &
```

**Auto-start as service (recommended):**

```bash
# Configure Colima to start on login
brew services start colima

# Check service status
brew services list | grep colima

# Stop the service
brew services stop colima
```

**Colima tips:**
- More resources: `colima start --cpu 4 --memory 8`
- Stop manually: `colima stop`
- Check status: `colima status`

### Option 2: Docker Desktop

Download from [docker.com](https://www.docker.com/products/docker-desktop/). Note: Docker Desktop has licensing restrictions for enterprise use.

### Option 3: Rancher Desktop

Download from [rancherdesktop.io](https://rancherdesktop.io/). Use **dockerd** runtime (not containerd) for compatibility.

## Make Targets

### No Docker Required

These targets work without a running Docker daemon:

```bash
make bootstrap          # Check tooling (reports Docker status)
make check-quick        # Quick validation: pins + lint (no Docker)
make validate-pins      # Verify Dockerfile pins match manifest
make lint-workflows     # Lint GitHub Actions YAML (needs yamlfmt)
make lint-dockerfiles   # Lint Dockerfiles with trivy
```

### Docker Required

These targets require a running Docker daemon:

```bash
make build-goneat-tools       # Build single-arch image
make build-goneat-tools-multi # Build multi-arch image
make test-goneat-tools        # Run tool version checks in container
make build-sbom-tools         # Build sbom-tools image
make test-sbom-tools          # Test sbom-tools
make validate-manifest        # JSON schema validation (uses dockerized ajv)
make quality                  # Full quality suite (includes validate-manifest)
make prepush                  # Pre-push checks (quality + build + test)
```

## Troubleshooting

### "docker.sock: no such file or directory"

**Cause:** Docker daemon not running.

**Fix (Colima):**
```bash
colima status        # Check if running
colima start         # Start if stopped
```

**Fix (Docker Desktop):** Open Docker Desktop app and wait for it to start.

### "Cannot connect to the Docker daemon"

**Cause:** Docker socket not found or permission denied.

**Fix (Colima):**
```bash
# Ensure DOCKER_HOST is set (add to ~/.zshrc or ~/.bashrc)
export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"

# Or create symlink (requires sudo)
sudo ln -sf ~/.colima/default/docker.sock /var/run/docker.sock
```

### "colima: command not found"

**Fix:**
```bash
brew install colima docker
colima start
```

### validate-manifest fails but validate-pins works

**Cause:** `validate-manifest` uses a Dockerized ajv validator; `validate-pins` is pure bash+jq.

**Fix:** Start Docker, or skip manifest validation for quick local checks:
```bash
make validate-pins      # Works without Docker
make lint-workflows     # Works without Docker
```

### "docker: unknown command: docker buildx"

**Cause:** With Colima, `docker-buildx` is a separate brew package and Docker needs to be configured to find it.

**Fix:**
```bash
# Install if missing
brew install docker-buildx

# Configure Docker to find the plugin
jq '. + {"cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"]}' \
  ~/.docker/config.json > ~/.docker/config.json.tmp && \
  mv ~/.docker/config.json.tmp ~/.docker/config.json

# Verify
docker buildx version
```

### Multi-arch build fails

**Cause:** buildx not configured or QEMU not available.

**Fix:**
```bash
# Create buildx builder with QEMU support
docker buildx create --use --name multiarch --driver docker-container
docker buildx inspect --bootstrap
```

## Development Workflow

### Quick Local Check (no Docker)

```bash
make check-quick        # Runs: validate-pins + lint-workflows + lint-dockerfiles
```

### Full Local Check (Docker required)

```bash
make prepush            # quality + build + test all images
```

### Recommended Pre-Commit Flow

1. **Always**: `make check-quick` (fast, no Docker)
2. **If changing Dockerfiles/tools**: `make build-goneat-tools && make test-goneat-tools`
3. **Before push**: `make prepush` (full validation)

### Testing a Single Image

```bash
make build-goneat-tools && make test-goneat-tools
make build-sbom-tools && make test-sbom-tools
```

## Adding New Tools

1. Add entry to `manifests/tools.json`
2. Add ARG + install to `images/<image>/Dockerfile`
3. Add pin check to `scripts/validate-pins.sh`
4. Add version check to `make test-<image>` target
5. Update `README.md` and `docs/images/<image>.md`
6. Run `make validate-pins` to verify sync

## Commit Attribution

All commits should include proper attribution per `AGENTS.md`:

```
feat: add shfmt to goneat-tools

Generated by Forge Neat under supervision of @3leapsdave

Co-Authored-By: Forge Neat <noreply@3leaps.net>
```

## Questions?

- Open an issue at [github.com/fulmenhq/fulmen-toolbox/issues](https://github.com/fulmenhq/fulmen-toolbox/issues)
- See `AGENTS.md` for AI agent coordination model
- See `MAINTAINERS.md` for project governance
