# User Guide

Practical guides for using Fulmen Toolbox images.

## Quick Start

**Choose your image variant:**

| Variant | Use | Example |
|---------|-----|---------|
| `-runner` | CI jobs, needs bash/make/git | `ghcr.io/fulmenhq/goneat-tools-runner:latest` |
| `-slim` | Local tool replacement | `ghcr.io/fulmenhq/goneat-tools-slim:latest` |

**Run a tool without installing it:**
```bash
docker run --rm -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-slim:latest \
  prettier --write "**/*.md"
```

**Start an interactive session:**
```bash
docker run --rm -it -v "$(pwd):/work" -w /work ghcr.io/fulmenhq/goneat-tools-runner:latest sh
```

## Contents

| Guide | Description |
|-------|-------------|
| [Container Usage Patterns](container-usage-patterns.md) | Choosing variants, tool replacement vs working environment, shell aliases |

## See Also

- [Runner Baseline Packages](../sop/runner-baseline.md) - What's included in `-runner` images
- [ADR-0004](../adr/ADR-0004-copyleft-and-runner-images.md) - Copyleft licensing decisions
