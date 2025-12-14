# sbom-tools Docker Image
# SBOM generation and vulnerability scanning: syft, grype, trivy
# Base: alpine:3.21 (minimal)
# Multi-arch: linux/amd64 + linux/arm64
# Size target: ~150-200MB (trivy adds ~50MB)
#
# Provides two SBOM/vuln workflows:
# - Anchore: syft (SBOM) + grype (vuln scan)
# - Aqua: trivy (SBOM + vuln scan + config scanning)

ARG ALPINE_IMAGE=alpine:3.21@sha256:5405e8f36ce1878720f71217d664aa3dea32e5e5df11acbf07fc78ef5661465b
ARG SYFT_VERSION=v1.18.1
ARG GRYPE_VERSION=v0.86.1
ARG TRIVY_VERSION=v0.68.1

FROM ${ALPINE_IMAGE}
ARG SYFT_VERSION
ARG GRYPE_VERSION
ARG TRIVY_VERSION

# Install runtime deps (ca-certificates for HTTPS, bash for scripting, CLI tools for CI workflows)
RUN apk add --no-cache ca-certificates bash curl=8.14.1-r2 jq=1.7.1-r0 yq-go=4.44.5-r5 git=2.47.3-r0

# Standard location for license texts and notices (transparency / compliance support)
RUN set -eux; \
    mkdir -p \
      /licenses/github /licenses/alpine \
      /notices/github /notices/alpine; \
    if [ -d /usr/share/licenses ]; then \
      cp -a /usr/share/licenses/. /licenses/alpine/; \
    fi; \
    # Curated upstream license texts for GitHub release binaries
    mkdir -p \
      /licenses/github/anchore/syft \
      /licenses/github/anchore/grype \
      /licenses/github/aquasecurity/trivy \
      /notices/github/anchore/syft \
      /notices/github/anchore/grype \
      /notices/github/aquasecurity/trivy; \
    curl -fsSL "https://raw.githubusercontent.com/anchore/syft/${SYFT_VERSION}/LICENSE" \
      -o /licenses/github/anchore/syft/LICENSE; \
    curl -fsSL "https://raw.githubusercontent.com/anchore/grype/${GRYPE_VERSION}/LICENSE" \
      -o /licenses/github/anchore/grype/LICENSE; \
    curl -fsSL "https://raw.githubusercontent.com/aquasecurity/trivy/${TRIVY_VERSION}/LICENSE" \
      -o /licenses/github/aquasecurity/trivy/LICENSE; \
    # NOTICE files are best-effort (some projects do not publish them)
    curl -fsSL "https://raw.githubusercontent.com/anchore/syft/${SYFT_VERSION}/NOTICE" \
      -o /notices/github/anchore/syft/NOTICE || true; \
    curl -fsSL "https://raw.githubusercontent.com/anchore/grype/${GRYPE_VERSION}/NOTICE" \
      -o /notices/github/anchore/grype/NOTICE || true; \
    curl -fsSL "https://raw.githubusercontent.com/aquasecurity/trivy/${TRIVY_VERSION}/NOTICE" \
      -o /notices/github/aquasecurity/trivy/NOTICE || true; \
    chmod -R a+rX /licenses /notices

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

# Install trivy (detect arch via uname for legacy builder compatibility)
# Trivy provides: SBOM generation, vuln scanning, AND config/Dockerfile scanning
RUN set -eux; \
    UNAME_ARCH="$(uname -m)"; \
    case "${UNAME_ARCH}" in \
        x86_64) ARCH="64bit" ;; \
        aarch64) ARCH="ARM64" ;; \
        *) echo "Unsupported arch: ${UNAME_ARCH}" && exit 1 ;; \
    esac; \
    wget -q "https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/trivy_${TRIVY_VERSION#v}_Linux-${ARCH}.tar.gz" -O /tmp/trivy.tar.gz; \
    tar -xzf /tmp/trivy.tar.gz -C /usr/local/bin trivy; \
    rm /tmp/trivy.tar.gz; \
    chmod +x /usr/local/bin/trivy; \
    trivy version

# Create non-root user for security
RUN adduser -D -u 1000 tooluser && mkdir -p /work && chown tooluser:tooluser /work

# Set working directory
WORKDIR /work

# Run as non-root user (security best practice)
USER tooluser

# Default entrypoint: shell for flexible usage
ENTRYPOINT ["/bin/sh"]
