# PHONY declarations grouped by responsibility. NOTE: declared as separate
# `.PHONY:` directives rather than one backslash-continuation block because
# checkmake's `phonydeclared` rule does not parse line-continuation `.PHONY:`
# directives correctly (it only sees the first physical line and reports
# every other PHONY target as "should be declared PHONY"). Multiple
# directives accumulate in make per the spec, so this is fully equivalent
# to the previous single block while also being checkmake-clean.
.PHONY: all build-all test-all
.PHONY: build-goneat-tools build-goneat-tools-runner build-goneat-tools-slim build-goneat-tools-runner-glibc
.PHONY: build-goneat-tools-multi build-goneat-tools-runner-multi build-goneat-tools-slim-multi build-goneat-tools-runner-glibc-multi
.PHONY: test-goneat-tools test-goneat-tools-runner test-goneat-tools-slim test-goneat-tools-runner-glibc
.PHONY: build-sbom-tools build-sbom-tools-runner build-sbom-tools-slim build-sbom-tools-runner-glibc
.PHONY: build-sbom-tools-multi build-sbom-tools-runner-multi build-sbom-tools-slim-multi build-sbom-tools-runner-glibc-multi
.PHONY: test-sbom-tools test-sbom-tools-runner test-sbom-tools-slim test-sbom-tools-runner-glibc
.PHONY: build-valkey-server-glibc build-valkey-server-glibc-multi test-valkey-server-glibc
.PHONY: prove prove-goneat prove-sbom prove-runners prove-multi prove-goneat-multi prove-sbom-multi prove-runners-multi
.PHONY: cache-init cache-clear
.PHONY: inventory-goneat-tools-runner inventory-goneat-tools-runner-glibc
.PHONY: clean help bump-major bump-minor bump-patch lint-sh fmt-sh prereqs bootstrap bootstrap-tools size
.PHONY: validate-manifest validate-apk-pins validate-apt-pins validate-pins validate-profiles validate-licenses
.PHONY: lint-workflows lint-dockerfiles
.PHONY: quality precommit prepush pr-final check-clean check-quick
.PHONY: catalog
.PHONY: release-plan release-clean release-download release-notes release-sign release-upload release-digests release-signing-help
.PHONY: release-export-keys release-export-gpg-key release-export-minisign-key
.PHONY: verify-release-key verify-minisign-key verify-release-digests
.PHONY: validate-subsystems validate-subsystem-echo-proxy-fixture validate-subsystem-authentik-idp
.PHONY: test-subsystem-echo-proxy-fixture test-subsystem-authentik-idp

# Fulmen Toolbox - Local Development Makefile
# Supports building/testing goneat-tools, sbom-tools, and application images (valkey, etc.)

REGISTRY := ghcr.io/fulmenhq

# Image families and variants
GONEAT_FAMILY := goneat-tools
# Canonical (v0.3.0+): musl images include libc in name
GONEAT_RUNNER_IMAGE := $(GONEAT_FAMILY)-runner-musl
GONEAT_SLIM_IMAGE := $(GONEAT_FAMILY)-slim-musl
GONEAT_GLIBC_IMAGE := $(GONEAT_FAMILY)-runner-glibc
GONEAT_RUNNER_TAG_LOCAL := $(REGISTRY)/$(GONEAT_RUNNER_IMAGE):local
GONEAT_RUNNER_TAG_LATEST := $(REGISTRY)/$(GONEAT_RUNNER_IMAGE):latest
GONEAT_SLIM_TAG_LOCAL := $(REGISTRY)/$(GONEAT_SLIM_IMAGE):local
GONEAT_SLIM_TAG_LATEST := $(REGISTRY)/$(GONEAT_SLIM_IMAGE):latest
GONEAT_GLIBC_TAG_LOCAL := $(REGISTRY)/$(GONEAT_GLIBC_IMAGE):local
GONEAT_GLIBC_TAG_LATEST := $(REGISTRY)/$(GONEAT_GLIBC_IMAGE):latest

SBOM_FAMILY := sbom-tools
# Canonical (v0.3.0+): musl images include libc in name
SBOM_RUNNER_IMAGE := $(SBOM_FAMILY)-runner-musl
SBOM_SLIM_IMAGE := $(SBOM_FAMILY)-slim-musl
SBOM_GLIBC_IMAGE := $(SBOM_FAMILY)-runner-glibc
SBOM_RUNNER_TAG_LOCAL := $(REGISTRY)/$(SBOM_RUNNER_IMAGE):local
SBOM_RUNNER_TAG_LATEST := $(REGISTRY)/$(SBOM_RUNNER_IMAGE):latest
SBOM_SLIM_TAG_LOCAL := $(REGISTRY)/$(SBOM_SLIM_IMAGE):local
SBOM_SLIM_TAG_LATEST := $(REGISTRY)/$(SBOM_SLIM_IMAGE):latest
SBOM_GLIBC_TAG_LOCAL := $(REGISTRY)/$(SBOM_GLIBC_IMAGE):local
SBOM_GLIBC_TAG_LATEST := $(REGISTRY)/$(SBOM_GLIBC_IMAGE):latest

# Application images (v0.3.0+)
VALKEY_FAMILY := valkey
VALKEY_SERVER_GLIBC_IMAGE := $(VALKEY_FAMILY)-server-glibc
VALKEY_SERVER_GLIBC_TAG_LOCAL := $(REGISTRY)/$(VALKEY_SERVER_GLIBC_IMAGE):local
VALKEY_SERVER_GLIBC_TAG_LATEST := $(REGISTRY)/$(VALKEY_SERVER_GLIBC_IMAGE):latest

VERSION_FILE := VERSION
BUMP_SCRIPT := scripts/bump-version.sh

SHELLCHECK ?= shellcheck
SHFMT ?= shfmt
# Core tools for day-to-day development
PREREQ_CORE ?= docker jq yamlfmt trivy
# Release-only tools (signing workflow)
PREREQ_RELEASE ?= cosign gpg minisign syft
OPTIONAL_CMDS ?= shellcheck shfmt
VALIDATE_MANIFEST ?= scripts/validate-manifest.sh
VALIDATE_PINS ?= scripts/validate-pins.sh
VALIDATE_APK_PINS ?= scripts/validate-apk-pins.sh
VALIDATE_APT_PINS ?= scripts/validate-apt-pins.sh
VALIDATE_PROFILES ?= scripts/validate-profiles.sh
VALIDATE_LICENSES ?= scripts/validate-licenses.sh
VALIDATE_SUBSYSTEMS ?= scripts/validate-subsystems.sh
TEST_SUBSYSTEM_ECHO_PROXY_FIXTURE ?= scripts/test-subsystem-echo-proxy-fixture.sh
TEST_SUBSYSTEM_AUTHENTIK_IDP ?= scripts/test-subsystem-authentik-idp.sh
YAMLFMT ?= yamlfmt
YAMLFMT_PIN ?= v0.21.0
MISSING_ACTION ?= "missing required tooling; install before proceeding"
YAMLLINT ?= yamllint

# Bootstrap tooling (sfetch -> goneat trust chain)
# Note: GONEAT_VERSION is a minimum version; if goneat is already installed, it is used as-is.
GONEAT_VERSION ?= v0.5.9
BINDIR ?= $(HOME)/.local/bin
SFETCH_BIN = $(shell command -v sfetch 2>/dev/null || echo "")
GONEAT_BIN = $(shell command -v goneat 2>/dev/null || echo "")

## Build and test all images
all: build-all test-all

## Build all images (single-arch)
build-all: build-goneat-tools-runner build-goneat-tools-slim build-goneat-tools-runner-glibc build-sbom-tools-runner build-sbom-tools-slim build-sbom-tools-runner-glibc

## Test all images
test-all: test-goneat-tools-runner test-goneat-tools-slim test-goneat-tools-runner-glibc test-sbom-tools-runner test-sbom-tools-slim test-sbom-tools-runner-glibc

# ─────────────────────────────────────────────────────────────────────────────
# Parallel builds with buildx bake (prove targets)
# ─────────────────────────────────────────────────────────────────────────────
# These targets use docker-bake.hcl for parallel builds with shared cache.
# Much faster than sequential `make build-*` for proving all images work.
#
# Usage:
#   make prove              # All images, native arch, parallel
#   make prove-multi        # All images, multi-arch (amd64+arm64), parallel
#   make prove-goneat       # Just goneat images, native arch
#   make prove-goneat-multi # Just goneat images, multi-arch
#   make prove-sbom         # Just sbom images, native arch
#   make prove-runners      # Just runner images (skip slim), native arch
#
# Cache options (faster subsequent builds):
#   make prove CACHE=1      # Use local .buildcache directory
#
# Advanced:
#   make prove TARGET=goneat-runner-musl  # Single target from bake file

BAKE_FILE := docker-bake.hcl
BUILDCACHE_DIR := .buildcache

# Cache flags for buildx bake
ifdef CACHE
BAKE_CACHE_FLAGS := --set *.cache-from=type=local,src=$(BUILDCACHE_DIR) \
                    --set *.cache-to=type=local,dest=$(BUILDCACHE_DIR),mode=max
else
BAKE_CACHE_FLAGS :=
endif

# Multi-arch platform flag
BAKE_MULTI_PLATFORM := --set *.platform=linux/amd64,linux/arm64

## Prove all images build (native arch, parallel via bake)
prove:
ifdef TARGET
	docker buildx bake -f $(BAKE_FILE) $(BAKE_CACHE_FLAGS) $(TARGET)
else
	docker buildx bake -f $(BAKE_FILE) $(BAKE_CACHE_FLAGS)
endif

## Prove all images build (multi-arch: amd64+arm64, parallel via bake)
prove-multi:
ifdef TARGET
	docker buildx bake -f $(BAKE_FILE) $(BAKE_CACHE_FLAGS) $(BAKE_MULTI_PLATFORM) $(TARGET)
else
	docker buildx bake -f $(BAKE_FILE) $(BAKE_CACHE_FLAGS) $(BAKE_MULTI_PLATFORM)
endif

## Prove goneat images (native arch)
prove-goneat:
	docker buildx bake -f $(BAKE_FILE) $(BAKE_CACHE_FLAGS) goneat

## Prove goneat images (multi-arch)
prove-goneat-multi:
	docker buildx bake -f $(BAKE_FILE) $(BAKE_CACHE_FLAGS) $(BAKE_MULTI_PLATFORM) goneat

## Prove sbom images (native arch)
prove-sbom:
	docker buildx bake -f $(BAKE_FILE) $(BAKE_CACHE_FLAGS) sbom

## Prove sbom images (multi-arch)
prove-sbom-multi:
	docker buildx bake -f $(BAKE_FILE) $(BAKE_CACHE_FLAGS) $(BAKE_MULTI_PLATFORM) sbom

## Prove runner images only (skip slim, native arch)
prove-runners:
	docker buildx bake -f $(BAKE_FILE) $(BAKE_CACHE_FLAGS) runners

## Prove runner images only (skip slim, multi-arch)
prove-runners-multi:
	docker buildx bake -f $(BAKE_FILE) $(BAKE_CACHE_FLAGS) $(BAKE_MULTI_PLATFORM) runners

## Initialize local build cache directory
cache-init:
	@mkdir -p $(BUILDCACHE_DIR)
	@echo "Created $(BUILDCACHE_DIR) for buildx cache"

## Clear local build cache
cache-clear:
	@rm -rf $(BUILDCACHE_DIR)
	@echo "Cleared $(BUILDCACHE_DIR)"

# ─────────────────────────────────────────────────────────────────────────────
# goneat-tools targets
# ─────────────────────────────────────────────────────────────────────────────

## Build goneat-tools runner (single-arch)
build-goneat-tools-runner:
	docker build --target runner -t $(GONEAT_RUNNER_TAG_LOCAL) images/$(GONEAT_FAMILY)

## Build goneat-tools runner glibc (single-arch)
build-goneat-tools-runner-glibc:
	docker build --target runner -t $(GONEAT_GLIBC_TAG_LOCAL) images/$(GONEAT_FAMILY)-glibc

## Build goneat-tools slim (single-arch)
build-goneat-tools-slim:
	docker build --target slim -t $(GONEAT_SLIM_TAG_LOCAL) images/$(GONEAT_FAMILY)

## Back-compat alias target (runner)
build-goneat-tools: build-goneat-tools-runner

## Build goneat-tools runner multi-arch (linux/amd64 + linux/arm64)
build-goneat-tools-runner-multi:
	docker buildx create --use || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--target runner \
		-t $(GONEAT_RUNNER_TAG_LOCAL) \
		-t $(GONEAT_RUNNER_TAG_LATEST) \
		--push=false \
		images/$(GONEAT_FAMILY)

## Build goneat-tools runner glibc multi-arch (linux/amd64 + linux/arm64)
build-goneat-tools-runner-glibc-multi:
	docker buildx create --use || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--target runner \
		-t $(GONEAT_GLIBC_TAG_LOCAL) \
		-t $(GONEAT_GLIBC_TAG_LATEST) \
		--push=false \
		images/$(GONEAT_FAMILY)-glibc

## Build goneat-tools slim multi-arch (linux/amd64 + linux/arm64)
build-goneat-tools-slim-multi:
	docker buildx create --use || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--target slim \
		-t $(GONEAT_SLIM_TAG_LOCAL) \
		-t $(GONEAT_SLIM_TAG_LATEST) \
		--push=false \
		images/$(GONEAT_FAMILY)

## Back-compat alias target (runner)
build-goneat-tools-multi: build-goneat-tools-runner-multi

## Test goneat-tools runner
# NOTE: validates runner baseline presence implicitly via common utilities.
# NOTE: cargo-audit and cargo-nextest are skipped on arm64 musl (glibc binaries only).
test-goneat-tools-runner:
	docker run --rm $(GONEAT_RUNNER_TAG_LOCAL) -c "\
		prettier --version && \
		biome --version && \
		yamlfmt --version && \
		yamllint --version && \
		shfmt --version && \
		checkmake --version && \
		actionlint --version && \
		jq --version && \
		yq --version && \
		rg --version && \
		taplo --version && \
		minisign -v >/dev/null 2>&1 && \
		goneat version >/dev/null 2>&1 && \
		sfetch --help >/dev/null 2>&1 && \
		shellsentry --version >/dev/null 2>&1 && \
		syft version >/dev/null 2>&1 && \
		grype version >/dev/null 2>&1 && \
		rustc --version >/dev/null 2>&1 && \
		cargo --version >/dev/null 2>&1 && \
		rustfmt --version >/dev/null 2>&1 && \
		cargo clippy --version >/dev/null 2>&1 && \
		cargo deny --version >/dev/null 2>&1 && \
		([ \$$(uname -m) = 'aarch64' ] || cargo audit --version >/dev/null 2>&1) && \
		cargo-zigbuild --version >/dev/null 2>&1 && \
		([ \$$(uname -m) = 'aarch64' ] || cargo nextest --version >/dev/null 2>&1) && \
		cbindgen --version >/dev/null 2>&1 && \
		go version >/dev/null 2>&1 && \
		zig version >/dev/null 2>&1 && \
		python3 --version >/dev/null 2>&1 && \
		uv --version >/dev/null 2>&1 && \
		maturin --version >/dev/null 2>&1 && \
		pytest --version >/dev/null 2>&1 && \
		command -v napi >/dev/null 2>&1 && \
		bash --version >/dev/null 2>&1 && \
		git --version >/dev/null 2>&1 && \
		curl --version >/dev/null 2>&1 && \
		gcc --version >/dev/null 2>&1 && \
		pkg-config --version >/dev/null 2>&1 && \
		[ -d /licenses ] && [ -d /licenses/alpine ] && [ -d /notices ] && \
		[ -f /licenses/github/jedisct1/minisign/LICENSE ] && \
		[ -f /licenses/github/3leaps/shellsentry/LICENSE ] && \
		[ -f /licenses/go/LICENSE ] && \
		[ -f /licenses/zig/LICENSE ] && \
		[ -f /licenses/rust/LICENSE-APACHE ] && \
		[ -f /licenses/crates/cargo-deny/LICENSE-APACHE ] && \
		echo 'goneat-tools-runner-musl OK!'"

## Test goneat-tools slim
# Ensures tool payload works and runner baseline packages are absent.
test-goneat-tools-slim:
	docker run --rm $(GONEAT_SLIM_TAG_LOCAL) -c "\
		prettier --version && \
		biome --version && \
		yamlfmt --version && \
		! command -v yamllint >/dev/null 2>&1 && \
		shfmt --version && \
		checkmake --version && \
		actionlint --version && \
		jq --version && \
		yq --version && \
		rg --version && \
		taplo --version && \
		minisign -v >/dev/null 2>&1 && \
		goneat version >/dev/null 2>&1 && \
		sfetch --help >/dev/null 2>&1 && \
		! command -v shellsentry >/dev/null 2>&1 && \
		! command -v syft >/dev/null 2>&1 && \
		! command -v grype >/dev/null 2>&1 && \
		! command -v rustc >/dev/null 2>&1 && \
		! command -v cargo >/dev/null 2>&1 && \
		! command -v rustfmt >/dev/null 2>&1 && \
		! command -v cargo-deny >/dev/null 2>&1 && \
		! command -v cargo-audit >/dev/null 2>&1 && \
		! command -v cargo-zigbuild >/dev/null 2>&1 && \
		! command -v cargo-nextest >/dev/null 2>&1 && \
		! command -v cbindgen >/dev/null 2>&1 && \
		! command -v go >/dev/null 2>&1 && \
		! command -v zig >/dev/null 2>&1 && \
		! command -v python3 >/dev/null 2>&1 && \
		! command -v uv >/dev/null 2>&1 && \
		! command -v maturin >/dev/null 2>&1 && \
		! command -v pytest >/dev/null 2>&1 && \
		! command -v napi >/dev/null 2>&1 && \
		! command -v bash >/dev/null 2>&1 && \
		! command -v git >/dev/null 2>&1 && \
		! command -v curl >/dev/null 2>&1 && \
		echo 'goneat-tools-slim-musl OK!'"

## Back-compat alias target (runner)
test-goneat-tools: test-goneat-tools-runner

## Test goneat-tools runner glibc
test-goneat-tools-runner-glibc:
	docker run --rm $(GONEAT_GLIBC_TAG_LOCAL) -c "\
		prettier --version && \
		biome --version && \
		yamlfmt --version && \
		yamllint --version && \
		shfmt --version && \
		checkmake --version && \
		actionlint --version && \
		jq --version && \
		yq --version && \
		rg --version && \
		taplo --version && \
		minisign -v >/dev/null 2>&1 && \
		goneat version >/dev/null 2>&1 && \
		sfetch --help >/dev/null 2>&1 && \
		shellsentry --version >/dev/null 2>&1 && \
		syft version >/dev/null 2>&1 && \
		grype version >/dev/null 2>&1 && \
		rustc --version >/dev/null 2>&1 && \
		cargo --version >/dev/null 2>&1 && \
		rustfmt --version >/dev/null 2>&1 && \
		cargo clippy --version >/dev/null 2>&1 && \
		cargo deny --version >/dev/null 2>&1 && \
		cargo audit --version >/dev/null 2>&1 && \
		cargo-zigbuild --version >/dev/null 2>&1 && \
		cargo nextest --version >/dev/null 2>&1 && \
		cbindgen --version >/dev/null 2>&1 && \
		go version >/dev/null 2>&1 && \
		zig version >/dev/null 2>&1 && \
		python3 --version >/dev/null 2>&1 && \
		uv --version >/dev/null 2>&1 && \
		maturin --version >/dev/null 2>&1 && \
		pytest --version >/dev/null 2>&1 && \
		command -v napi >/dev/null 2>&1 && \
		bash --version >/dev/null 2>&1 && \
		git --version >/dev/null 2>&1 && \
		curl --version >/dev/null 2>&1 && \
		gcc --version >/dev/null 2>&1 && \
		pkg-config --version >/dev/null 2>&1 && \
		[ -d /licenses ] && [ -d /licenses/debian ] && [ -d /notices ] && \
		[ -f /licenses/github/jedisct1/minisign/LICENSE ] && \
		[ -f /licenses/github/3leaps/shellsentry/LICENSE ] && \
		[ -f /licenses/go/LICENSE ] && \
		[ -f /licenses/zig/LICENSE ] && \
		[ -f /licenses/rust/LICENSE-APACHE ] && \
		[ -f /licenses/crates/cargo-deny/LICENSE-APACHE ] && \
		echo 'goneat-tools-runner-glibc OK!'"

## Inventory goneat-tools runner (musl)
inventory-goneat-tools-runner:
	docker run --rm $(GONEAT_RUNNER_TAG_LOCAL) -c "\
		echo 'goneat-tools-runner-musl inventory' && \
		node --version && \
		npm --version && \
		goneat version && \
		sfetch --version && \
		shellsentry --version && \
		syft version && \
		grype version && \
		rustc --version && \
		cargo --version && \
		rustfmt --version && \
		cargo clippy --version && \
		cargo deny --version && \
		cargo audit --version && \
		cargo-zigbuild --version && \
		cargo nextest --version && \
		cbindgen --version && \
		go version && \
		zig version && \
		python3 --version && \
		uv --version && \
		maturin --version && \
		pytest --version && \
		echo napi \$$(napi -h 2>&1 | head -1)"

## Inventory goneat-tools runner (glibc)
inventory-goneat-tools-runner-glibc:
	docker run --rm $(GONEAT_GLIBC_TAG_LOCAL) -c "\
		echo 'goneat-tools-runner-glibc inventory' && \
		node --version && \
		npm --version && \
		goneat version && \
		sfetch --version && \
		shellsentry --version && \
		syft version && \
		grype version && \
		rustc --version && \
		cargo --version && \
		rustfmt --version && \
		cargo clippy --version && \
		cargo deny --version && \
		cargo audit --version && \
		cargo-zigbuild --version && \
		cargo nextest --version && \
		cbindgen --version && \
		go version && \
		zig version && \
		python3 --version && \
		uv --version && \
		maturin --version && \
		pytest --version && \
		echo napi \$$(napi -h 2>&1 | head -1)"

# ─────────────────────────────────────────────────────────────────────────────
# sbom-tools targets
# ─────────────────────────────────────────────────────────────────────────────

## Build sbom-tools runner single-arch
build-sbom-tools-runner:
	docker build --target runner -t $(SBOM_RUNNER_TAG_LOCAL) images/$(SBOM_FAMILY)

## Build sbom-tools runner glibc single-arch
build-sbom-tools-runner-glibc:
	docker build --target runner -t $(SBOM_GLIBC_TAG_LOCAL) images/$(SBOM_FAMILY)-glibc

## Build sbom-tools slim single-arch
build-sbom-tools-slim:
	docker build --target slim -t $(SBOM_SLIM_TAG_LOCAL) images/$(SBOM_FAMILY)

## Back-compat alias target (runner)
build-sbom-tools: build-sbom-tools-runner

## Build sbom-tools runner multi-arch (linux/amd64 + linux/arm64)
build-sbom-tools-runner-multi:
	docker buildx create --use || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--target runner \
		-t $(SBOM_RUNNER_TAG_LOCAL) \
		-t $(SBOM_RUNNER_TAG_LATEST) \
		--push=false \
		images/$(SBOM_FAMILY)

## Build sbom-tools runner glibc multi-arch (linux/amd64 + linux/arm64)
build-sbom-tools-runner-glibc-multi:
	docker buildx create --use || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--target runner \
		-t $(SBOM_GLIBC_TAG_LOCAL) \
		-t $(SBOM_GLIBC_TAG_LATEST) \
		--push=false \
		images/$(SBOM_FAMILY)-glibc

## Build sbom-tools slim multi-arch (linux/amd64 + linux/arm64)
build-sbom-tools-slim-multi:
	docker buildx create --use || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--target slim \
		-t $(SBOM_SLIM_TAG_LOCAL) \
		-t $(SBOM_SLIM_TAG_LATEST) \
		--push=false \
		images/$(SBOM_FAMILY)

## Back-compat alias target (runner)
build-sbom-tools-multi: build-sbom-tools-runner-multi

## Test sbom-tools runner
# NOTE:
# - These tests assume network access.
# - grype and trivy may download databases on first run (can take ~1-2 minutes).
# - trivy also enables secret scanning by default; if CI time becomes an issue, consider
#   using `trivy fs --scanners vuln` (keep as a deliberate policy choice).
test-sbom-tools-runner:
	docker run --rm \
		-v $(CURDIR)/tests/fixtures/sbom:/fixture:ro \
		$(SBOM_RUNNER_TAG_LOCAL) -c "\
		syft version && \
		grype version && \
		trivy version && \
		shellsentry --version >/dev/null 2>&1 && \
		yamllint --version && \
		jq --version && \
		yq --version && \
		git --version && \
		gcc --version >/dev/null 2>&1 && \
		pkg-config --version >/dev/null 2>&1 && \
		syft /fixture -o cyclonedx-json > /tmp/sbom.json && \
		[ -s /tmp/sbom.json ] && \
		grype sbom:/tmp/sbom.json --fail-on critical && \
		trivy fs --exit-code 0 --severity HIGH,CRITICAL /fixture > /tmp/trivy.txt && \
		[ -s /tmp/trivy.txt ] && \
		[ -d /licenses ] && [ -d /licenses/alpine ] && [ -d /notices ] && \
		[ -f /licenses/github/anchore/syft/LICENSE ] && \
		[ -f /licenses/github/anchore/grype/LICENSE ] && \
		[ -f /licenses/github/aquasecurity/trivy/LICENSE ] && \
		[ -f /licenses/github/3leaps/shellsentry/LICENSE ] && \
		echo 'sbom-tools-runner-musl OK!'"

## Test sbom-tools slim
# NOTE:
# - These tests assume network access (trivy DB downloads on first run).
# Ensures tool payload works and runner baseline packages are absent.
test-sbom-tools-slim:
	docker run --rm \
		-v $(CURDIR)/tests/fixtures/sbom:/fixture:ro \
		$(SBOM_SLIM_TAG_LOCAL) -c "\
		syft version && \
		grype version && \
		trivy version && \
		! command -v shellsentry >/dev/null 2>&1 && \
		! command -v yamllint >/dev/null 2>&1 && \
		jq --version && \
		yq --version && \
		! command -v git >/dev/null 2>&1 && \
		! command -v curl >/dev/null 2>&1 && \
		syft /fixture -o cyclonedx-json > /tmp/sbom.json && \
		[ -s /tmp/sbom.json ] && \
		grype sbom:/tmp/sbom.json --fail-on critical && \
		trivy fs --exit-code 0 --severity HIGH,CRITICAL /fixture > /tmp/trivy.txt && \
		[ -s /tmp/trivy.txt ] && \
		[ -d /licenses ] && [ -d /licenses/alpine ] && [ -d /notices ] && \
		[ -f /licenses/github/anchore/syft/LICENSE ] && \
		[ -f /licenses/github/anchore/grype/LICENSE ] && \
		[ -f /licenses/github/aquasecurity/trivy/LICENSE ] && \
		echo 'sbom-tools-slim-musl OK!'"

## Back-compat alias target (runner)
test-sbom-tools: test-sbom-tools-runner

## Test sbom-tools runner glibc
# NOTE:
# - These tests assume network access.
# - grype and trivy may download databases on first run (can take ~1-2 minutes).
test-sbom-tools-runner-glibc:
	docker run --rm \
		-v $(CURDIR)/tests/fixtures/sbom:/fixture:ro \
		$(SBOM_GLIBC_TAG_LOCAL) -c "\
		syft version && \
		grype version && \
		trivy version && \
		shellsentry --version >/dev/null 2>&1 && \
		yamllint --version && \
		jq --version && \
		yq --version && \
		git --version && \
		gcc --version >/dev/null 2>&1 && \
		pkg-config --version >/dev/null 2>&1 && \
		syft /fixture -o cyclonedx-json > /tmp/sbom.json && \
		[ -s /tmp/sbom.json ] && \
		grype sbom:/tmp/sbom.json --fail-on critical && \
		trivy fs --exit-code 0 --severity HIGH,CRITICAL /fixture > /tmp/trivy.txt && \
		[ -s /tmp/trivy.txt ] && \
		[ -d /licenses ] && [ -d /licenses/debian ] && [ -d /notices ] && \
		[ -f /licenses/github/anchore/syft/LICENSE ] && \
		[ -f /licenses/github/anchore/grype/LICENSE ] && \
		[ -f /licenses/github/aquasecurity/trivy/LICENSE ] && \
		[ -f /licenses/github/3leaps/shellsentry/LICENSE ] && \
		echo 'sbom-tools-runner-glibc OK!'"

# ─────────────────────────────────────────────────────────────────────────────
# Application images (v0.3.0+)
# ─────────────────────────────────────────────────────────────────────────────

## Build valkey-server-glibc (single-arch)
build-valkey-server-glibc:
	docker build --target server -t $(VALKEY_SERVER_GLIBC_TAG_LOCAL) images/$(VALKEY_FAMILY)

## Build valkey-server-glibc multi-arch (linux/amd64 + linux/arm64)
build-valkey-server-glibc-multi:
	docker buildx create --use || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--target server \
		-t $(VALKEY_SERVER_GLIBC_TAG_LOCAL) \
		-t $(VALKEY_SERVER_GLIBC_TAG_LATEST) \
		--push=false \
		images/$(VALKEY_FAMILY)

## Test valkey-server-glibc
# Uses trap to ensure container cleanup on failure
test-valkey-server-glibc:
	@echo "Testing valkey-server-glibc..."
	@CONTAINER_ID=$$(docker run --rm -d $(VALKEY_SERVER_GLIBC_TAG_LOCAL)) && \
	trap "docker stop $$CONTAINER_ID >/dev/null 2>&1 || true" EXIT && \
	sleep 2 && \
	docker exec $$CONTAINER_ID valkey-cli ping | grep -q PONG && \
	docker exec $$CONTAINER_ID sh -c '[ -d /licenses ] && [ -f /licenses/github/valkey-io/valkey/LICENSE ]' && \
	docker exec $$CONTAINER_ID sh -c '[ -d /notices ]' && \
	docker exec $$CONTAINER_ID sh -c 'id | grep -q valkey' && \
	echo 'valkey-server-glibc OK!'

# ─────────────────────────────────────────────────────────────────────────────

## Clean up local images
clean:
	docker rmi \
		$(GONEAT_RUNNER_TAG_LOCAL) $(GONEAT_RUNNER_TAG_LATEST) \
		$(GONEAT_SLIM_TAG_LOCAL) $(GONEAT_SLIM_TAG_LATEST) \
		$(GONEAT_GLIBC_TAG_LOCAL) $(GONEAT_GLIBC_TAG_LATEST) \
		$(SBOM_RUNNER_TAG_LOCAL) $(SBOM_RUNNER_TAG_LATEST) \
		$(SBOM_SLIM_TAG_LOCAL) $(SBOM_SLIM_TAG_LATEST) \
		$(SBOM_GLIBC_TAG_LOCAL) $(SBOM_GLIBC_TAG_LATEST) \
		$(VALKEY_SERVER_GLIBC_TAG_LOCAL) $(VALKEY_SERVER_GLIBC_TAG_LATEST) || true

## Show Docker image sizes
size:
	@docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep -E "(fulmenhq|REPOSITORY)" || true

## Bump version (semver)
bump-major:
	@$(BUMP_SCRIPT) major

bump-minor:
	@$(BUMP_SCRIPT) minor

bump-patch:
	@$(BUMP_SCRIPT) patch

## Shell script hygiene (optional; requires shfmt/shellcheck)
lint-sh:
	@command -v $(SHELLCHECK) >/dev/null 2>&1 || { echo "shellcheck not found"; exit 1; }
	@$(SHELLCHECK) scripts/*.sh

fmt-sh:
	@command -v $(SHFMT) >/dev/null 2>&1 || { echo "shfmt not found"; exit 1; }
	@$(SHFMT) -w scripts/*.sh

## Validate tool manifest against schema
validate-manifest:
	@$(VALIDATE_MANIFEST)

## Validate pinned versions in Dockerfiles against manifests/tools.json
validate-pins:
	@$(VALIDATE_PINS)

## Validate APK package pins are available in upstream Alpine repos (requires Docker)
validate-apk-pins:
	@$(VALIDATE_APK_PINS)

## Validate APT security pins are available in upstream Debian repos (requires Docker)
validate-apt-pins:
	@$(VALIDATE_APT_PINS)

## Validate Dockerfiles conform to baseline profiles
validate-profiles:
	@$(VALIDATE_PROFILES)

## Validate curated licenses/notices exist in built images
validate-licenses:
	@$(VALIDATE_LICENSES)

## Validate subsystem manifests + compose config
validate-subsystems:
	@$(VALIDATE_SUBSYSTEMS)

validate-subsystem-echo-proxy-fixture:
	@$(VALIDATE_SUBSYSTEMS) echo-proxy-fixture

validate-subsystem-authentik-idp:
	@$(VALIDATE_SUBSYSTEMS) authentik-idp

## Smoke test: evaluation-scale subsystem
# Requires a local Docker daemon.
test-subsystem-echo-proxy-fixture:
	@$(TEST_SUBSYSTEM_ECHO_PROXY_FIXTURE)

test-subsystem-authentik-idp:
	@$(TEST_SUBSYSTEM_AUTHENTIK_IDP)

## Generate local image catalog from manifests (gitignored)
# Usage:
#   make catalog
#   make catalog IMAGE=goneat-tools-runner-musl
catalog:
	@mkdir -p dist/catalog
	@set -eu; \
	if [ -n "$(IMAGE)" ]; then \
		out="dist/catalog/$(IMAGE).md"; \
		scripts/catalog.sh --image "$(IMAGE)" > "$$out"; \
		test -s "$$out"; \
		echo "Wrote $$out"; \
	else \
		out="dist/catalog/catalog.md"; \
		scripts/catalog.sh > "$$out"; \
		test -s "$$out"; \
		echo "Wrote $$out"; \
	fi

## Lint GitHub workflows with yamlfmt
lint-workflows:
	@test -d .github/workflows || { echo ".github/workflows not found"; exit 0; }
	@command -v $(YAMLFMT) >/dev/null 2>&1 || { echo "yamlfmt not found"; exit 1; }
	@$(YAMLFMT) -lint .github/workflows
	@if command -v $(YAMLLINT) >/dev/null 2>&1; then \
		echo "yamllint: running"; \
		$(YAMLLINT) .github/workflows; \
	else \
		echo "yamllint not found (skip)"; \
	fi
	@if command -v actionlint >/dev/null 2>&1; then \
		echo "actionlint: running"; \
		actionlint; \
	else \
		echo "actionlint not found (skip)"; \
	fi

## Validate Dockerfiles with trivy config scanning (best practices + misconfigs)
lint-dockerfiles:
	@if command -v trivy >/dev/null 2>&1; then \
		echo "Validating Dockerfiles with trivy config scan..."; \
		for df in images/*/Dockerfile; do \
			echo "  scanning $$df"; \
			trivy config --severity HIGH,CRITICAL --exit-code 1 "$$df" || exit 1; \
		done; \
		echo "All Dockerfiles passed trivy scan."; \
	else \
		echo "trivy not found. Install: brew install trivy"; \
		echo "Skipping Dockerfile lint."; \
	fi

## Quality bundle: manifest validation + profile validation + workflow lint + dockerfile lint
quality: validate-manifest validate-pins validate-apk-pins validate-apt-pins validate-profiles lint-workflows lint-dockerfiles lint-sh

## Precommit bundle: quality checks
precommit:
	@$(MAKE) quality

## Quick validation (no Docker required)
check-quick:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Quick validation (no Docker required)..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@$(MAKE) validate-pins
	@$(MAKE) lint-workflows
	@$(MAKE) lint-dockerfiles
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "✅ Quick validation passed."
	@echo "   For full checks (requires Docker): make prepush"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

## Check for uncommitted/unstaged changes (fails if dirty)
check-clean:
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "ERROR: Working tree is dirty. Commit or stash changes before prepush."; \
		git status --short; \
		exit 1; \
	fi
	@echo "Working tree is clean."

## Prepush bundle: check clean + quality + build + test ALL images (requires docker daemon)
prepush:
	@$(MAKE) check-clean
	@$(MAKE) quality
	@$(MAKE) build-all
	@$(MAKE) test-all
	@echo "Prepush checks passed. Safe to push."

## Strict local gate: auto-format then assess format/lint/security (fail-on medium).
## Mirrors what we expect CI to enforce so maintainers can catch drift before pushing.
pr-final:
	@command -v goneat >/dev/null 2>&1 || { echo "goneat not found; install via 'make bootstrap-tools' or see docs/user-guide/preflight.md"; exit 1; }
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Running goneat format (auto-fix)..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@goneat format
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Running goneat assess (format + lint + security, fail-on medium)..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@goneat assess --check --categories format,lint,security --fail-on medium
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "✅ pr-final clean. Safe to commit + push."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

## Release plan helper (prints steps, does not push)
release-plan:
	@scripts/release.sh

# ─────────────────────────────────────────────────────────────────────────────
# Manual signing workflow targets
# ─────────────────────────────────────────────────────────────────────────────
FULMEN_TOOLBOX_RELEASE_TAG ?= v$(shell cat VERSION 2>/dev/null || echo "0.0.0")
DIST_RELEASE ?= dist/release
GPG_KEY_FILE ?= $(DIST_RELEASE)/fulmen-toolbox-release-signing-key.asc
MINISIGN_PUB ?= $(DIST_RELEASE)/fulmenhq-release-signing.pub

## Clean release artifacts directory (run before release-download)
release-clean:
	@echo "🧹 Cleaning $(DIST_RELEASE)..."
	@rm -rf $(DIST_RELEASE)
	@mkdir -p $(DIST_RELEASE)
	@echo "✅ $(DIST_RELEASE) is clean"

## Download release artifacts for manual signing (FULMEN_TOOLBOX_RELEASE_TAG=vX.Y.Z)
release-download:
	@scripts/release-download.sh $(FULMEN_TOOLBOX_RELEASE_TAG) $(DIST_RELEASE)

## Stage release notes into dist/ for upload (FULMEN_TOOLBOX_RELEASE_TAG=vX.Y.Z)
release-notes:
	@SRC="docs/releases/$(FULMEN_TOOLBOX_RELEASE_TAG).md"; \
	DEST="$(DIST_RELEASE)/release-notes-$(FULMEN_TOOLBOX_RELEASE_TAG).md"; \
	if [ ! -f "$$SRC" ]; then \
	  echo "⚠️  Release notes not found: $$SRC"; \
	  echo "   Skip ok for now; create it for next release."; \
	  echo "   To require notes: FULMEN_TOOLBOX_RELEASE_NOTES_REQUIRED=1 make release-notes FULMEN_TOOLBOX_RELEASE_TAG=$(FULMEN_TOOLBOX_RELEASE_TAG)"; \
	  if [ "$$FULMEN_TOOLBOX_RELEASE_NOTES_REQUIRED" = "1" ]; then exit 1; fi; \
	  exit 0; \
	fi; \
	mkdir -p "$(DIST_RELEASE)"; \
	cp "$$SRC" "$$DEST"; \
	chmod 0644 "$$DEST"; \
	echo "✅ Staged release notes: $$DEST"

## Get image digests for manual cosign signing (FULMEN_TOOLBOX_RELEASE_TAG=vX.Y.Z)
#
# Images can be overridden via FULMEN_TOOLBOX_IMAGES env var (space-delimited). Defaults to manifest list.
release-digests:
	@echo "Image digests for $(FULMEN_TOOLBOX_RELEASE_TAG):"
	@echo ""
	@IMAGES="$${FULMEN_TOOLBOX_IMAGES:-$$(bash scripts/list-images.sh --format space)}"; \
	for image in $$IMAGES; do \
	  DIGEST=$$(docker manifest inspect ghcr.io/fulmenhq/$$image:$(FULMEN_TOOLBOX_RELEASE_TAG) -v 2>/dev/null | \
	    jq -r 'if type == "array" then .[0].Descriptor.digest else .config.digest end' 2>/dev/null) || true; \
	  if [ -n "$$DIGEST" ] && [ "$$DIGEST" != "null" ]; then \
	    echo "$$image: $$DIGEST"; \
	    echo "  cosign sign ghcr.io/fulmenhq/$$image@$$DIGEST"; \
	  else \
	    echo "$$image: (waiting for image push or auth required)"; \
	  fi; \
	done

## Verify all expected images exist for a release tag
# Fails if any image digest cannot be resolved.
verify-release-digests:
	@IMAGES="$${FULMEN_TOOLBOX_IMAGES:-$$(bash scripts/list-images.sh --format space)}"; \
	missing=0; \
	echo "Verifying image digests for $(FULMEN_TOOLBOX_RELEASE_TAG)..."; \
	for image in $$IMAGES; do \
	  DIGEST=$$(docker manifest inspect ghcr.io/fulmenhq/$$image:$(FULMEN_TOOLBOX_RELEASE_TAG) -v 2>/dev/null | \
	    jq -r 'if type == "array" then .[0].Descriptor.digest else .config.digest end' 2>/dev/null) || true; \
	  if [ -n "$$DIGEST" ] && [ "$$DIGEST" != "null" ]; then \
	    echo "✅ $$image: $$DIGEST"; \
	  else \
	    echo "❌ $$image: missing tag $(FULMEN_TOOLBOX_RELEASE_TAG) or auth required" >&2; \
	    missing=1; \
	  fi; \
	done; \
	if [ $$missing -ne 0 ]; then \
	  echo "" >&2; \
	  echo "Release digest verification failed." >&2; \
	  exit 1; \
	fi; \
	echo "✅ All expected release image digests resolved."
## Perform interactive signing for downloaded release (FULMEN_TOOLBOX_RELEASE_TAG=vX.Y.Z)
release-sign:
	@scripts/release-sign.sh $(FULMEN_TOOLBOX_RELEASE_TAG) $(DIST_RELEASE)

## Export GPG public key for release (requires FULMEN_TOOLBOX_PGP_KEY_ID env var)
release-export-gpg-key:
	@if [ -z "$$FULMEN_TOOLBOX_PGP_KEY_ID" ]; then \
	  echo "❌ FULMEN_TOOLBOX_PGP_KEY_ID env var not set"; \
	  echo "   Set with: export FULMEN_TOOLBOX_PGP_KEY_ID='<your-key-id>!'"; \
	  exit 1; \
	fi
	@mkdir -p $(DIST_RELEASE)
	@echo "🔑 Exporting GPG public key ($$FULMEN_TOOLBOX_PGP_KEY_ID) to $(GPG_KEY_FILE)..."
	@if [ -n "$$FULMEN_TOOLBOX_GPG_HOMEDIR" ]; then \
	  env GNUPGHOME="$$FULMEN_TOOLBOX_GPG_HOMEDIR" gpg --armor --export "$$FULMEN_TOOLBOX_PGP_KEY_ID" > $(GPG_KEY_FILE); \
	else \
	  gpg --armor --export "$$FULMEN_TOOLBOX_PGP_KEY_ID" > $(GPG_KEY_FILE); \
	fi
	@echo "✅ GPG public key exported"

## Export minisign public key for release (requires FULMEN_TOOLBOX_MINISIGN_KEY env var)
release-export-minisign-key:
	@if [ -z "$$FULMEN_TOOLBOX_MINISIGN_KEY" ]; then \
	  echo "❌ FULMEN_TOOLBOX_MINISIGN_KEY env var not set"; \
	  echo "   Set with: export FULMEN_TOOLBOX_MINISIGN_KEY=\"\$$HOME/.minisign/minisign.key\""; \
	  exit 1; \
	fi
	@MINISIGN_PUB_SRC="$${FULMEN_TOOLBOX_MINISIGN_KEY%.key}.pub"; \
	if [ ! -f "$$MINISIGN_PUB_SRC" ]; then \
	  echo "❌ Minisign public key not found: $$MINISIGN_PUB_SRC"; \
	  exit 1; \
	fi; \
	mkdir -p $(DIST_RELEASE); \
	echo "🔑 Copying minisign public key to $(MINISIGN_PUB)..."; \
	cp "$$MINISIGN_PUB_SRC" $(MINISIGN_PUB); \
	chmod 0644 $(MINISIGN_PUB); \
	echo "✅ Minisign public key copied"

## Export both public keys for release
release-export-keys: release-export-gpg-key release-export-minisign-key

## Verify GPG public key is safe to upload (no private key material)
verify-release-key: release-export-gpg-key
	@scripts/verify-public-key.sh $(GPG_KEY_FILE)

## Verify minisign public key exists (exported/copied)
verify-minisign-key: release-export-minisign-key
	@test -f $(MINISIGN_PUB) || { echo "❌ minisign public key missing: $(MINISIGN_PUB)"; exit 1; }
	@echo "✅ minisign public key present: $(MINISIGN_PUB)"

## Upload signed artifacts to GitHub Release (FULMEN_TOOLBOX_RELEASE_TAG=vX.Y.Z)
release-upload: verify-release-key verify-minisign-key
	@scripts/release-upload.sh $(FULMEN_TOOLBOX_RELEASE_TAG) $(DIST_RELEASE)

## Show manual signing workflow steps
release-signing-help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Manual Signing Workflow for fulmen-toolbox"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "1. AUTOMATED (run via make):"
	@echo "   FULMEN_TOOLBOX_RELEASE_TAG=v0.1.2 make release-download"
	@echo "   FULMEN_TOOLBOX_RELEASE_TAG=v0.1.2 make release-digests"
	@echo ""
	@echo "2. INTERACTIVE (run via make - still requires passphrase/browser):"
	@echo "   export FULMEN_TOOLBOX_PGP_KEY_ID='<your-key-id>!'"
	@echo "   export FULMEN_TOOLBOX_GPG_HOMEDIR=\"\$$HOME/.gnupg\"  # optional (multiple keyrings)"
	@echo "   export FULMEN_TOOLBOX_MINISIGN_KEY=\"\$$HOME/.minisign/minisign.key\""
	@echo "   FULMEN_TOOLBOX_RELEASE_TAG=v0.1.2 make release-sign"
	@echo ""
	@echo "   # Optional skips (debugging / partial runs):"
	@echo "   FULMEN_TOOLBOX_COSIGN=0 FULMEN_TOOLBOX_RELEASE_TAG=v0.1.2 make release-sign"
	@echo "   FULMEN_TOOLBOX_GPG=0 FULMEN_TOOLBOX_RELEASE_TAG=v0.1.2 make release-sign"
	@echo "   FULMEN_TOOLBOX_MINISIGN=0 FULMEN_TOOLBOX_RELEASE_TAG=v0.1.2 make release-sign"
	@echo "   # (equivalents: FULMEN_TOOLBOX_SKIP_COSIGN=1, FULMEN_TOOLBOX_SKIP_GPG=1, FULMEN_TOOLBOX_SKIP_MINISIGN=1)"
	@echo ""
	@echo "3. AUTOMATED (run via make):"
	@echo "   make verify-release-key"
	@echo "   FULMEN_TOOLBOX_RELEASE_TAG=v0.1.2 make release-upload"
	@echo ""

## Bootstrap repo tooling (trust-anchor: sfetch -> goneat -> doctor tools)
# Installs foundation tools from .goneat/tools.yaml (jq, yamlfmt, trivy).
# Checks container-dev scope (docker, colima) as advisory only (not installed).
bootstrap:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Bootstrap: sfetch -> goneat -> doctor tools"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@if [ -z "$(SFETCH_BIN)" ]; then \
		echo "❌ sfetch not found (required trust anchor)"; \
		echo ""; \
		echo "Install sfetch with:"; \
		echo "  curl -sSfL https://github.com/3leaps/sfetch/releases/latest/download/install-sfetch.sh | bash"; \
		echo ""; \
		exit 1; \
	else \
		echo "✅ sfetch found: $$($(SFETCH_BIN) --version 2>&1 | head -n1)"; \
		echo "→ sfetch self-verify (trust anchor):"; \
		$(SFETCH_BIN) --self-verify; \
	fi
	@mkdir -p "$(BINDIR)"; \
	if [ -x "$(BINDIR)/goneat" ] && "$(BINDIR)/goneat" --version 2>/dev/null | grep -q "$(GONEAT_VERSION)"; then \
		echo "→ goneat $(GONEAT_VERSION) already available at $(BINDIR)/goneat"; \
	else \
		echo "→ Installing goneat $(GONEAT_VERSION) to $(BINDIR) via sfetch..."; \
		$(SFETCH_BIN) --repo fulmenhq/goneat --tag $(GONEAT_VERSION) --dest-dir "$(BINDIR)"; \
	fi
	@echo "→ Installing foundation tools via goneat doctor..."
	@$(GONEAT_BIN) doctor tools --config .goneat/tools.yaml --scope foundation --install --yes --no-cooling
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Checking container runtime (advisory - not auto-installed)..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@$(GONEAT_BIN) doctor tools --config .goneat/tools.yaml --scope container-dev || true
	@echo ""
	@echo "✅ Bootstrap complete. Ensure $(BINDIR) is on PATH."
	@echo "   Note: Docker/Colima must be installed manually."

## Check required tooling is installed (advisory; tiered: core vs release)
# Quick verification without installation. For full setup, use 'make bootstrap'.
prereqs:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Checking tooling (see CONTRIBUTING.md for full setup)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@core_missing=0; \
	echo ""; \
	echo "Core tools (day-to-day development):"; \
	for cmd in $(PREREQ_CORE); do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo "✅ $$cmd: ok"; \
		else \
			if [ "$$cmd" = "docker" ]; then \
				echo "❌ $$cmd: MISSING"; \
				echo "   Install via: brew install colima docker && colima start"; \
			elif [ "$$cmd" = "yamlfmt" ]; then \
				echo "❌ $$cmd: MISSING"; \
				echo "   Install via: go install github.com/google/yamlfmt/cmd/yamlfmt@$(YAMLFMT_PIN)"; \
			elif [ "$$cmd" = "trivy" ]; then \
				echo "❌ $$cmd: MISSING"; \
				echo "   Install via: brew install trivy"; \
			elif [ "$$cmd" = "jq" ]; then \
				echo "❌ $$cmd: MISSING"; \
				echo "   Install via: brew install jq"; \
			else \
				echo "❌ $$cmd: MISSING"; \
			fi; \
			core_missing=1; \
		fi; \
	done; \
	echo ""; \
	echo "Docker daemon status:"; \
	docker_running=0; \
	if command -v docker >/dev/null 2>&1; then \
		if docker info >/dev/null 2>&1; then \
			echo "✅ docker daemon: running"; \
			docker_running=1; \
		else \
			echo "⚠️  docker daemon: NOT RUNNING"; \
			echo "   If using Colima: colima start (or: brew services start colima)"; \
			echo "   If using Docker Desktop: open the Docker Desktop app"; \
			echo "   Required for: make build-*, test-*, quality, prepush"; \
			echo "   Not required for: make check-quick, validate-pins, lint-*"; \
		fi; \
	fi; \
	if [ $$docker_running -eq 1 ]; then \
		if docker buildx version >/dev/null 2>&1; then \
			echo "✅ docker buildx: ok"; \
		else \
			echo "❌ docker buildx: MISSING"; \
			echo "   Install via: brew install docker-buildx"; \
			core_missing=1; \
		fi; \
	else \
		echo "⬚  docker buildx: skipped (requires running daemon)"; \
	fi; \
	echo ""; \
	echo "Release tools (signing workflow only):"; \
	release_missing=0; \
	for cmd in $(PREREQ_RELEASE); do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo "✅ $$cmd: ok"; \
		else \
			if [ "$$cmd" = "cosign" ]; then \
				echo "⬚  $$cmd: not installed"; \
				echo "   Install via: brew install cosign"; \
			elif [ "$$cmd" = "gpg" ]; then \
				echo "⬚  $$cmd: not installed"; \
				echo "   Install via: brew install gnupg"; \
			elif [ "$$cmd" = "minisign" ]; then \
				echo "⬚  $$cmd: not installed"; \
				echo "   Install via: brew install minisign"; \
			elif [ "$$cmd" = "syft" ]; then \
				echo "⬚  $$cmd: not installed"; \
				echo "   Install via: brew install syft"; \
			else \
				echo "⬚  $$cmd: not installed"; \
			fi; \
			release_missing=1; \
		fi; \
	done; \
	echo ""; \
	echo "Optional tools:"; \
	for cmd in $(OPTIONAL_CMDS); do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo "✅ $$cmd: ok"; \
		else \
			if [ "$$cmd" = "shellcheck" ]; then \
				echo "⬚  $$cmd: not installed (GPL - sidecar pattern)"; \
			elif [ "$$cmd" = "shfmt" ]; then \
				echo "⬚  $$cmd: not installed"; \
				echo "   Install via: go install mvdan.cc/sh/v3/cmd/shfmt@latest"; \
			else \
				echo "⬚  $$cmd: not installed"; \
			fi; \
		fi; \
	done; \
	echo ""; \
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
	if [ $$core_missing -ne 0 ]; then \
		echo "❌ Core tools missing. Install above to proceed."; \
		echo "   Quick start: brew install colima docker docker-buildx jq trivy"; \
		echo "   Then: go install github.com/google/yamlfmt/cmd/yamlfmt@$(YAMLFMT_PIN)"; \
	elif [ $$docker_running -eq 0 ]; then \
		echo "⚠️  Core tools OK, but Docker daemon not running."; \
		echo "   Start now: colima start"; \
		echo "   Auto-start: brew services start colima"; \
		echo "   Without Docker: make check-quick (limited checks)"; \
	elif [ $$release_missing -ne 0 ]; then \
		echo "✅ Ready for development! (release tools not installed)"; \
		echo "   For releases: brew install cosign gnupg minisign syft"; \
	else \
		echo "✅ All tools installed. Ready for development and releases!"; \
	fi; \
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
	exit $$core_missing

## Help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

## Usage Examples:
# make build-goneat-tools test-goneat-tools
# make build-goneat-tools-multi
# make size
# make clean
