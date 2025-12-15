.PHONY: all build-all test-all \
	build-goneat-tools build-goneat-tools-runner build-goneat-tools-slim \
	build-goneat-tools-multi build-goneat-tools-runner-multi build-goneat-tools-slim-multi \
	test-goneat-tools test-goneat-tools-runner test-goneat-tools-slim \
	build-sbom-tools build-sbom-tools-runner build-sbom-tools-slim \
	build-sbom-tools-multi build-sbom-tools-runner-multi build-sbom-tools-slim-multi \
	test-sbom-tools test-sbom-tools-runner test-sbom-tools-slim \
	clean help bump-major bump-minor bump-patch lint-sh fmt-sh release-plan prereqs bootstrap \
	validate-manifest lint-workflows lint-dockerfiles quality precommit prepush check-clean check-quick \
	release-download release-notes release-sign release-upload verify-release-key release-digests

# Fulmen Toolbox - Local Development Makefile
# Supports building/testing goneat-tools and sbom-tools

REGISTRY := ghcr.io/fulmenhq

# Image families and variants
GONEAT_FAMILY := goneat-tools
GONEAT_RUNNER_IMAGE := $(GONEAT_FAMILY)-runner
GONEAT_SLIM_IMAGE := $(GONEAT_FAMILY)-slim
GONEAT_RUNNER_TAG_LOCAL := $(REGISTRY)/$(GONEAT_RUNNER_IMAGE):local
GONEAT_RUNNER_TAG_LATEST := $(REGISTRY)/$(GONEAT_RUNNER_IMAGE):latest
GONEAT_SLIM_TAG_LOCAL := $(REGISTRY)/$(GONEAT_SLIM_IMAGE):local
GONEAT_SLIM_TAG_LATEST := $(REGISTRY)/$(GONEAT_SLIM_IMAGE):latest

SBOM_FAMILY := sbom-tools
SBOM_RUNNER_IMAGE := $(SBOM_FAMILY)-runner
SBOM_SLIM_IMAGE := $(SBOM_FAMILY)-slim
SBOM_RUNNER_TAG_LOCAL := $(REGISTRY)/$(SBOM_RUNNER_IMAGE):local
SBOM_RUNNER_TAG_LATEST := $(REGISTRY)/$(SBOM_RUNNER_IMAGE):latest
SBOM_SLIM_TAG_LOCAL := $(REGISTRY)/$(SBOM_SLIM_IMAGE):local
SBOM_SLIM_TAG_LATEST := $(REGISTRY)/$(SBOM_SLIM_IMAGE):latest
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
VALIDATE_PROFILES ?= scripts/validate-profiles.sh
VALIDATE_LICENSES ?= scripts/validate-licenses.sh
YAMLFMT ?= yamlfmt
YAMLFMT_PIN ?= v0.20.0
MISSING_ACTION ?= "missing required tooling; install before proceeding"
YAMLLINT ?= yamllint

## Build and test all images
all: build-all test-all

## Build all images (single-arch)
build-all: build-goneat-tools-runner build-goneat-tools-slim build-sbom-tools-runner build-sbom-tools-slim

## Test all images
test-all: test-goneat-tools-runner test-goneat-tools-slim test-sbom-tools-runner test-sbom-tools-slim

# ─────────────────────────────────────────────────────────────────────────────
# goneat-tools targets
# ─────────────────────────────────────────────────────────────────────────────

## Build goneat-tools runner (single-arch)
build-goneat-tools-runner:
	docker build --target runner -t $(GONEAT_RUNNER_TAG_LOCAL) images/$(GONEAT_FAMILY)

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
test-goneat-tools-runner:
	docker run --rm $(GONEAT_RUNNER_TAG_LOCAL) -c "\
		prettier --version && \
		biome --version && \
		yamlfmt --version && \
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
		bash --version >/dev/null 2>&1 && \
		git --version >/dev/null 2>&1 && \
		curl --version >/dev/null 2>&1 && \
		[ -d /licenses ] && [ -d /licenses/alpine ] && [ -d /notices ] && \
		[ -f /licenses/github/jedisct1/minisign/LICENSE ] && \
		echo 'goneat-tools-runner OK!'"

## Test goneat-tools slim
# Ensures tool payload works and runner baseline packages are absent.
test-goneat-tools-slim:
	docker run --rm $(GONEAT_SLIM_TAG_LOCAL) -c "\
		prettier --version && \
		biome --version && \
		yamlfmt --version && \
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
		! command -v bash >/dev/null 2>&1 && \
		! command -v git >/dev/null 2>&1 && \
		! command -v curl >/dev/null 2>&1 && \
		echo 'goneat-tools-slim OK!'"

## Back-compat alias target (runner)
test-goneat-tools: test-goneat-tools-runner

# ─────────────────────────────────────────────────────────────────────────────
# sbom-tools targets
# ─────────────────────────────────────────────────────────────────────────────

## Build sbom-tools runner single-arch
build-sbom-tools-runner:
	docker build --target runner -t $(SBOM_RUNNER_TAG_LOCAL) images/$(SBOM_FAMILY)

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
		jq --version && \
		yq --version && \
		git --version && \
		syft /fixture -o cyclonedx-json > /tmp/sbom.json && \
		[ -s /tmp/sbom.json ] && \
		grype sbom:/tmp/sbom.json --fail-on critical && \
		trivy fs --exit-code 0 --severity HIGH,CRITICAL /fixture > /tmp/trivy.txt && \
		[ -s /tmp/trivy.txt ] && \
		[ -d /licenses ] && [ -d /licenses/alpine ] && [ -d /notices ] && \
		[ -f /licenses/github/anchore/syft/LICENSE ] && \
		[ -f /licenses/github/anchore/grype/LICENSE ] && \
		[ -f /licenses/github/aquasecurity/trivy/LICENSE ] && \
		echo 'sbom-tools-runner OK!'"

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
		echo 'sbom-tools-slim OK!'"

## Back-compat alias target (runner)
test-sbom-tools: test-sbom-tools-runner

# ─────────────────────────────────────────────────────────────────────────────

## Clean up local images
clean:
	docker rmi \
		$(GONEAT_RUNNER_TAG_LOCAL) $(GONEAT_RUNNER_TAG_LATEST) \
		$(GONEAT_SLIM_TAG_LOCAL) $(GONEAT_SLIM_TAG_LATEST) \
		$(SBOM_RUNNER_TAG_LOCAL) $(SBOM_RUNNER_TAG_LATEST) \
		$(SBOM_SLIM_TAG_LOCAL) $(SBOM_SLIM_TAG_LATEST) || true

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

## Validate Dockerfiles conform to baseline profiles
validate-profiles:
	@$(VALIDATE_PROFILES)

## Validate curated licenses/notices exist in built images
validate-licenses:
	@$(VALIDATE_LICENSES)

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
quality: validate-manifest validate-pins validate-profiles lint-workflows lint-dockerfiles

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

## Release plan helper (prints steps, does not push)
release-plan:
	@scripts/release.sh

# ─────────────────────────────────────────────────────────────────────────────
# Manual signing workflow targets
# ─────────────────────────────────────────────────────────────────────────────
RELEASE_TAG ?= $(shell cat VERSION 2>/dev/null || echo "v0.0.0")
DIST_RELEASE ?= dist/release
GPG_KEY_FILE ?= $(DIST_RELEASE)/fulmen-toolbox-release-signing-key.asc
MINISIGN_PUB ?= $(DIST_RELEASE)/fulmenhq-release-signing.pub

## Clean release artifacts directory (run before release-download)
release-clean:
	@echo "🧹 Cleaning $(DIST_RELEASE)..."
	@rm -rf $(DIST_RELEASE)
	@mkdir -p $(DIST_RELEASE)
	@echo "✅ $(DIST_RELEASE) is clean"

## Download release artifacts for manual signing (RELEASE_TAG=vX.Y.Z)
release-download:
	@scripts/release-download.sh $(RELEASE_TAG) $(DIST_RELEASE)

## Stage release notes into dist/ for upload (RELEASE_TAG=vX.Y.Z)
release-notes:
	@SRC="docs/releases/$(RELEASE_TAG).md"; \
	DEST="$(DIST_RELEASE)/release-notes-$(RELEASE_TAG).md"; \
	if [ ! -f "$$SRC" ]; then \
	  echo "⚠️  Release notes not found: $$SRC"; \
	  echo "   Skip ok for now; create it for next release."; \
	  echo "   To require notes: RELEASE_NOTES_REQUIRED=1 make release-notes RELEASE_TAG=$(RELEASE_TAG)"; \
	  if [ "$$RELEASE_NOTES_REQUIRED" = "1" ]; then exit 1; fi; \
	  exit 0; \
	fi; \
	mkdir -p "$(DIST_RELEASE)"; \
	cp "$$SRC" "$$DEST"; \
	chmod 0644 "$$DEST"; \
	echo "✅ Staged release notes: $$DEST"

## Get image digests for manual cosign signing (RELEASE_TAG=vX.Y.Z)
#
# Images can be overridden via IMAGES env var (space-delimited). Defaults to v0.2.x variants.
release-digests:
	@echo "Image digests for $(RELEASE_TAG):"
	@echo ""
	@IMAGES="$${IMAGES:-goneat-tools-runner goneat-tools-slim sbom-tools-runner sbom-tools-slim}"; \
	for image in $$IMAGES; do \
	  DIGEST=$$(docker manifest inspect ghcr.io/fulmenhq/$$image:$(RELEASE_TAG) -v 2>/dev/null | \
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
	@IMAGES="$${IMAGES:-goneat-tools-runner goneat-tools-slim sbom-tools-runner sbom-tools-slim}"; \
	missing=0; \
	echo "Verifying image digests for $(RELEASE_TAG)..."; \
	for image in $$IMAGES; do \
	  DIGEST=$$(docker manifest inspect ghcr.io/fulmenhq/$$image:$(RELEASE_TAG) -v 2>/dev/null | \
	    jq -r 'if type == "array" then .[0].Descriptor.digest else .config.digest end' 2>/dev/null) || true; \
	  if [ -n "$$DIGEST" ] && [ "$$DIGEST" != "null" ]; then \
	    echo "✅ $$image: $$DIGEST"; \
	  else \
	    echo "❌ $$image: missing tag $(RELEASE_TAG) or auth required" >&2; \
	    missing=1; \
	  fi; \
	done; \
	if [ $$missing -ne 0 ]; then \
	  echo "" >&2; \
	  echo "Release digest verification failed." >&2; \
	  exit 1; \
	fi; \
	echo "✅ All expected release image digests resolved."
## Perform interactive signing for downloaded release (RELEASE_TAG=vX.Y.Z)
release-sign:
	@scripts/release-sign.sh $(RELEASE_TAG) $(DIST_RELEASE)

## Export GPG public key for release (requires PGP_KEY_ID env var)
release-export-gpg-key:
	@if [ -z "$$PGP_KEY_ID" ]; then \
	  echo "❌ PGP_KEY_ID env var not set"; \
	  echo "   Set with: export PGP_KEY_ID='<your-key-id>!'"; \
	  exit 1; \
	fi
	@mkdir -p $(DIST_RELEASE)
	@echo "🔑 Exporting GPG public key ($$PGP_KEY_ID) to $(GPG_KEY_FILE)..."
	@if [ -n "$$GPG_HOMEDIR" ]; then \
	  env GNUPGHOME="$$GPG_HOMEDIR" gpg --armor --export "$$PGP_KEY_ID" > $(GPG_KEY_FILE); \
	else \
	  gpg --armor --export "$$PGP_KEY_ID" > $(GPG_KEY_FILE); \
	fi
	@echo "✅ GPG public key exported"

## Export minisign public key for release (requires MINISIGN_KEY env var)
release-export-minisign-key:
	@if [ -z "$$MINISIGN_KEY" ]; then \
	  echo "❌ MINISIGN_KEY env var not set"; \
	  echo "   Set with: export MINISIGN_KEY=\"\$$HOME/.minisign/minisign.key\""; \
	  exit 1; \
	fi
	@MINISIGN_PUB_SRC="$${MINISIGN_KEY%.key}.pub"; \
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

## Upload signed artifacts to GitHub Release (RELEASE_TAG=vX.Y.Z)
release-upload: verify-release-key verify-minisign-key
	@scripts/release-upload.sh $(RELEASE_TAG) $(DIST_RELEASE)

## Show manual signing workflow steps
release-signing-help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Manual Signing Workflow for fulmen-toolbox"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "1. AUTOMATED (run via make):"
	@echo "   RELEASE_TAG=v0.1.2 make release-download"
	@echo "   RELEASE_TAG=v0.1.2 make release-digests"
	@echo ""
	@echo "2. INTERACTIVE (run via make - still requires passphrase/browser):"
	@echo "   export PGP_KEY_ID='<your-key-id>!'"
	@echo "   export GPG_HOMEDIR=\"\$$HOME/.gnupg\"  # optional (multiple keyrings)"
	@echo "   export MINISIGN_KEY=\"\$$HOME/.minisign/minisign.key\""
	@echo "   RELEASE_TAG=v0.1.2 make release-sign"
	@echo ""
	@echo "   # Optional skips (debugging / partial runs):"
	@echo "   COSIGN=0 RELEASE_TAG=v0.1.2 make release-sign"
	@echo "   GPG=0 RELEASE_TAG=v0.1.2 make release-sign"
	@echo "   MINISIGN=0 RELEASE_TAG=v0.1.2 make release-sign"
	@echo "   # (equivalents: SKIP_COSIGN=1, SKIP_GPG=1, SKIP_MINISIGN=1)"
	@echo ""
	@echo "3. AUTOMATED (run via make):"
	@echo "   make verify-release-key"
	@echo "   RELEASE_TAG=v0.1.2 make release-upload"
	@echo ""

## Check required tooling is installed (tiered: core vs release)
prereqs bootstrap:
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
