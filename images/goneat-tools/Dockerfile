# goneat-tools Docker Image
# Code quality and formatting tools: Prettier, yamlfmt, jq, yq, ripgrep
# Base: node:22-alpine for Prettier + Alpine pkgs for others
# Multi-arch: linux/amd64 + linux/arm64
# Size target: ~150-250MB

# Version pins
ARG GO_IMAGE=golang:1.23-alpine@sha256:383395b794dffa5b53012a212365d40c8e37109a626ca30d6151c8348d380b5f
ARG NODE_IMAGE=node:22-alpine@sha256:9632533eda8061fc1e9960cfb3f8762781c07a00ee7317f5dc0e13c05e15166f
ARG YAMLFMT_VERSION=v0.20.0
ARG PRETTIER_VERSION=3.7.4
ARG BIOME_VERSION=2.3.8
ARG JQ_VERSION=1.8.1-r0
ARG YQ_VERSION=4.49.2-r1
ARG RIPGREP_VERSION=15.1.0-r0
ARG TAPLO_VERSION=0.10.0-r0
ARG BASH_VERSION=5.3.3-r1
ARG GIT_VERSION=2.52.0-r0

# Stage 1: Build yamlfmt (Go binary)
FROM ${GO_IMAGE} AS go-builder
ARG YAMLFMT_VERSION
RUN go install github.com/google/yamlfmt/cmd/yamlfmt@${YAMLFMT_VERSION}

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

# Install Alpine packages: jq, yq-go, ripgrep, taplo, bash, git
RUN apk add --no-cache \
    jq=${JQ_VERSION} \
    yq-go=${YQ_VERSION} \
    ripgrep=${RIPGREP_VERSION} \
    taplo=${TAPLO_VERSION} \
    bash=${BASH_VERSION} \
    git=${GIT_VERSION}

# Install Prettier globally
RUN npm install -g prettier@${PRETTIER_VERSION} @biomejs/biome@${BIOME_VERSION} && \
    npm cache clean --force

# Copy yamlfmt from builder
COPY --from=go-builder /go/bin/yamlfmt /usr/local/bin/yamlfmt

# Set working directory
WORKDIR /work

# Default entrypoint: shell for flexible usage
ENTRYPOINT ["/bin/sh"]
