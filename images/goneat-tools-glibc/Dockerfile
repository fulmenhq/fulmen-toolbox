# goneat-tools glibc runner Docker Image
# Code quality and formatting tools + CGO-capable runner baseline
# Base: node:22-bookworm-slim (glibc)
# Multi-arch: linux/amd64 + linux/arm64
#
# Build targets:
# - slim: tool payload only (not published)
# - runner (default): slim + runner baseline + build tools

# Version pins
#
# GO_IMAGE ↔ GO_VERSION coupling: bumping GO_VERSION (the toolchain extracted
# to /opt/go for runner consumers) requires re-pinning GO_IMAGE digest to a
# golang:1.X-bookworm tag containing the same Go patch version. The two ARGs
# must stay in sync — a mismatch silently ships a runner whose builder Go
# differs from its runtime Go, defeating the consumer fix landed in v0.4.0.
ARG GO_IMAGE=golang:1.26-bookworm@sha256:1ecb7edf62a0408027bd5729dfd6b1b8766e578e8df93995b225dfd0944eb651
ARG NODE_IMAGE=node:22-bookworm-slim@sha256:6c74791e557ce11fc957704f6d4fe134a7bc8d6f5ca4403205b2966bd488f6b3
ARG DEBIAN_IMAGE=debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818
ARG YAMLFMT_VERSION=v0.21.0
ARG SHFMT_VERSION=v3.13.1
ARG CHECKMAKE_VERSION=v0.3.2
ARG ACTIONLINT_VERSION=v1.7.12
ARG PRETTIER_VERSION=3.9.6
ARG BIOME_VERSION=2.3.11
# Overrides the npm bundled in the node base. See the npm stage below for the
# maintenance obligation this pin creates.
ARG NPM_VERSION=12.0.1
ARG JQ_VERSION=1.8.1
ARG YQ_VERSION=v4.53.3
ARG RIPGREP_VERSION=15.1.0
ARG TAPLO_VERSION=0.10.0

# DX tools (Go)
ARG GONEAT_VERSION=v0.5.16
ARG SFETCH_VERSION=v0.4.9
ARG SHELLSENTRY_VERSION=v0.1.5
ARG GOLANGCI_LINT_VERSION=v2.12.2

# Non-runner tool pins
ARG MINISIGN_VERSION=0.12

# Toolchain pins (runner-only)
ARG GO_VERSION=1.26.5
ARG GO_SHA256_AMD64=5c2c3b16caefa1d968a94c1daca04a7ca301a496d9b086e17ad77bb81393f053
ARG GO_SHA256_ARM64=fe4789e92b1f33358680864bbe8704289e7bb5fc207d80623c308935bd696d49
ARG RUST_VERSION=1.94.1
ARG RUSTUP_VERSION=1.28.2
ARG RUST_TARGETS="x86_64-unknown-linux-gnu x86_64-unknown-linux-musl aarch64-unknown-linux-gnu aarch64-unknown-linux-musl x86_64-apple-darwin aarch64-apple-darwin x86_64-pc-windows-gnu"
ARG ZIG_VERSION=0.15.2
ARG ZIG_SHA256_AMD64=02aa270f183da276e5b5920b1dac44a63f1a49e55050ebde3aecc9eb82f93239
ARG ZIG_SHA256_ARM64=958ed7d1e00d0ea76590d27666efbf7a932281b3d7ba0c6b01b0ff26498f667f
ARG SYFT_VERSION=v1.50.0
ARG GRYPE_VERSION=v0.116.1
ARG CARGO_DENY_VERSION=0.19.0
ARG CARGO_AUDIT_VERSION=0.22.0
ARG CARGO_ZIGBUILD_VERSION=0.20.1
ARG CARGO_NEXTEST_VERSION=0.9.122
ARG CBINDGEN_VERSION=0.29.0
ARG UV_VERSION=0.9.28
ARG MATURIN_VERSION=1.11.5
ARG PYTEST_VERSION=9.1.1
ARG RUFF_VERSION=0.15.22
ARG NAPI_RS_CLI_VERSION=3.5.1

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

# Stage 1b2: Build golangci-lint v2 (runner-only)
# Pinned against the runner's Go (${GO_VERSION}) so the resulting binary's
# embedded Go version always matches the toolchain shipped in the runner.
# This closes the "user `go install`s a Go-built linter and inherits an older
# Go" failure pattern that produced the namelens issue against v0.3.5.
# License: GPL-3.0-only (runner is copyleft-by-design per README).
FROM ${GO_IMAGE} AS golangci-lint-builder
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && \
    rm -rf /var/lib/apt/lists/*
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
FROM ${DEBIAN_IMAGE} AS sbom-fetcher
ARG SYFT_VERSION
ARG GRYPE_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl tar gzip && \
    rm -rf /var/lib/apt/lists/*
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
FROM ${DEBIAN_IMAGE} AS zig-fetcher
ARG ZIG_VERSION
ARG ZIG_SHA256_AMD64
ARG ZIG_SHA256_ARM64
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl xz-utils && \
    rm -rf /var/lib/apt/lists/*
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
FROM ${DEBIAN_IMAGE} AS go-fetcher
ARG GO_VERSION
ARG GO_SHA256_AMD64
ARG GO_SHA256_ARM64
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl tar && \
    rm -rf /var/lib/apt/lists/*
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
FROM ${DEBIAN_IMAGE} AS rustup-builder
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
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl build-essential pkg-config && \
    rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    UNAME_ARCH="$(uname -m)"; \
    case "${UNAME_ARCH}" in \
      x86_64) RUSTUP_HOST="x86_64-unknown-linux-gnu" ;; \
      aarch64) RUSTUP_HOST="aarch64-unknown-linux-gnu" ;; \
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
FROM ${DEBIAN_IMAGE} AS cargo-tools-fetcher
ARG CARGO_DENY_VERSION
ARG CARGO_AUDIT_VERSION
ARG CARGO_ZIGBUILD_VERSION
ARG CARGO_NEXTEST_VERSION
ARG CBINDGEN_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl tar gzip xz-utils && \
    rm -rf /var/lib/apt/lists/*
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
        AUDIT_ARCH="x86_64-unknown-linux-gnu"; \
        ZIGBUILD_ARCH="x86_64-unknown-linux-musl"; \
        NEXTEST_ARCH="x86_64-unknown-linux-gnu"; \
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
      /licenses/github /licenses/debian /licenses/npm /licenses/pypi /licenses/zig /licenses/go /licenses/rust /licenses/crates \
      /notices/github /notices/debian /notices/npm && \
    chmod -R a+rX /licenses /notices

# Update the npm bundled in the node base image.
#
# node:22 ships npm 10.9.x, whose *bundled* dependency tree carries HIGH and
# CRITICAL advisories (tar, sigstore, brace-expansion). Those packages are not
# ours -- they live under /usr/local/lib/node_modules/npm/node_modules -- so the
# only ways to clear them are to wait for the base image to refresh its npm, or
# to update npm ourselves. We update.
#
# MAINTENANCE OBLIGATION: this pin overrides whatever npm the base ships, so it
# can silently go BACKWARDS if the base later bundles a newer npm than
# ${NPM_VERSION}. On every node base digest bump, re-verify that this pin is
# still >= the base's bundled npm, and drop this stage entirely once the base
# catches up. See RELEASE_CHECKLIST.md ("Pinned npm override").
ARG NPM_VERSION
RUN npm install -g npm@${NPM_VERSION} && \
    npm cache clean --force && \
    mkdir -p /licenses/npm/npm && \
    cp /usr/local/lib/node_modules/npm/LICENSE /licenses/npm/npm/LICENSE && \
    chmod -R a+rX /licenses/npm

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

ARG UV_VERSION
ARG MATURIN_VERSION
ARG PYTEST_VERSION
ARG RUFF_VERSION
ARG NAPI_RS_CLI_VERSION

USER root

# Install runner baseline packages + build tools for CGO.
# libgnutls30 is security-pinned to the patched bookworm-security build (the
# base image lags the security repo). See manifests/tools.json; availability is
# enforced by validate-apt-pins.sh and presence by validate-pins.sh.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgnutls30=3.7.9-2+deb12u7 \
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
    zip \
    openssh-client \
    build-essential \
    gcc \
    g++ \
    libc6-dev \
    pkg-config \
    python3 \
    python3-pip \
    yamllint && \
    rm -rf /var/lib/apt/lists/*

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
    python3 -m pip install --no-cache-dir uv==${UV_VERSION} maturin==${MATURIN_VERSION} pytest==${PYTEST_VERSION} ruff==${RUFF_VERSION}; \
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
copy_license("ruff", "/licenses/pypi/ruff/LICENSE")
PY

RUN chmod -R a+rX /licenses /notices /opt && \
    chown -R node:node /opt/gopath /opt/cargo /opt/rustup /opt/go /opt/zig

USER node
