# sbom-tools Docker Image
# SBOM generation and vulnerability scanning: syft, grype
# Base: alpine:3.21 (minimal)
# Multi-arch: linux/amd64 + linux/arm64
# Size target: ~80-120MB

ARG ALPINE_IMAGE=alpine:3.21@sha256:5405e8f36ce1878720f71217d664aa3dea32e5e5df11acbf07fc78ef5661465b
ARG SYFT_VERSION=v1.18.1
ARG GRYPE_VERSION=v0.86.1

FROM ${ALPINE_IMAGE}
ARG SYFT_VERSION
ARG GRYPE_VERSION

# Install minimal runtime deps (ca-certificates for HTTPS, bash for scripting)
RUN apk add --no-cache ca-certificates bash

# Install syft (detect arch via uname for legacy builder compatibility)
RUN set -eux; \
    UNAME_ARCH="$(uname -m)"; \
    case "${UNAME_ARCH}" in \
        x86_64) ARCH="amd64" ;; \
        aarch64) ARCH="arm64" ;; \
        *) echo "Unsupported arch: ${UNAME_ARCH}" && exit 1 ;; \
    esac; \
    wget -q "https://github.com/anchore/syft/releases/download/${SYFT_VERSION}/syft_${SYFT_VERSION#v}_linux_${ARCH}.tar.gz" -O /tmp/syft.tar.gz; \
    tar -xzf /tmp/syft.tar.gz -C /usr/local/bin syft; \
    rm /tmp/syft.tar.gz; \
    chmod +x /usr/local/bin/syft; \
    syft version

# Install grype (detect arch via uname for legacy builder compatibility)
RUN set -eux; \
    UNAME_ARCH="$(uname -m)"; \
    case "${UNAME_ARCH}" in \
        x86_64) ARCH="amd64" ;; \
        aarch64) ARCH="arm64" ;; \
        *) echo "Unsupported arch: ${UNAME_ARCH}" && exit 1 ;; \
    esac; \
    wget -q "https://github.com/anchore/grype/releases/download/${GRYPE_VERSION}/grype_${GRYPE_VERSION#v}_linux_${ARCH}.tar.gz" -O /tmp/grype.tar.gz; \
    tar -xzf /tmp/grype.tar.gz -C /usr/local/bin grype; \
    rm /tmp/grype.tar.gz; \
    chmod +x /usr/local/bin/grype; \
    grype version

# Set working directory
WORKDIR /work

# Default entrypoint: shell for flexible usage
ENTRYPOINT ["/bin/sh"]
