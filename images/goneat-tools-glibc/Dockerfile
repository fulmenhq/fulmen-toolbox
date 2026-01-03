# goneat-tools glibc runner Docker Image
# Code quality and formatting tools + CGO-capable runner baseline
# Base: node:22-bookworm-slim (glibc)
# Multi-arch: linux/amd64 + linux/arm64
#
# Build targets:
# - slim: tool payload only (not published)
# - runner (default): slim + runner baseline + build tools

# Version pins
ARG GO_IMAGE=golang:1.25-bookworm@sha256:2c7c65601b020ee79db4c1a32ebee0bf3d6b298969ec683e24fcbea29305f10e
ARG NODE_IMAGE=node:22-bookworm-slim@sha256:7378f5a4830ef48eb36d1abf4ef398391db562b5c41a0bded83192fbcea21cc8
ARG DEBIAN_IMAGE=debian:bookworm-slim@sha256:d5d3f9c23164ea16f31852f95bd5959aad1c5e854332fe00f7b3a20fcc9f635c
ARG YAMLFMT_VERSION=v0.20.0
ARG SHFMT_VERSION=v3.12.0
ARG CHECKMAKE_VERSION=0.2.2
ARG ACTIONLINT_VERSION=v1.7.9
ARG PRETTIER_VERSION=3.7.4
ARG BIOME_VERSION=2.3.8
ARG JQ_VERSION=1.8.1
ARG YQ_VERSION=v4.49.2
ARG RIPGREP_VERSION=15.1.0
ARG TAPLO_VERSION=0.10.0

# DX tools (Go)
ARG GONEAT_VERSION=v0.4.2
ARG SFETCH_VERSION=v0.3.2

# Non-runner tool pins
ARG MINISIGN_VERSION=0.12

# Stage 1: Build Go tools (yamlfmt, shfmt, checkmake, actionlint, goneat, sfetch)
FROM ${GO_IMAGE} AS go-builder

# Build-only dependency: required for some `go install` VCS fetches.
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ARG YAMLFMT_VERSION
ARG SHFMT_VERSION
ARG CHECKMAKE_VERSION
ARG ACTIONLINT_VERSION
ARG GONEAT_VERSION
ARG SFETCH_VERSION
RUN go install github.com/google/yamlfmt/cmd/yamlfmt@${YAMLFMT_VERSION} && \
    go install mvdan.cc/sh/v3/cmd/shfmt@${SHFMT_VERSION} && \
    go install github.com/mrtazz/checkmake/cmd/checkmake@${CHECKMAKE_VERSION} && \
    go install github.com/rhysd/actionlint/cmd/actionlint@${ACTIONLINT_VERSION} && \
    go install github.com/fulmenhq/goneat@${GONEAT_VERSION} && \
    go install github.com/3leaps/sfetch@${SFETCH_VERSION}

# License/notice staging for Go-installed tools
# (Copied into final image under /licenses/github/*)
RUN set -eux; \
    mkdir -p \
      /licenses/github/google/yamlfmt /licenses/github/mvdan/sh /licenses/github/mrtazz/checkmake /licenses/github/rhysd/actionlint \
      /licenses/github/fulmenhq/goneat /licenses/github/3leaps/sfetch; \
    mkdir -p \
      /notices/github/google/yamlfmt /notices/github/mvdan/sh /notices/github/mrtazz/checkmake /notices/github/rhysd/actionlint \
      /notices/github/fulmenhq/goneat /notices/github/3leaps/sfetch; \
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
    copy_license "${GOMODCACHE}/github.com/fulmenhq/goneat@${GONEAT_VERSION}/LICENSE" /licenses/github/fulmenhq/goneat/LICENSE; \
    copy_license "${GOMODCACHE}/github.com/3leaps/sfetch@${SFETCH_VERSION}/LICENSE" /licenses/github/3leaps/sfetch/LICENSE; \
    copy_notice "${GOMODCACHE}/github.com/google/yamlfmt@${YAMLFMT_VERSION}" /notices/github/google/yamlfmt; \
    copy_notice "${GOMODCACHE}/mvdan.cc/sh/v3@${SHFMT_VERSION}" /notices/github/mvdan/sh; \
    copy_notice "${GOMODCACHE}/github.com/mrtazz/checkmake@*" /notices/github/mrtazz/checkmake; \
    copy_notice "${GOMODCACHE}/github.com/rhysd/actionlint@${ACTIONLINT_VERSION}" /notices/github/rhysd/actionlint; \
    copy_notice "${GOMODCACHE}/github.com/fulmenhq/goneat@${GONEAT_VERSION}" /notices/github/fulmenhq/goneat; \
    copy_notice "${GOMODCACHE}/github.com/3leaps/sfetch@${SFETCH_VERSION}" /notices/github/3leaps/sfetch; \
    chmod -R a+rX /licenses /notices

# Stage 2: Fetch curated license texts (kept out of runtime layers)
FROM ${DEBIAN_IMAGE} AS license-fetcher
ARG MINISIGN_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    mkdir -p /licenses/github/jedisct1/minisign; \
    curl -fsSL "https://raw.githubusercontent.com/jedisct1/minisign/${MINISIGN_VERSION}/LICENSE" \
      -o /licenses/github/jedisct1/minisign/LICENSE; \
    chmod -R a+rX /licenses

# Stage 3: Fetch platform binaries (jq, yq, ripgrep, taplo, minisign)
FROM ${DEBIAN_IMAGE} AS bin-fetcher
ARG JQ_VERSION
ARG YQ_VERSION
ARG RIPGREP_VERSION
ARG TAPLO_VERSION
ARG MINISIGN_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl tar gzip xz-utils && \
    rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    mkdir -p /out/bin /tmp/rg /tmp/minisign; \
    case "$(uname -m)" in \
      x86_64) ARCH="amd64"; RG_ARCH="x86_64"; RG_LIBC="musl"; TAPLO_ARCH="x86_64" ;; \
      aarch64) ARCH="arm64"; RG_ARCH="aarch64"; RG_LIBC="gnu"; TAPLO_ARCH="aarch64" ;; \
      *) echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${ARCH}" -o /out/bin/jq; \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" -o /out/bin/yq; \
    curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${RG_ARCH}-unknown-linux-${RG_LIBC}.tar.gz" -o /tmp/rg.tar.gz; \
    tar -xzf /tmp/rg.tar.gz -C /tmp/rg --strip-components=1; \
    install -m 0755 /tmp/rg/rg /out/bin/rg; \
    curl -fsSL "https://github.com/tamasfe/taplo/releases/download/${TAPLO_VERSION}/taplo-linux-${TAPLO_ARCH}.gz" -o /tmp/taplo.gz; \
    gunzip -c /tmp/taplo.gz > /out/bin/taplo; \
    curl -fsSL "https://github.com/jedisct1/minisign/releases/download/${MINISIGN_VERSION}/minisign-${MINISIGN_VERSION}-linux.tar.gz" -o /tmp/minisign.tar.gz; \
    tar -xzf /tmp/minisign.tar.gz -C /tmp/minisign; \
    MINISIGN_BIN="$(find /tmp/minisign -type f -name minisign -perm -u+x | head -n 1)"; \
    [ -n "$MINISIGN_BIN" ]; \
    install -m 0755 "$MINISIGN_BIN" /out/bin/minisign; \
    chmod 0755 /out/bin/jq /out/bin/yq /out/bin/taplo /out/bin/rg /out/bin/minisign

# Stage 4: slim variant (tools only)
FROM ${NODE_IMAGE} AS slim
ARG PRETTIER_VERSION
ARG BIOME_VERSION

# Minimal runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Standard location for license texts and notices (transparency / compliance support)
RUN mkdir -p \
      /licenses/github /licenses/debian /licenses/npm \
      /notices/github /notices/debian /notices/npm && \
    chmod -R a+rX /licenses /notices

# Install Prettier and Biome globally
RUN npm install -g prettier@${PRETTIER_VERSION} @biomejs/biome@${BIOME_VERSION} && \
    npm cache clean --force && \
    # Capture top-level license files from installed npm packages
    mkdir -p /licenses/npm/prettier /licenses/npm/biome && \
    if [ -f /usr/local/lib/node_modules/prettier/LICENSE ]; then \
      cp /usr/local/lib/node_modules/prettier/LICENSE /licenses/npm/prettier/LICENSE; \
    fi && \
    for f in LICENSE-APACHE LICENSE-MIT; do \
      if [ -f "/usr/local/lib/node_modules/@biomejs/biome/$f" ]; then \
        cp "/usr/local/lib/node_modules/@biomejs/biome/$f" "/licenses/npm/biome/$f"; \
      fi; \
    done && \
    chmod -R a+rX /licenses/npm

# Copy Go tools from builder
COPY --from=go-builder /go/bin/yamlfmt /usr/local/bin/yamlfmt
COPY --from=go-builder /go/bin/shfmt /usr/local/bin/shfmt
COPY --from=go-builder /go/bin/checkmake /usr/local/bin/checkmake
COPY --from=go-builder /go/bin/actionlint /usr/local/bin/actionlint
COPY --from=go-builder /go/bin/goneat /usr/local/bin/goneat
COPY --from=go-builder /go/bin/sfetch /usr/local/bin/sfetch

# Copy platform binaries
COPY --from=bin-fetcher /out/bin/jq /usr/local/bin/jq
COPY --from=bin-fetcher /out/bin/yq /usr/local/bin/yq
COPY --from=bin-fetcher /out/bin/rg /usr/local/bin/rg
COPY --from=bin-fetcher /out/bin/taplo /usr/local/bin/taplo
COPY --from=bin-fetcher /out/bin/minisign /usr/local/bin/minisign

# Copy staged Go tool licenses/notices
COPY --from=go-builder /licenses/github/ /licenses/github/
COPY --from=go-builder /notices/github/ /notices/github/

# Copy curated license texts
COPY --from=license-fetcher /licenses/github/jedisct1/minisign/LICENSE /licenses/github/jedisct1/minisign/LICENSE

# Create non-root user for security (node:bookworm-slim provides 'node' user)
# /work owned by node user for volume mounts
RUN mkdir -p /work && chown node:node /work

WORKDIR /work
USER node
ENTRYPOINT ["/bin/sh"]

# Stage 5: runner variant (default)
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

USER node
