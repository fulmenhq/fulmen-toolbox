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

# Install Alpine packages: jq, yq-go, ripgrep, taplo, bash, git, curl
RUN apk add --no-cache \
    jq=${JQ_VERSION} \
    yq-go=${YQ_VERSION} \
    ripgrep=${RIPGREP_VERSION} \
    taplo=${TAPLO_VERSION} \
    bash=${BASH_VERSION} \
    git=${GIT_VERSION} \
    curl=${CURL_VERSION}

# Install Prettier globally
RUN npm install -g prettier@${PRETTIER_VERSION} @biomejs/biome@${BIOME_VERSION} && \
    npm cache clean --force

# Copy Go tools from builder
COPY --from=go-builder /go/bin/yamlfmt /usr/local/bin/yamlfmt
COPY --from=go-builder /go/bin/shfmt /usr/local/bin/shfmt
COPY --from=go-builder /go/bin/checkmake /usr/local/bin/checkmake
COPY --from=go-builder /go/bin/actionlint /usr/local/bin/actionlint

# Create non-root user for security (node:alpine provides 'node' user)
# /work owned by node user for volume mounts
RUN mkdir -p /work && chown node:node /work

# Set working directory
WORKDIR /work

# Run as non-root user (security best practice)
USER node

# Default entrypoint: shell for flexible usage
ENTRYPOINT ["/bin/sh"]
