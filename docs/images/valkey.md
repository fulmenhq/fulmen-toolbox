# valkey Images

Purpose: Valkey (Redis-compatible) key-value store for production deployments, sidecars, and local development.

This doc covers the configuration surface and contracts. For definitive version pins, see `manifests/apps.json` at the release tag.

## Variants

| Canonical Tag | Base | Use Case |
|---------------|------|----------|
| `ghcr.io/fulmenhq/valkey-server-glibc` | Debian bookworm | Production server, sidecar |

No shorthand canonicals are published for new application families. Use the fully-qualified tag.

See `docs/images/tag-taxonomy.md` for naming conventions.

## Quick Start

### Basic (ephemeral, no auth)

```bash
docker run --rm -p 6379:6379 ghcr.io/fulmenhq/valkey-server-glibc:latest
```

### With password authentication

```bash
docker run --rm -p 6379:6379 \
  ghcr.io/fulmenhq/valkey-server-glibc:latest \
  valkey-server --requirepass mysecret
```

### With persistence

```bash
docker run --rm -p 6379:6379 \
  -v valkey-data:/data \
  ghcr.io/fulmenhq/valkey-server-glibc:latest \
  valkey-server --appendonly yes
```

## Configuration Surface

This image inherits the upstream Valkey entrypoint without modification. Configuration is via **command-line arguments** or a **mounted config file** — there is no env-var-to-config translation layer.

### CLI Arguments (Primary Method)

**Authentication:**
```bash
valkey-server --requirepass "${VALKEY_PASSWORD}"
```

**Persistence (AOF):**
```bash
valkey-server --appendonly yes --dir /data
```

**Persistence (RDB):**
```bash
valkey-server --save 60 1 --dir /data
```

**TLS:**
```bash
valkey-server \
  --tls-port 6379 --port 0 \
  --tls-cert-file /certs/tls.crt \
  --tls-key-file /certs/tls.key \
  --tls-ca-cert-file /certs/ca.crt
```

### Configuration File

For complex configurations, mount a config file:

```bash
docker run --rm -p 6379:6379 \
  -v ./valkey.conf:/etc/valkey/valkey.conf:ro \
  ghcr.io/fulmenhq/valkey-server-glibc:latest \
  valkey-server /etc/valkey/valkey.conf
```

## Service Contract

### Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 6379 | TCP | Valkey protocol (default) |

### Volumes

| Path | Mode | Required | Description |
|------|------|----------|-------------|
| `/data` | rw | No | Persistence directory (AOF/RDB files) |
| `/certs` | ro | No | TLS certificates (when TLS enabled) |

### Healthcheck

The image includes a built-in healthcheck using `valkey-cli ping`:

- Interval: 30s
- Timeout: 5s
- Start period: 5s
- Retries: 3

Override with `--no-healthcheck` or a custom `HEALTHCHECK` in your Dockerfile.

### Runtime User

Runs as `valkey` (UID 999, GID 999) by default. The upstream image creates this user.

## Compose Example

```yaml
services:
  valkey:
    image: ghcr.io/fulmenhq/valkey-server-glibc:latest
    ports:
      - "6379:6379"
    volumes:
      - valkey-data:/data
    command: valkey-server --appendonly yes
    healthcheck:
      test: ["CMD", "valkey-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  valkey-data:
```

## Licensing

- **Valkey**: BSD-3-Clause
- License text: `/licenses/github/valkey-io/valkey/LICENSE`

The image includes a `/licenses` directory for compliance transparency.

## Upstream

This image is a vendor-image repack of the official Valkey image:

- Upstream: `valkey/valkey:8.1-bookworm`
- Valkey project: https://valkey.io/
- GitHub: https://github.com/valkey-io/valkey

## See Also

- [Container Usage Patterns](../user-guide/container-usage-patterns.md)
- [Image Tag Taxonomy](tag-taxonomy.md)
