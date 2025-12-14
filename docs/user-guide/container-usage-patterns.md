# Container Usage Patterns

This guide explains two ways to use Fulmen Toolbox images. Many developers are familiar with running tasks *inside* a container, but fewer realize containers can replace locally-installed tools entirely.

## Choosing an Image Variant

Each toolbox image comes in two variants:

| Variant | Image Suffix | Best For | What's Included |
|---------|--------------|----------|-----------------|
| **Runner** | `-runner` | CI jobs, GitHub Actions, build tasks | Tools + bash, git, make, curl, coreutils |
| **Slim** | `-slim` | Local tool replacement, shell aliases | Tools only, minimal footprint |

### Decision Guide

**Use `-runner` when:**
- Running as a CI job container (GitHub Actions, GitLab CI, etc.)
- Your scripts need `bash`, `make`, `git`, or GNU coreutils
- You want a full shell environment with common utilities
- You need to fetch artifacts with `curl` or extract with `tar`

**Use `-slim` when:**
- Replacing locally-installed tools (via shell aliases)
- Running a single tool command (e.g., `prettier --write .`)
- You want a smaller image (and fewer baseline utilities)
- You want to minimize copyleft surface area (best-effort; not a guarantee)

### Examples

```bash
# CI job (runner) - has bash, make, git
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-runner:latest \
  bash -c "make lint && make format"

# Local tool replacement (slim) - just the tools
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim:latest \
  prettier --write "**/*.md"
```

> **Note:** Images without a suffix (`goneat-tools`, `sbom-tools`) are aliases for `-runner` variants.

---

## Usage Patterns

| Pattern | Use Case | Command Style |
|---------|----------|---------------|
| **Tool Replacement** | Run a single command without installing anything | `docker run --rm -v "$(pwd):/work" <image> <tool> <args>` |
| **Working Environment** | Interactive session inside container | `docker run --rm -it -v "$(pwd):/work" <image> sh` |

---

## Pattern 1: Tool Replacement (No Installation)

**Problem:** You need to run `prettier` or `yamlfmt` but don't want to install Node.js, Go, or manage tool versions locally.

**Solution:** Mount your project directory and run the tool via Docker.

### Basic Structure

```bash
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim:latest \
  <tool> <arguments>
```

| Flag | Purpose |
|------|---------|
| `--rm` | Remove container after exit (no clutter) |
| `-v "$(pwd):/work"` | Mount current directory into container at `/work` |
| `-w /work` | Set working directory inside container |

### Examples

**Format all Markdown/YAML files:**
```bash
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim:latest \
  prettier --write "**/*.{md,json,yml,yaml}"
```

**Check YAML formatting:**
```bash
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim:latest \
  yamlfmt -lint .
```

**Lint GitHub Actions workflows:**
```bash
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim:latest \
  actionlint
```

**Generate SBOM for a project:**
```bash
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/sbom-tools-slim:latest \
  syft dir:/work -o spdx-json
```

**Scan for vulnerabilities:**
```bash
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/sbom-tools-slim:latest \
  grype dir:/work
```

### Shell Aliases (Recommended)

Add to your `~/.bashrc` or `~/.zshrc`. Use `-slim` variants for local tool replacement (smaller, avoids the runner baseline):

```bash
# goneat-tools-slim aliases (recommended for local use)
alias prettier='docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim:latest prettier'
alias yamlfmt='docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim:latest yamlfmt'
alias biome='docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim:latest biome'
alias actionlint='docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim:latest actionlint'
alias shfmt='docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim:latest shfmt'

# sbom-tools-slim aliases (recommended for local use)
alias syft='docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/sbom-tools-slim:latest syft'
alias grype='docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/sbom-tools-slim:latest grype'
alias trivy='docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/sbom-tools-slim:latest trivy'
```

Now you can run:
```bash
prettier --write "**/*.md"
yamlfmt -lint .
syft dir:/work -o json
```

No local installation required.

### Using Local Config Files

Your project's config files (`.prettierrc.json`, `.yamlfmt.yaml`, `biome.json`, etc.) are automatically used because the volume mount makes them visible inside the container.

```bash
# This uses YOUR .prettierrc.json, not a default
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim:latest \
  prettier --check .
```

---

## Pattern 2: Working Environment (Interactive)

For interactive shells and multi-step workflows, prefer `-runner` variants (they include a more complete baseline userland).

**Problem:** You want to run multiple commands, explore tools, or debug inside the container.

**Solution:** Start an interactive shell session.

### Basic Structure

```bash
docker run --rm -it -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-runner:latest sh
```

| Flag | Purpose |
|------|---------|
| `-it` | Interactive terminal (keeps stdin open + allocates TTY) |
| `sh` | Start a shell instead of running a single command |

### Example Session

```bash
$ docker run --rm -it -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-runner:latest sh

/work $ prettier --version
3.4.2

/work $ yamlfmt --version
0.20.0

/work $ prettier --write "**/*.md"
README.md 42ms

/work $ yamlfmt -lint .
All files formatted correctly

/work $ exit
```

### When to Use Interactive Mode

- Exploring what tools are available (`--help`, `--version`)
- Running multiple related commands
- Debugging formatting/linting issues
- Learning tool options before scripting

---

## Comparison

| Aspect | Tool Replacement | Working Environment |
|--------|------------------|---------------------|
| **Invocation** | One command per `docker run` | Single `docker run`, many commands |
| **Overhead** | Container starts/stops each time | Container stays running |
| **Best for** | CI/CD, scripts, quick checks | Exploration, debugging |
| **Shell aliases** | Works great | Not applicable |

---

## Troubleshooting

### Permission Denied Errors

If you see `EACCES` or permission errors:

```bash
# Run as your user ID
docker run --rm -u "$(id -u):$(id -g)" -v "$(pwd):/work" -w /work \
  ghcr.io/fulmenhq/goneat-tools-slim:latest prettier --write .
```

### Files Not Found

Ensure you're in the correct directory and the volume mount is correct:

```bash
# Verify mount
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-runner:latest \
  ls -la
```

### Config Not Being Used

Config files must be in the mounted directory tree. If your config is in `~/.config/`, it won't be visible unless you mount it:

```bash
# Mount additional config directory
docker run --rm \
  -v "$(pwd):/work" \
  -v "$HOME/.config/yamlfmt:/home/nonroot/.config/yamlfmt:ro" \
  -w /work \
  ghcr.io/fulmenhq/goneat-tools-slim:latest yamlfmt -lint .
```

---

## GitHub Actions Usage

In CI, the container runs your job steps directly:

```yaml
jobs:
  quality:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/fulmenhq/goneat-tools-runner:latest
      options: --user 1001  # Match GHA runner UID
    steps:
      - uses: actions/checkout@v4
      - run: prettier --check "**/*.{md,json,yml,yaml}"
      - run: yamlfmt -lint .
      - run: actionlint
```

This is essentially "Pattern 2" (working environment) managed by GitHub Actions.

---

## Quick Reference

```bash
# Format markdown (tool replacement)
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim:latest \
  prettier --write "**/*.md"

# Interactive session
docker run --rm -it -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-runner:latest sh

# Generate SBOM
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/sbom-tools-slim:latest \
  syft dir:/work -o spdx-json > sbom.json

# Scan for vulnerabilities
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/sbom-tools-slim:latest \
  grype dir:/work
```
