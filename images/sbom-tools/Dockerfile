# sbom-tools Docker Image
# SBOM generation and vulnerability scanning: syft, grype, trivy
# Base: alpine:3.21 (minimal)
# Multi-arch: linux/amd64 + linux/arm64
#
# Build targets:
# - slim: tool payload only (no runner baseline)
# - runner (default): slim + runner baseline packages

ARG ALPINE_IMAGE=alpine:3.21@sha256:5405e8f36ce1878720f71217d664aa3dea32e5e5df11acbf07fc78ef5661465b
ARG SYFT_VERSION=v1.18.1
ARG GRYPE_VERSION=v0.86.1
ARG TRIVY_VERSION=v0.68.1

# Runner-baseline pinned packages (subset)
ARG GIT_VERSION=2.47.3-r0
ARG CURL_VERSION=8.14.1-r2
ARG JQ_VERSION=1.7.1-r0
ARG YQ_VERSION=4.44.5-r5

# Stage 1: Fetch binaries and stage licenses/notices (kept out of runtime layers)
FROM ${ALPINE_IMAGE} AS fetcher
ARG SYFT_VERSION
ARG GRYPE_VERSION
ARG TRIVY_VERSION
RUN apk add --no-cache ca-certificates curl tar gzip wget
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

# Install syft/grype/trivy (arch-aware)
RUN set -eux; \
    UNAME_ARCH="$(uname -m)"; \
    case "${UNAME_ARCH}" in \
        x86_64) ARCH="amd64" ;; \
        aarch64) ARCH="arm64" ;; \
        *) echo "Unsupported arch: ${UNAME_ARCH}" && exit 1 ;; \
    esac; \
    wget -q "https://github.com/anchore/syft/releases/download/${SYFT_VERSION}/syft_${SYFT_VERSION#v}_linux_${ARCH}.tar.gz" -O /tmp/syft.tar.gz; \
    tar -xzf /tmp/syft.tar.gz -C /out/bin syft; \
    rm /tmp/syft.tar.gz; \
    wget -q "https://github.com/anchore/grype/releases/download/${GRYPE_VERSION}/grype_${GRYPE_VERSION#v}_linux_${ARCH}.tar.gz" -O /tmp/grype.tar.gz; \
    tar -xzf /tmp/grype.tar.gz -C /out/bin grype; \
    rm /tmp/grype.tar.gz; \
    case "${UNAME_ARCH}" in \
        x86_64) TRIVY_ARCH="64bit" ;; \
        aarch64) TRIVY_ARCH="ARM64" ;; \
    esac; \
    wget -q "https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/trivy_${TRIVY_VERSION#v}_Linux-${TRIVY_ARCH}.tar.gz" -O /tmp/trivy.tar.gz; \
    tar -xzf /tmp/trivy.tar.gz -C /out/bin trivy; \
    rm /tmp/trivy.tar.gz; \
    chmod +x /out/bin/syft /out/bin/grype /out/bin/trivy

# Stage 2: slim variant (tools only)
FROM ${ALPINE_IMAGE} AS slim
ARG JQ_VERSION
ARG YQ_VERSION

# Minimal runtime deps (TLS + JSON/YAML shaping)
RUN apk add --no-cache \
    ca-certificates \
    jq=${JQ_VERSION} \
    yq-go=${YQ_VERSION}

# Standard location for license texts and notices (transparency / compliance support)
RUN set -eux; \
    mkdir -p \
      /licenses/github /licenses/alpine \
      /notices/github /notices/alpine; \
    if [ -d /usr/share/licenses ]; then \
      cp -a /usr/share/licenses/. /licenses/alpine/; \
    fi; \
    chmod -R a+rX /licenses /notices

# Copy tools
COPY --from=fetcher /out/bin/syft /usr/local/bin/syft
COPY --from=fetcher /out/bin/grype /usr/local/bin/grype
COPY --from=fetcher /out/bin/trivy /usr/local/bin/trivy

# Copy staged licenses/notices
COPY --from=fetcher /out/licenses/github/ /licenses/github/
COPY --from=fetcher /out/notices/github/ /notices/github/

# Create non-root user for security
RUN adduser -D -u 1000 tooluser && mkdir -p /work && chown tooluser:tooluser /work
WORKDIR /work
USER tooluser
ENTRYPOINT ["/bin/sh"]

# Stage 3: runner variant (default)
FROM slim AS runner
ARG GIT_VERSION
ARG CURL_VERSION

USER root

# Install runner baseline packages (pin git/curl to match manifests/tools.json)
RUN apk add --no-cache \
    bash \
    git=${GIT_VERSION} \
    curl=${CURL_VERSION} \
    coreutils \
    findutils \
    diffutils \
    make \
    tar \
    gzip \
    xz \
    unzip \
    openssh-client

USER tooluser
