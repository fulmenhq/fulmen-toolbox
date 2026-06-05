# goneat-tools Docker Image
# Code quality and formatting tools: Prettier, Biome, yamlfmt, shfmt, checkmake, actionlint, jq, yq, ripgrep, taplo
# Base: node:22-alpine for Prettier + Alpine pkgs for others
# Multi-arch: linux/amd64 + linux/arm64
#
# Build targets:
# - slim: tool payload only (no runner baseline)
# - runner (default): slim + runner baseline packages

# Version pins
#
# GO_IMAGE ↔ GO_VERSION coupling: bumping GO_VERSION (the toolchain extracted
# to /opt/go for runner consumers) requires re-pinning GO_IMAGE digest to a
# golang:1.X-alpine tag containing the same Go patch version. The two ARGs
# must stay in sync — a mismatch silently ships a runner whose builder Go
# differs from its runtime Go, defeating the consumer fix landed in v0.4.0.
ARG GO_IMAGE=golang:1.26-alpine@sha256:f23e8b227fb4493eabe03bede4d5a32d04092da71962f1fb79b5f7d1e6c2a17f
ARG NODE_IMAGE=node:22-alpine@sha256:968df39aedcea65eeb078fb336ed7191baf48f972b4479711397108be0966920
ARG YAMLFMT_VERSION=v0.21.0
ARG SHFMT_VERSION=v3.12.0
ARG CHECKMAKE_VERSION=v0.3.2
ARG ACTIONLINT_VERSION=v1.7.10
ARG PRETTIER_VERSION=3.8.0
ARG BIOME_VERSION=2.3.11
ARG JQ_VERSION=1.8.1-r0
ARG YQ_VERSION=4.49.2-r6
ARG RIPGREP_VERSION=15.1.0-r0
ARG TAPLO_VERSION=0.10.0-r0

# DX tools (Go)
ARG GONEAT_VERSION=v0.5.13
ARG SFETCH_VERSION=v0.4.5
ARG SHELLSENTRY_VERSION=v0.1.4
ARG GOLANGCI_LINT_VERSION=v2.12.1

# Runner-baseline pinned packages (subset)
ARG BASH_VERSION=5.3.3-r1
ARG GIT_VERSION=2.52.0-r0
ARG CURL_VERSION=8.19.0-r0

# Non-runner tool pins
ARG MINISIGN_VERSION=0.12-r1

# Toolchain pins (runner-only)
ARG GO_VERSION=1.26.4
ARG GO_SHA256_AMD64=1153d3d50e0ac764b447adfe05c2bcf08e889d42a02e0fe0259bd47f6733ad7f
ARG GO_SHA256_ARM64=ef758ae7c6cf9267c9c0ef080b8965f453d89ab2d25d9eb22de4405925238768
ARG RUST_VERSION=1.92.0
ARG RUSTUP_VERSION=1.28.2
ARG RUST_TARGETS="x86_64-unknown-linux-gnu x86_64-unknown-linux-musl aarch64-unknown-linux-gnu aarch64-unknown-linux-musl x86_64-apple-darwin aarch64-apple-darwin x86_64-pc-windows-gnu"
ARG ZIG_VERSION=0.15.2
ARG ZIG_SHA256_AMD64=02aa270f183da276e5b5920b1dac44a63f1a49e55050ebde3aecc9eb82f93239
ARG ZIG_SHA256_ARM64=958ed7d1e00d0ea76590d27666efbf7a932281b3d7ba0c6b01b0ff26498f667f
ARG SYFT_VERSION=v1.45.0
ARG GRYPE_VERSION=v0.113.0
ARG CARGO_DENY_VERSION=0.19.0
ARG CARGO_AUDIT_VERSION=0.22.0
ARG CARGO_ZIGBUILD_VERSION=0.20.1
ARG CARGO_NEXTEST_VERSION=0.9.122
ARG CBINDGEN_VERSION=0.29.0
ARG UV_VERSION=0.9.28
ARG MATURIN_VERSION=1.11.5
ARG PYTEST_VERSION=9.0.2
ARG NAPI_RS_CLI_VERSION=3.5.1

# Stage 1: Build Go tools (yamlfmt, shfmt, checkmake, actionlint, goneat, sfetch)
FROM ${GO_IMAGE} AS go-builder

# Build-only dependency: required for some `go install` VCS fetches.
RUN apk add --no-cache git

ARG YAMLFMT_VERSION
ARG SHFMT_VERSION
ARG CHECKMAKE_VERSION
ARG ACTIONLINT_VERSION
ARG GONEAT_VERSION
ARG SFETCH_VERSION
RUN go install github.com/google/yamlfmt/cmd/yamlfmt@${YAMLFMT_VERSION} && \
    go install mvdan.cc/sh/v3/cmd/shfmt@${SHFMT_VERSION} && \
    go install github.com/checkmake/checkmake/cmd/checkmake@${CHECKMAKE_VERSION} && \
    go install github.com/rhysd/actionlint/cmd/actionlint@${ACTIONLINT_VERSION} && \
    go install github.com/fulmenhq/goneat@${GONEAT_VERSION} && \
    go install github.com/3leaps/sfetch@${SFETCH_VERSION}

# License/notice staging for Go-installed tools
# (Copied into final image under /licenses/github/*)
RUN set -eux; \
    mkdir -p \
      /licenses/github/google/yamlfmt /licenses/github/mvdan/sh /licenses/github/checkmake/checkmake /licenses/github/rhysd/actionlint \
      /licenses/github/fulmenhq/goneat /licenses/github/3leaps/sfetch; \
    mkdir -p \
      /notices/github/google/yamlfmt /notices/github/mvdan/sh /notices/github/checkmake/checkmake /notices/github/rhysd/actionlint \
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
    copy_license "${GOMODCACHE}/github.com/checkmake/checkmake@*/LICENSE" /licenses/github/checkmake/checkmake/LICENSE; \
    copy_license "${GOMODCACHE}/github.com/rhysd/actionlint@${ACTIONLINT_VERSION}/LICENSE*" /licenses/github/rhysd/actionlint/LICENSE; \
    copy_license "${GOMODCACHE}/github.com/fulmenhq/goneat@${GONEAT_VERSION}/LICENSE" /licenses/github/fulmenhq/goneat/LICENSE; \
    copy_license "${GOMODCACHE}/github.com/3leaps/sfetch@${SFETCH_VERSION}/LICENSE" /licenses/github/3leaps/sfetch/LICENSE; \
    copy_notice "${GOMODCACHE}/github.com/google/yamlfmt@${YAMLFMT_VERSION}" /notices/github/google/yamlfmt; \
    copy_notice "${GOMODCACHE}/mvdan.cc/sh/v3@${SHFMT_VERSION}" /notices/github/mvdan/sh; \
    copy_notice "${GOMODCACHE}/github.com/checkmake/checkmake@*" /notices/github/checkmake/checkmake; \
    copy_notice "${GOMODCACHE}/github.com/rhysd/actionlint@${ACTIONLINT_VERSION}" /notices/github/rhysd/actionlint; \
    copy_notice "${GOMODCACHE}/github.com/fulmenhq/goneat@${GONEAT_VERSION}" /notices/github/fulmenhq/goneat; \
    copy_notice "${GOMODCACHE}/github.com/3leaps/sfetch@${SFETCH_VERSION}" /notices/github/3leaps/sfetch; \
    chmod -R a+rX /licenses /notices

# Stage 1b: Build shellsentry (runner-only)
FROM ${GO_IMAGE} AS shellsentry-builder
RUN apk add --no-cache git
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

# Stage 1b2: Build golangci-lint v2 (runner-only)
# Pinned against the runner's Go (${GO_VERSION}) so the resulting binary's
# embedded Go version always matches the toolchain shipped in the runner.
# This closes the "user `go install`s a Go-built linter and inherits an older
# Go" failure pattern that produced the namelens issue against v0.3.5.
# License: GPL-3.0-only (runner is copyleft-by-design per README).
FROM ${GO_IMAGE} AS golangci-lint-builder
RUN apk add --no-cache git
ARG GOLANGCI_LINT_VERSION
RUN go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@${GOLANGCI_LINT_VERSION}
RUN set -eux; \
    mkdir -p \
      /out/bin \
      /out/licenses/github/golangci/golangci-lint; \
    [ -f /go/bin/golangci-lint ] || { echo "golangci-lint binary not at /go/bin/golangci-lint" >&2; ls -la /go/bin >&2; exit 1; }; \
    cp /go/bin/golangci-lint /out/bin/golangci-lint; \
    GOMODCACHE="$(go env GOMODCACHE)"; \
    cp "${GOMODCACHE}/github.com/golangci/golangci-lint/v2@${GOLANGCI_LINT_VERSION}/LICENSE" \
      /out/licenses/github/golangci/golangci-lint/LICENSE; \
    chmod -R a+rX /out

# Stage 1c: Fetch SBOM tools (runner-only)
FROM ${NODE_IMAGE} AS sbom-fetcher
ARG SYFT_VERSION
ARG GRYPE_VERSION
RUN apk add --no-cache ca-certificates curl tar gzip
RUN set -eux; \
    mkdir -p \
      /out/bin \
      /out/licenses/github/anchore/syft \
      /out/licenses/github/anchore/grype \
      /out/notices/github/anchore/syft \
      /out/notices/github/anchore/grype; \
    curl -fsSL "https://raw.githubusercontent.com/anchore/syft/${SYFT_VERSION}/LICENSE" \
      -o /out/licenses/github/anchore/syft/LICENSE; \
    curl -fsSL "https://raw.githubusercontent.com/anchore/grype/${GRYPE_VERSION}/LICENSE" \
      -o /out/licenses/github/anchore/grype/LICENSE; \
    curl -fsSL "https://raw.githubusercontent.com/anchore/syft/${SYFT_VERSION}/NOTICE" \
      -o /out/notices/github/anchore/syft/NOTICE || true; \
    curl -fsSL "https://raw.githubusercontent.com/anchore/grype/${GRYPE_VERSION}/NOTICE" \
      -o /out/notices/github/anchore/grype/NOTICE || true; \
    UNAME_ARCH="$(uname -m)"; \
    case "${UNAME_ARCH}" in \
      x86_64) ARCH="amd64" ;; \
      aarch64) ARCH="arm64" ;; \
      *) echo "Unsupported arch: ${UNAME_ARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/anchore/syft/releases/download/${SYFT_VERSION}/syft_${SYFT_VERSION#v}_linux_${ARCH}.tar.gz" -o /tmp/syft.tar.gz; \
    tar -xzf /tmp/syft.tar.gz -C /out/bin syft; \
    rm /tmp/syft.tar.gz; \
    curl -fsSL "https://github.com/anchore/grype/releases/download/${GRYPE_VERSION}/grype_${GRYPE_VERSION#v}_linux_${ARCH}.tar.gz" -o /tmp/grype.tar.gz; \
    tar -xzf /tmp/grype.tar.gz -C /out/bin grype; \
    rm /tmp/grype.tar.gz; \
    chmod +x /out/bin/syft /out/bin/grype; \
    chmod -R a+rX /out/licenses /out/notices

# Stage 1d: Fetch Zig (runner-only)
FROM ${NODE_IMAGE} AS zig-fetcher
ARG ZIG_VERSION
ARG ZIG_SHA256_AMD64
ARG ZIG_SHA256_ARM64
RUN apk add --no-cache ca-certificates curl tar xz
RUN set -eux; \
    UNAME_ARCH="$(uname -m)"; \
    case "${UNAME_ARCH}" in \
      x86_64) ZIG_ARCH="x86_64"; ZIG_SHA256="${ZIG_SHA256_AMD64}" ;; \
      aarch64) ZIG_ARCH="aarch64"; ZIG_SHA256="${ZIG_SHA256_ARM64}" ;; \
      *) echo "Unsupported arch: ${UNAME_ARCH}" >&2; exit 1 ;; \
    esac; \
    ZIG_TARBALL="zig-${ZIG_ARCH}-linux-${ZIG_VERSION}.tar.xz"; \
    curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/${ZIG_TARBALL}" -o /tmp/zig.tar.xz; \
    echo "${ZIG_SHA256}  /tmp/zig.tar.xz" | sha256sum -c -; \
    mkdir -p /out/zig; \
    tar -xJf /tmp/zig.tar.xz -C /out/zig --strip-components=1; \
    rm /tmp/zig.tar.xz; \
    mkdir -p /out/licenses/zig; \
    if [ -f /out/zig/LICENSE ]; then cp /out/zig/LICENSE /out/licenses/zig/LICENSE; fi; \
    chmod -R a+rX /out

# Stage 1e: Fetch Go toolchain (runner-only)
FROM ${NODE_IMAGE} AS go-fetcher
ARG GO_VERSION
ARG GO_SHA256_AMD64
ARG GO_SHA256_ARM64
RUN apk add --no-cache ca-certificates curl tar
RUN set -eux; \
    UNAME_ARCH="$(uname -m)"; \
    case "${UNAME_ARCH}" in \
      x86_64) GO_ARCH="amd64"; GO_SHA256="${GO_SHA256_AMD64}" ;; \
      aarch64) GO_ARCH="arm64"; GO_SHA256="${GO_SHA256_ARM64}" ;; \
      *) echo "Unsupported arch: ${UNAME_ARCH}" >&2; exit 1 ;; \
    esac; \
    GO_TARBALL="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"; \
    curl -fsSL "https://go.dev/dl/${GO_TARBALL}" -o /tmp/go.tar.gz; \
    echo "${GO_SHA256}  /tmp/go.tar.gz" | sha256sum -c -; \
    mkdir -p /out/go; \
    tar -xzf /tmp/go.tar.gz -C /out/go --strip-components=1; \
    rm /tmp/go.tar.gz; \
    mkdir -p /out/licenses/go; \
    if [ -f /out/go/LICENSE ]; then cp /out/go/LICENSE /out/licenses/go/LICENSE; fi; \
    chmod -R a+rX /out

# Stage 1f: Install Rust toolchain + cargo tools (runner-only)
FROM ${NODE_IMAGE} AS rustup-builder
ARG RUST_VERSION
ARG RUSTUP_VERSION
ARG RUST_TARGETS
ARG CARGO_DENY_VERSION
ARG CARGO_AUDIT_VERSION
ARG CARGO_ZIGBUILD_VERSION
ARG CARGO_NEXTEST_VERSION
ARG CBINDGEN_VERSION
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN apk add --no-cache ca-certificates curl build-base
RUN set -eux; \
    UNAME_ARCH="$(uname -m)"; \
    case "${UNAME_ARCH}" in \
      x86_64) RUSTUP_HOST="x86_64-unknown-linux-musl" ;; \
      aarch64) RUSTUP_HOST="aarch64-unknown-linux-musl" ;; \
      *) echo "Unsupported arch: ${UNAME_ARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${RUSTUP_HOST}/rustup-init" -o /tmp/rustup-init; \
    chmod +x /tmp/rustup-init; \
    /tmp/rustup-init -y --no-modify-path --profile minimal --default-toolchain "${RUST_VERSION}" --default-host "${RUSTUP_HOST}"; \
    rm /tmp/rustup-init; \
    rustup component add rustfmt clippy; \
    for target in ${RUST_TARGETS}; do rustup target add "${target}"; done; \
    mkdir -p /out/licenses/rust; \
    TOOLCHAIN_DIR="${RUSTUP_HOME}/toolchains/${RUST_VERSION}-${RUSTUP_HOST}"; \
    for license in LICENSE-APACHE LICENSE-MIT; do \
      if [ -f "${TOOLCHAIN_DIR}/${license}" ]; then \
        cp "${TOOLCHAIN_DIR}/${license}" "/out/licenses/rust/${license}"; \
      elif [ -f "${TOOLCHAIN_DIR}/share/doc/rust/${license}" ]; then \
        cp "${TOOLCHAIN_DIR}/share/doc/rust/${license}" "/out/licenses/rust/${license}"; \
      else \
        curl -fsSL "https://raw.githubusercontent.com/rust-lang/rust/${RUST_VERSION}/${license}" \
          -o "/out/licenses/rust/${license}"; \
      fi; \
    done; \
    chmod -R a+rX /out/licenses

# Stage 1g: Fetch cargo tools (runner-only)
FROM ${NODE_IMAGE} AS cargo-tools-fetcher
ARG CARGO_DENY_VERSION
ARG CARGO_AUDIT_VERSION
ARG CARGO_ZIGBUILD_VERSION
ARG CARGO_NEXTEST_VERSION
ARG CBINDGEN_VERSION
RUN apk add --no-cache ca-certificates curl tar gzip xz
RUN set -eux; \
    mkdir -p \
      /out/bin \
      /out/licenses/crates/cargo-deny \
      /out/licenses/crates/cargo-audit \
      /out/licenses/crates/cargo-zigbuild \
      /out/licenses/crates/cargo-nextest \
      /out/licenses/crates/cbindgen; \
    UNAME_ARCH="$(uname -m)"; \
    case "${UNAME_ARCH}" in \
      x86_64) \
        DENY_ARCH="x86_64-unknown-linux-musl"; \
        AUDIT_ARCH="x86_64-unknown-linux-musl"; \
        ZIGBUILD_ARCH="x86_64-unknown-linux-musl"; \
        NEXTEST_ARCH="x86_64-unknown-linux-musl"; \
        CBINDGEN_ASSET="cbindgen-ubuntu22.04"; \
        ;; \
      aarch64) \
        DENY_ARCH="aarch64-unknown-linux-musl"; \
        AUDIT_ARCH="aarch64-unknown-linux-gnu"; \
        ZIGBUILD_ARCH="aarch64-unknown-linux-musl"; \
        NEXTEST_ARCH="aarch64-unknown-linux-gnu"; \
        CBINDGEN_ASSET="cbindgen-ubuntu22.04-aarch64"; \
        ;; \
      *) echo "Unsupported arch: ${UNAME_ARCH}" >&2; exit 1 ;; \
    esac; \
    fetch_and_verify() { url="$1" sha_url="$2" output="$3"; \
      curl -fsSL "$url" -o "$output"; \
      if [ -n "$sha_url" ]; then \
        sha="$(curl -fsSL "$sha_url" | cut -d' ' -f1)"; \
        echo "${sha}  ${output}" | sha256sum -c -; \
      fi; \
    }; \
    extract_binary() { archive="$1" binary="$2" dest="$3" license_dest="$4" require_license="$5"; \
      rm -rf /tmp/extract; \
      mkdir -p /tmp/extract "$license_dest"; \
      tar -xzf "$archive" -C /tmp/extract; \
      if [ -f "/tmp/extract/${binary}" ]; then \
        cp "/tmp/extract/${binary}" "$dest"; \
      else \
        for path in /tmp/extract/*/"${binary}"; do \
          if [ -f "$path" ]; then cp "$path" "$dest"; break; fi; \
        done; \
      fi; \
      [ -f "$dest" ] || { echo "missing ${binary} in ${archive}" >&2; exit 1; }; \
      if [ "${require_license}" = "1" ]; then \
        found=0; \
        for dir in /tmp/extract /tmp/extract/*; do \
          for file in "$dir"/LICENSE* "$dir"/COPYING*; do \
            if [ -f "$file" ]; then cp "$file" "$license_dest/$(basename "$file")"; found=1; fi; \
          done; \
        done; \
        [ "$found" -eq 1 ] || { echo "missing LICENSE for ${binary}" >&2; exit 1; }; \
      fi; \
    }; \
    fetch_and_verify \
      "https://github.com/EmbarkStudios/cargo-deny/releases/download/${CARGO_DENY_VERSION}/cargo-deny-${CARGO_DENY_VERSION}-${DENY_ARCH}.tar.gz" \
      "https://github.com/EmbarkStudios/cargo-deny/releases/download/${CARGO_DENY_VERSION}/cargo-deny-${CARGO_DENY_VERSION}-${DENY_ARCH}.tar.gz.sha256" \
      /tmp/cargo-deny.tar.gz; \
    extract_binary /tmp/cargo-deny.tar.gz cargo-deny /out/bin/cargo-deny /out/licenses/crates/cargo-deny 1; \
    rm /tmp/cargo-deny.tar.gz; \
    fetch_and_verify \
      "https://github.com/RustSec/rustsec/releases/download/cargo-audit/v${CARGO_AUDIT_VERSION}/cargo-audit-${AUDIT_ARCH}-v${CARGO_AUDIT_VERSION}.tgz" \
      "" \
      /tmp/cargo-audit.tgz; \
    extract_binary /tmp/cargo-audit.tgz cargo-audit /out/bin/cargo-audit /out/licenses/crates/cargo-audit 1; \
    rm /tmp/cargo-audit.tgz; \
    fetch_and_verify \
      "https://github.com/rust-cross/cargo-zigbuild/releases/download/v${CARGO_ZIGBUILD_VERSION}/cargo-zigbuild-v${CARGO_ZIGBUILD_VERSION}.${ZIGBUILD_ARCH}.tar.gz" \
      "https://github.com/rust-cross/cargo-zigbuild/releases/download/v${CARGO_ZIGBUILD_VERSION}/cargo-zigbuild-v${CARGO_ZIGBUILD_VERSION}.${ZIGBUILD_ARCH}.tar.gz.sha256" \
      /tmp/cargo-zigbuild.tar.gz; \
    extract_binary /tmp/cargo-zigbuild.tar.gz cargo-zigbuild /out/bin/cargo-zigbuild /out/licenses/crates/cargo-zigbuild 0; \
    rm /tmp/cargo-zigbuild.tar.gz; \
    curl -fsSL "https://raw.githubusercontent.com/rust-cross/cargo-zigbuild/v${CARGO_ZIGBUILD_VERSION}/LICENSE" \
      -o /out/licenses/crates/cargo-zigbuild/LICENSE; \
    fetch_and_verify \
      "https://github.com/nextest-rs/nextest/releases/download/cargo-nextest-${CARGO_NEXTEST_VERSION}/cargo-nextest-${CARGO_NEXTEST_VERSION}-${NEXTEST_ARCH}.tar.gz" \
      "https://github.com/nextest-rs/nextest/releases/download/cargo-nextest-${CARGO_NEXTEST_VERSION}/cargo-nextest-${CARGO_NEXTEST_VERSION}-${NEXTEST_ARCH}.sha256" \
      /tmp/cargo-nextest.tar.gz; \
    extract_binary /tmp/cargo-nextest.tar.gz cargo-nextest /out/bin/cargo-nextest /out/licenses/crates/cargo-nextest 0; \
    rm /tmp/cargo-nextest.tar.gz; \
    curl -fsSL "https://raw.githubusercontent.com/nextest-rs/nextest/cargo-nextest-${CARGO_NEXTEST_VERSION}/LICENSE-APACHE" \
      -o /out/licenses/crates/cargo-nextest/LICENSE-APACHE; \
    curl -fsSL "https://raw.githubusercontent.com/nextest-rs/nextest/cargo-nextest-${CARGO_NEXTEST_VERSION}/LICENSE-MIT" \
      -o /out/licenses/crates/cargo-nextest/LICENSE-MIT; \
    fetch_and_verify \
      "https://github.com/mozilla/cbindgen/releases/download/${CBINDGEN_VERSION}/${CBINDGEN_ASSET}" \
      "" \
      /out/bin/cbindgen; \
    chmod +x /out/bin/cargo-deny /out/bin/cargo-audit /out/bin/cargo-zigbuild /out/bin/cargo-nextest /out/bin/cbindgen; \
    curl -fsSL "https://raw.githubusercontent.com/mozilla/cbindgen/${CBINDGEN_VERSION}/LICENSE" \
      -o /out/licenses/crates/cbindgen/LICENSE; \
    chmod -R a+rX /out/licenses

# Stage 2: Fetch curated license texts (kept out of runtime layers)
FROM ${NODE_IMAGE} AS license-fetcher
ARG MINISIGN_VERSION
RUN apk add --no-cache ca-certificates curl
RUN set -eux; \
    MINISIGN_UPSTREAM_VERSION="${MINISIGN_VERSION%%-r*}"; \
    mkdir -p /licenses/github/jedisct1/minisign; \
    curl -fsSL "https://raw.githubusercontent.com/jedisct1/minisign/${MINISIGN_UPSTREAM_VERSION}/LICENSE" \
      -o /licenses/github/jedisct1/minisign/LICENSE; \
    chmod -R a+rX /licenses

# Stage 3: slim variant (tools only)
FROM ${NODE_IMAGE} AS slim
ARG PRETTIER_VERSION
ARG BIOME_VERSION
ARG JQ_VERSION
ARG YQ_VERSION
ARG RIPGREP_VERSION
ARG TAPLO_VERSION
ARG MINISIGN_VERSION

# Install non-runner Alpine packages
RUN apk add --no-cache \
    jq=${JQ_VERSION} \
    yq-go=${YQ_VERSION} \
    ripgrep=${RIPGREP_VERSION} \
    taplo=${TAPLO_VERSION} \
    minisign=${MINISIGN_VERSION}

# Standard location for license texts and notices (transparency / compliance support)
RUN mkdir -p \
      /licenses/github /licenses/alpine /licenses/npm /licenses/pypi /licenses/zig /licenses/go /licenses/rust /licenses/crates \
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

# Copy staged Go tool licenses/notices
COPY --from=go-builder /licenses/github/ /licenses/github/
COPY --from=go-builder /notices/github/ /notices/github/

# Copy curated license texts
COPY --from=license-fetcher /licenses/github/jedisct1/minisign/LICENSE /licenses/github/jedisct1/minisign/LICENSE

# Create non-root user for security (node:alpine provides 'node' user)
# /work owned by node user for volume mounts
RUN mkdir -p /work && chown node:node /work

WORKDIR /work
USER node
ENTRYPOINT ["/bin/sh"]

# Stage 4: runner variant (default)
FROM slim AS runner

ARG BASH_VERSION
ARG GIT_VERSION
ARG CURL_VERSION
ARG UV_VERSION
ARG MATURIN_VERSION
ARG PYTEST_VERSION
ARG NAPI_RS_CLI_VERSION

USER root


# Install runner baseline packages
RUN apk add --no-cache \
    bash=${BASH_VERSION} \
    git=${GIT_VERSION} \
    curl=${CURL_VERSION} \
    build-base \
    pkgconf \
    python3 \
    py3-pip \
    yamllint \
    gcompat \
    ca-certificates \
    coreutils \
    findutils \
    diffutils \
    make \
    tar \
    gzip \
    xz \
    unzip \
    zip \
    openssh-client

ENV CARGO_HOME=/opt/cargo \
    RUSTUP_HOME=/opt/rustup \
    GOPATH=/opt/gopath \
    PATH=/opt/go/bin:/opt/cargo/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    CGO_ENABLED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1

COPY --from=go-fetcher /out/go /opt/go
COPY --from=go-fetcher /out/licenses/go/LICENSE /licenses/go/LICENSE
COPY --from=zig-fetcher /out/zig /opt/zig
COPY --from=zig-fetcher /out/licenses/zig/LICENSE /licenses/zig/LICENSE
COPY --from=rustup-builder /opt/cargo /opt/cargo
COPY --from=rustup-builder /opt/rustup /opt/rustup
COPY --from=rustup-builder /out/licenses/rust /licenses/rust
COPY --from=cargo-tools-fetcher /out/bin/cargo-deny /usr/local/bin/cargo-deny
COPY --from=cargo-tools-fetcher /out/bin/cargo-audit /usr/local/bin/cargo-audit
COPY --from=cargo-tools-fetcher /out/bin/cargo-zigbuild /usr/local/bin/cargo-zigbuild
COPY --from=cargo-tools-fetcher /out/bin/cargo-nextest /usr/local/bin/cargo-nextest
COPY --from=cargo-tools-fetcher /out/bin/cbindgen /usr/local/bin/cbindgen
COPY --from=cargo-tools-fetcher /out/licenses/crates /licenses/crates
COPY --from=sbom-fetcher /out/bin/syft /usr/local/bin/syft
COPY --from=sbom-fetcher /out/bin/grype /usr/local/bin/grype
COPY --from=sbom-fetcher /out/licenses/github/anchore/ /licenses/github/anchore/
COPY --from=sbom-fetcher /out/notices/github/anchore/ /notices/github/anchore/
COPY --from=shellsentry-builder /out/bin/shellsentry /usr/local/bin/shellsentry
COPY --from=shellsentry-builder /out/licenses/github/3leaps/shellsentry/LICENSE /licenses/github/3leaps/shellsentry/LICENSE
COPY --from=shellsentry-builder /out/notices/github/3leaps/shellsentry/NOTICE /notices/github/3leaps/shellsentry/NOTICE
COPY --from=golangci-lint-builder /out/bin/golangci-lint /usr/local/bin/golangci-lint
COPY --from=golangci-lint-builder /out/licenses/github/golangci/golangci-lint/LICENSE /licenses/github/golangci/golangci-lint/LICENSE

RUN set -eux; \
    ln -s /opt/zig/zig /usr/local/bin/zig; \
    mkdir -p /opt/gopath; \
    python3 -m pip install --no-cache-dir uv==${UV_VERSION} maturin==${MATURIN_VERSION} pytest==${PYTEST_VERSION}; \
    npm install -g @napi-rs/cli@${NAPI_RS_CLI_VERSION}; \
    mkdir -p /licenses/npm/napi-rs; \
    if [ -f /usr/local/lib/node_modules/@napi-rs/cli/LICENSE ]; then \
      cp /usr/local/lib/node_modules/@napi-rs/cli/LICENSE /licenses/npm/napi-rs/LICENSE; \
    elif [ -f /usr/local/lib/node_modules/@napi-rs/cli/LICENSE.md ]; then \
      cp /usr/local/lib/node_modules/@napi-rs/cli/LICENSE.md /licenses/npm/napi-rs/LICENSE; \
    fi; \
    python3 - <<'PY'
import importlib.metadata as md
from pathlib import Path
import shutil

def copy_license(package, destination):
    dist = md.distribution(package)
    files = list(dist.files or [])
    candidates = [f for f in files if f.name.lower().startswith("license")]
    if not candidates:
        raise SystemExit(f"missing license for {package}")
    source = dist.locate_file(candidates[0])
    Path(destination).parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(source, destination)

copy_license("uv", "/licenses/pypi/uv/LICENSE")
copy_license("maturin", "/licenses/pypi/maturin/LICENSE")
copy_license("pytest", "/licenses/pypi/pytest/LICENSE")
PY

RUN chmod -R a+rX /licenses /notices /opt && \
    chown -R node:node /opt/gopath /opt/cargo /opt/rustup /opt/go /opt/zig

USER node
