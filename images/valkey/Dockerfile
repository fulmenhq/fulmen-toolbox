# valkey-server-glibc Docker Image
# Valkey (Redis-compatible) key-value store - vendor-image repack
# Base: valkey/valkey:8.1-bookworm (glibc/Debian)
# Multi-arch: linux/amd64 + linux/arm64
#
# This is a minimal repack of the upstream Valkey image with:
# - License/notice transparency (/licenses directory)
# - Non-root runtime by default
#
# Configuration is via CLI args or config file mount (no env-var translation).
# See docs/images/valkey.md for usage patterns.

# Pinned upstream image (vendor-image repack strategy)
ARG VALKEY_IMAGE=valkey/valkey:8.1-bookworm@sha256:fea8b3e67b15729d4bb70589eb03367bab9ad1ee89c876f54327fc7c6e618571
# License branch tracks the upstream release branch (not patch version)
ARG VALKEY_LICENSE_BRANCH=8.1

# Stage 1: Fetch license from upstream repo
# Pin base image for reproducibility
ARG DEBIAN_IMAGE=debian:bookworm-slim@sha256:d5d3f9c23164ea16f31852f95bd5959aad1c5e854332fe00f7b3a20fcc9f635c
FROM ${DEBIAN_IMAGE} AS license-fetcher
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*
ARG VALKEY_LICENSE_BRANCH
RUN set -eux; \
    mkdir -p /licenses/github/valkey-io/valkey; \
    curl -fsSL "https://raw.githubusercontent.com/valkey-io/valkey/${VALKEY_LICENSE_BRANCH}/COPYING" \
      -o /licenses/github/valkey-io/valkey/LICENSE; \
    chmod -R a+rX /licenses

# Stage 2: Final image (repack upstream with overlays)
FROM ${VALKEY_IMAGE} AS server

# Copy license from fetcher
COPY --from=license-fetcher /licenses /licenses

# Create notices directory (empty for now; Valkey has no NOTICE file)
RUN mkdir -p /notices && chmod -R a+rX /notices

# Ensure /data is writable by valkey user (upstream already creates this)
# and /licenses is readable
RUN chown -R valkey:valkey /data && \
    chmod -R a+rX /licenses /notices

# Switch to non-root user (valkey user exists in upstream image as 999:999)
USER valkey

# Expose default port
EXPOSE 6379

# Health check using valkey-cli (more reliable than TCP probe)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["valkey-cli", "ping"]

# Use upstream entrypoint and default command
# The upstream docker-entrypoint.sh handles config generation
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["valkey-server"]
