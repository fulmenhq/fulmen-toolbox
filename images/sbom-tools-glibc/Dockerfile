# sbom-tools glibc runner Docker Image
# SBOM generation and vulnerability scanning: syft, grype, trivy
# Base: debian:bookworm-slim (glibc)
# Multi-arch: linux/amd64 + linux/arm64
#
# Build targets:
# - slim: tool payload only (not published)
# - runner (default): slim + runner baseline + build tools

ARG DEBIAN_IMAGE=debian:bookworm-slim@sha256:d5d3f9c23164ea16f31852f95bd5959aad1c5e854332fe00f7b3a20fcc9f635c
ARG GO_IMAGE=golang:1.25-bookworm@sha256:2c7c65601b020ee79db4c1a32ebee0bf3d6b298969ec683e24fcbea29305f10e
ARG SYFT_VERSION=v1.41.1
ARG GRYPE_VERSION=v0.107.1
ARG TRIVY_VERSION=v0.69.0
ARG SHELLSENTRY_VERSION=v0.1.4
ARG JQ_VERSION=1.8.1
ARG YQ_VERSION=v4.49.2

# Stage 1: Fetch binaries and stage licenses/notices (kept out of runtime layers)
FROM ${DEBIAN_IMAGE} AS fetcher
ARG SYFT_VERSION
ARG GRYPE_VERSION
ARG TRIVY_VERSION
ARG JQ_VERSION
ARG YQ_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl tar gzip xz-utils && \
    rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    mkdir -p \
      /out/bin \
      /out/licenses/github/anchore/syft \
      /out/licenses/github/anchore/grype \
      /out/licenses/github/aquasecurity/trivy \
      /out/notices/github/anchore/syft \
      /out/notices/github/anchore/grype \
      /out/notices/github/aquasecurity/trivy; \
    curl -fsSL "https://raw.githubusercontent.com/anchore/syft/${SYFT_VERSION}/LICENSE" \
      -o /out/licenses/github/anchore/syft/LICENSE; \
    curl -fsSL "https://raw.githubusercontent.com/anchore/grype/${GRYPE_VERSION}/LICENSE" \
      -o /out/licenses/github/anchore/grype/LICENSE; \
    curl -fsSL "https://raw.githubusercontent.com/aquasecurity/trivy/${TRIVY_VERSION}/LICENSE" \
      -o /out/licenses/github/aquasecurity/trivy/LICENSE; \
    curl -fsSL "https://raw.githubusercontent.com/anchore/syft/${SYFT_VERSION}/NOTICE" \
      -o /out/notices/github/anchore/syft/NOTICE || true; \
    curl -fsSL "https://raw.githubusercontent.com/anchore/grype/${GRYPE_VERSION}/NOTICE" \
      -o /out/notices/github/anchore/grype/NOTICE || true; \
    curl -fsSL "https://raw.githubusercontent.com/aquasecurity/trivy/${TRIVY_VERSION}/NOTICE" \
      -o /out/notices/github/aquasecurity/trivy/NOTICE; \
    chmod -R a+rX /out/licenses /out/notices

# Install syft/grype/trivy + jq/yq (arch-aware)
RUN set -eux; \
    UNAME_ARCH="$(uname -m)"; \
    case "${UNAME_ARCH}" in \
        x86_64) ARCH="amd64"; TRIVY_ARCH="64bit" ;; \
        aarch64) ARCH="arm64"; TRIVY_ARCH="ARM64" ;; \
        *) echo "Unsupported arch: ${UNAME_ARCH}" && exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/anchore/syft/releases/download/${SYFT_VERSION}/syft_${SYFT_VERSION#v}_linux_${ARCH}.tar.gz" -o /tmp/syft.tar.gz; \
    tar -xzf /tmp/syft.tar.gz -C /out/bin syft; \
    rm /tmp/syft.tar.gz; \
    curl -fsSL "https://github.com/anchore/grype/releases/download/${GRYPE_VERSION}/grype_${GRYPE_VERSION#v}_linux_${ARCH}.tar.gz" -o /tmp/grype.tar.gz; \
    tar -xzf /tmp/grype.tar.gz -C /out/bin grype; \
    rm /tmp/grype.tar.gz; \
    curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/trivy_${TRIVY_VERSION#v}_Linux-${TRIVY_ARCH}.tar.gz" -o /tmp/trivy.tar.gz; \
    tar -xzf /tmp/trivy.tar.gz -C /out/bin trivy; \
    rm /tmp/trivy.tar.gz; \
    curl -fsSL "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${ARCH}" -o /out/bin/jq; \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" -o /out/bin/yq; \
    chmod +x /out/bin/syft /out/bin/grype /out/bin/trivy /out/bin/jq /out/bin/yq

# Stage 1b: Build shellsentry (runner-only)
FROM ${GO_IMAGE} AS shellsentry-builder
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && \
    rm -rf /var/lib/apt/lists/*
ARG SHELLSENTRY_VERSION
RUN go install github.com/3leaps/shellsentry@${SHELLSENTRY_VERSION}
RUN set -eux; \
    mkdir -p \
      /out/bin \
      /out/licenses/github/3leaps/shellsentry \
      /out/notices/github/3leaps/shellsentry; \
    cp /go/bin/shellsentry /out/bin/shellsentry; \
    GOMODCACHE="$(go env GOMODCACHE)"; \
    cp "${GOMODCACHE}/github.com/3leaps/shellsentry@${SHELLSENTRY_VERSION}/LICENSE" \
      /out/licenses/github/3leaps/shellsentry/LICENSE; \
    cp "${GOMODCACHE}/github.com/3leaps/shellsentry@${SHELLSENTRY_VERSION}/NOTICE" \
      /out/notices/github/3leaps/shellsentry/NOTICE; \
    chmod -R a+rX /out

# Stage 2: slim variant (tools only)
FROM ${DEBIAN_IMAGE} AS slim

# Minimal runtime deps (TLS + JSON/YAML shaping)
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Standard location for license texts and notices (transparency / compliance support)
RUN set -eux; \
    mkdir -p \
      /licenses/github /licenses/debian \
      /notices/github /notices/debian; \
    chmod -R a+rX /licenses /notices

# Copy tools
COPY --from=fetcher /out/bin/syft /usr/local/bin/syft
COPY --from=fetcher /out/bin/grype /usr/local/bin/grype
COPY --from=fetcher /out/bin/trivy /usr/local/bin/trivy
COPY --from=fetcher /out/bin/jq /usr/local/bin/jq
COPY --from=fetcher /out/bin/yq /usr/local/bin/yq

# Copy staged licenses/notices
COPY --from=fetcher /out/licenses/github/ /licenses/github/
COPY --from=fetcher /out/notices/github/ /notices/github/

# Create non-root user for security
RUN adduser --disabled-password --gecos "" --uid 1000 tooluser && mkdir -p /work && chown tooluser:tooluser /work
WORKDIR /work
USER tooluser
ENTRYPOINT ["/bin/sh"]

# Stage 3: runner variant (default)
FROM slim AS runner

USER root

# Install runner baseline packages + build tools for CGO
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    git \
    curl \
    ca-certificates \
    coreutils \
    findutils \
    diffutils \
    make \
    tar \
    gzip \
    xz-utils \
    unzip \
    openssh-client \
    build-essential \
    gcc \
    g++ \
    libc6-dev \
    pkg-config \
    python3 \
    yamllint && \
    rm -rf /var/lib/apt/lists/*

COPY --from=shellsentry-builder /out/bin/shellsentry /usr/local/bin/shellsentry
COPY --from=shellsentry-builder /out/licenses/github/3leaps/shellsentry/LICENSE /licenses/github/3leaps/shellsentry/LICENSE
COPY --from=shellsentry-builder /out/notices/github/3leaps/shellsentry/NOTICE /notices/github/3leaps/shellsentry/NOTICE

USER tooluser
