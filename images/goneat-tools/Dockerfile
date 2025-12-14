# goneat-tools Docker Image
# Code quality and formatting tools: Prettier, Biome, yamlfmt, shfmt, checkmake, actionlint, jq, yq, ripgrep, taplo
# Base: node:22-alpine for Prettier + Alpine pkgs for others
# Multi-arch: linux/amd64 + linux/arm64
# Size target: ~150-250MB

# Version pins
ARG GO_IMAGE=golang:1.24-alpine@sha256:06545cc1ff10ddf04aebe20db1352ec7c96d1e43135767931c473557d0378202
ARG NODE_IMAGE=node:22-alpine@sha256:9632533eda8061fc1e9960cfb3f8762781c07a00ee7317f5dc0e13c05e15166f
ARG YAMLFMT_VERSION=v0.20.0
ARG SHFMT_VERSION=v3.12.0
ARG CHECKMAKE_VERSION=0.2.2
ARG ACTIONLINT_VERSION=v1.7.9
ARG PRETTIER_VERSION=3.7.4
ARG BIOME_VERSION=2.3.8
ARG JQ_VERSION=1.8.1-r0
ARG YQ_VERSION=4.49.2-r1
ARG RIPGREP_VERSION=15.1.0-r0
ARG TAPLO_VERSION=0.10.0-r0
ARG BASH_VERSION=5.3.3-r1
ARG GIT_VERSION=2.52.0-r0
ARG CURL_VERSION=8.17.0-r1
ARG MINISIGN_VERSION=0.12-r0

# Stage 1: Build Go tools (yamlfmt, shfmt, checkmake, actionlint)
FROM ${GO_IMAGE} AS go-builder
ARG YAMLFMT_VERSION
ARG SHFMT_VERSION
ARG CHECKMAKE_VERSION
ARG ACTIONLINT_VERSION
RUN go install github.com/google/yamlfmt/cmd/yamlfmt@${YAMLFMT_VERSION} && \
    go install mvdan.cc/sh/v3/cmd/shfmt@${SHFMT_VERSION} && \
    go install github.com/mrtazz/checkmake/cmd/checkmake@${CHECKMAKE_VERSION} && \
    go install github.com/rhysd/actionlint/cmd/actionlint@${ACTIONLINT_VERSION}

# License/notice staging for Go-installed tools
# (Copied into final image under /licenses/github/*)
RUN set -eux; \
    mkdir -p /licenses/github/google/yamlfmt /licenses/github/mvdan/sh /licenses/github/mrtazz/checkmake /licenses/github/rhysd/actionlint; \
    mkdir -p /notices/github/google/yamlfmt /notices/github/mvdan/sh /notices/github/mrtazz/checkmake /notices/github/rhysd/actionlint; \
    GOMODCACHE="$(go env GOMODCACHE)"; \
    copy_license() { pattern="$1" dest="$2"; \
      set -- $pattern; \
      [ -f "$1" ] || { echo "missing LICENSE: $pattern" >&2; exit 1; }; \
      cp "$1" "$dest"; \
    }; \
    copy_notice() { moddir_pattern="$1" destdir="$2"; \
      set -- $moddir_pattern; \
      moddir="$1"; \
      for f in NOTICE NOTICE.txt NOTICE.md; do \
        if [ -f "$moddir/$f" ]; then cp "$moddir/$f" "$destdir/NOTICE"; fi; \
      done; \
    }; \
    copy_license "${GOMODCACHE}/github.com/google/yamlfmt@${YAMLFMT_VERSION}/LICENSE" /licenses/github/google/yamlfmt/LICENSE; \
    copy_license "${GOMODCACHE}/mvdan.cc/sh/v3@${SHFMT_VERSION}/LICENSE" /licenses/github/mvdan/sh/LICENSE; \
    copy_license "${GOMODCACHE}/github.com/mrtazz/checkmake@*/LICENSE" /licenses/github/mrtazz/checkmake/LICENSE; \
    copy_license "${GOMODCACHE}/github.com/rhysd/actionlint@${ACTIONLINT_VERSION}/LICENSE*" /licenses/github/rhysd/actionlint/LICENSE; \
    copy_notice "${GOMODCACHE}/github.com/google/yamlfmt@${YAMLFMT_VERSION}" /notices/github/google/yamlfmt; \
    copy_notice "${GOMODCACHE}/mvdan.cc/sh/v3@${SHFMT_VERSION}" /notices/github/mvdan/sh; \
    copy_notice "${GOMODCACHE}/github.com/mrtazz/checkmake@*" /notices/github/mrtazz/checkmake; \
    copy_notice "${GOMODCACHE}/github.com/rhysd/actionlint@${ACTIONLINT_VERSION}" /notices/github/rhysd/actionlint; \
    chmod -R a+rX /licenses /notices
# Stage 2: Final image
FROM ${NODE_IMAGE}
ARG PRETTIER_VERSION
ARG BIOME_VERSION
ARG JQ_VERSION
ARG YQ_VERSION
ARG RIPGREP_VERSION
ARG TAPLO_VERSION
ARG BASH_VERSION
ARG GIT_VERSION
ARG CURL_VERSION
ARG MINISIGN_VERSION

# Install Alpine packages: jq, yq-go, ripgrep, taplo, bash, git, curl, minisign
RUN apk add --no-cache \
    jq=${JQ_VERSION} \
    yq-go=${YQ_VERSION} \
    ripgrep=${RIPGREP_VERSION} \
    taplo=${TAPLO_VERSION} \
    bash=${BASH_VERSION} \
    git=${GIT_VERSION} \
    curl=${CURL_VERSION} \
    minisign=${MINISIGN_VERSION}

# Standard location for license texts and notices (transparency / compliance support)
RUN mkdir -p \
      /licenses/github /licenses/alpine /licenses/npm \
      /notices/github /notices/alpine /notices/npm && \
    if [ -d /usr/share/licenses ]; then \
      cp -a /usr/share/licenses/. /licenses/alpine/; \
    fi && \
    chmod -R a+rX /licenses /notices

# Install Prettier and Biome globally
RUN npm install -g prettier@${PRETTIER_VERSION} @biomejs/biome@${BIOME_VERSION} && \
    npm cache clean --force && \
    # Capture top-level license files from installed npm packages
    mkdir -p /licenses/npm/prettier /licenses/npm/biome && \
    if [ -f /usr/local/lib/node_modules/prettier/LICENSE ]; then \
      cp /usr/local/lib/node_modules/prettier/LICENSE /licenses/npm/prettier/LICENSE; \
    fi && \
    if [ -f /usr/local/lib/node_modules/@biomejs/biome/LICENSE ]; then \
      cp /usr/local/lib/node_modules/@biomejs/biome/LICENSE /licenses/npm/biome/LICENSE; \
    fi && \
    chmod -R a+rX /licenses/npm

# Copy Go tools from builder
COPY --from=go-builder /go/bin/yamlfmt /usr/local/bin/yamlfmt
COPY --from=go-builder /go/bin/shfmt /usr/local/bin/shfmt
COPY --from=go-builder /go/bin/checkmake /usr/local/bin/checkmake
COPY --from=go-builder /go/bin/actionlint /usr/local/bin/actionlint

# Copy staged Go tool licenses/notices
COPY --from=go-builder /licenses/github/ /licenses/github/
COPY --from=go-builder /notices/github/ /notices/github/

# Add curated license texts for non-apk sources
RUN set -eux; \
    MINISIGN_UPSTREAM_VERSION="${MINISIGN_VERSION%%-r*}"; \
    mkdir -p /licenses/github/jedisct1/minisign; \
    curl -fsSL "https://raw.githubusercontent.com/jedisct1/minisign/${MINISIGN_UPSTREAM_VERSION}/LICENSE" \
      -o /licenses/github/jedisct1/minisign/LICENSE; \
    chmod -R a+rX /licenses/github/jedisct1/minisign

# Create non-root user for security (node:alpine provides 'node' user)
# /work owned by node user for volume mounts
RUN mkdir -p /work && chown node:node /work

# Set working directory
WORKDIR /work

# Run as non-root user (security best practice)
USER node

# Default entrypoint: shell for flexible usage
ENTRYPOINT ["/bin/sh"]
