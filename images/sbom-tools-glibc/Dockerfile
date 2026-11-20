# sbom-tools glibc runner Docker Image
# SBOM generation and vulnerability scanning: syft, grype, trivy
# Base: debian:bookworm-slim (glibc)
# Multi-arch: linux/amd64 + linux/arm64
#
# Build targets:
# - slim: tool payload only (not published)
# - runner (default): slim + runner baseline + build tools

ARG DEBIAN_IMAGE=debian:bookworm-slim@sha256:7ff6ba31527b9e336162fa061746c366c4b2032f4d2cff2078bea43f78efe3f8
# shellsentry is built from this image. Keep it on the same Go patch as the
# goneat-tools builder (currently 1.26.11).
ARG GO_IMAGE=golang:1.26.11-bookworm@sha256:dc40a13b61304647ed7e5d581d246b86413dfc29d63c6d018310feb93cd98fc0
ARG SYFT_VERSION=v1.57.1
ARG GRYPE_VERSION=v0.121.3
ARG SYFT_SHA256_AMD64=bf52519eb57f675d47c07d43213cb6dff6449f3d6d1147ff6701ed91f44eef0c
ARG SYFT_SHA256_ARM64=aa3d3e07344f590bcce8d31043b752daa76c8a56c2aa34ceeee63c6168152582
ARG GRYPE_SHA256_AMD64=e9da18cc1429e786722e32161288103600efffd8e483c90761f90485bd1bec85
ARG GRYPE_SHA256_ARM64=b7815598d48da78bfd16f5b98ef28e1bb09c03d34fc8c3e350f99b6ccb3c7cba
ARG TRIVY_VERSION=v0.76.2
ARG TRIVY_SHA256_AMD64=bc0fc726e017b8927a62b2d3531d7a84ee01769daf5c99ed866dced54089fdbf
ARG TRIVY_SHA256_ARM64=ab9d51f86e6a5fb936f605faff6b593ac51bc378fff4d3e8b9d58358b9c367c3
ARG SHELLSENTRY_VERSION=v0.1.7
# Upstream GitHub release binary (jqlang/jq), checksum-verified per arch below.
ARG JQ_VERSION=1.8.2
ARG JQ_SHA256_AMD64=b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f
ARG JQ_SHA256_ARM64=8b85c817833814ddca00a144c33705546355afccf0cf39b188f3cdb48b852309
# Upstream GitHub release binary (mikefarah/yq), checksum-verified per arch below.
ARG YQ_VERSION=v4.54.3
ARG YQ_SHA256_AMD64=129534601871538efe0ba4c5e62a34fb1d5f469bcb975c4fddeb467d82974973
ARG YQ_SHA256_ARM64=89f69310b61b68d1245065a1241d1fc843f7a36cd6103ffd77ad987613bd1b67

# Stage 1: Fetch binaries and stage licenses/notices (kept out of runtime layers)
FROM ${DEBIAN_IMAGE} AS fetcher
ARG SYFT_VERSION
ARG GRYPE_VERSION
ARG SYFT_SHA256_AMD64
ARG SYFT_SHA256_ARM64
ARG GRYPE_SHA256_AMD64
ARG GRYPE_SHA256_ARM64
ARG TRIVY_VERSION
ARG TRIVY_SHA256_AMD64
ARG TRIVY_SHA256_ARM64
ARG JQ_VERSION
ARG JQ_SHA256_AMD64
ARG JQ_SHA256_ARM64
ARG YQ_VERSION
ARG YQ_SHA256_AMD64
ARG YQ_SHA256_ARM64
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
        x86_64) ARCH="amd64"; TRIVY_ARCH="64bit"; TRIVY_SHA256="${TRIVY_SHA256_AMD64}" ;; \
        aarch64) ARCH="arm64"; TRIVY_ARCH="ARM64"; TRIVY_SHA256="${TRIVY_SHA256_ARM64}" ;; \
        *) echo "Unsupported arch: ${UNAME_ARCH}" && exit 1 ;; \
    esac; \
    case "${ARCH}" in \
      amd64) SYFT_SHA256="${SYFT_SHA256_AMD64}"; GRYPE_SHA256="${GRYPE_SHA256_AMD64}"; JQ_SHA256="${JQ_SHA256_AMD64}"; YQ_SHA256="${YQ_SHA256_AMD64}" ;; \
      arm64) SYFT_SHA256="${SYFT_SHA256_ARM64}"; GRYPE_SHA256="${GRYPE_SHA256_ARM64}"; JQ_SHA256="${JQ_SHA256_ARM64}"; YQ_SHA256="${YQ_SHA256_ARM64}" ;; \
    esac; \
    curl -fsSL "https://github.com/anchore/syft/releases/download/${SYFT_VERSION}/syft_${SYFT_VERSION#v}_linux_${ARCH}.tar.gz" -o /tmp/syft.tar.gz; \
    echo "${SYFT_SHA256}  /tmp/syft.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/syft.tar.gz -C /out/bin syft; \
    rm /tmp/syft.tar.gz; \
    curl -fsSL "https://github.com/anchore/grype/releases/download/${GRYPE_VERSION}/grype_${GRYPE_VERSION#v}_linux_${ARCH}.tar.gz" -o /tmp/grype.tar.gz; \
    echo "${GRYPE_SHA256}  /tmp/grype.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/grype.tar.gz -C /out/bin grype; \
    rm /tmp/grype.tar.gz; \
    curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/trivy_${TRIVY_VERSION#v}_Linux-${TRIVY_ARCH}.tar.gz" -o /tmp/trivy.tar.gz; \
    echo "${TRIVY_SHA256}  /tmp/trivy.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/trivy.tar.gz -C /out/bin trivy; \
    rm /tmp/trivy.tar.gz; \
    curl -fsSL "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${ARCH}" -o /out/bin/jq; \
    echo "${JQ_SHA256}  /out/bin/jq" | sha256sum -c -; \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" -o /out/bin/yq; \
    echo "${YQ_SHA256}  /out/bin/yq" | sha256sum -c -; \
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

# Install runner baseline packages + build tools for CGO.
# libgnutls30 is security-pinned to the patched bookworm-security build (the
# base image lags the security repo). See manifests/tools.json; availability is
# enforced by validate-apt-pins.sh and presence by validate-pins.sh.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgnutls30=3.7.9-2+deb12u7 \
    apt=2.6.2 \
    libapt-pkg6.0=2.6.2 \
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
