.PHONY: all build-all test-all \
	build-goneat-tools build-goneat-tools-multi test-goneat-tools \
	build-sbom-tools build-sbom-tools-multi test-sbom-tools \
	clean help bump-major bump-minor bump-patch lint-sh fmt-sh release-plan prereqs bootstrap \
	validate-manifest lint-workflows lint-dockerfiles quality precommit prepush check-clean \
	release-download release-upload verify-release-key release-digests

# Fulmen Toolbox - Local Development Makefile
# Supports building/testing goneat-tools and sbom-tools

REGISTRY := ghcr.io/fulmenhq
IMAGE_NAME := goneat-tools
TAG_LOCAL := $(REGISTRY)/$(IMAGE_NAME):local
TAG_LATEST := $(REGISTRY)/$(IMAGE_NAME):latest
VERSION_FILE := VERSION
BUMP_SCRIPT := scripts/bump-version.sh

SHELLCHECK ?= shellcheck
SHFMT ?= shfmt
PREREQ_CMDS ?= docker cosign gpg minisign syft trivy yamlfmt
OPTIONAL_CMDS ?= shellcheck shfmt
VALIDATE_MANIFEST ?= scripts/validate-manifest.sh
YAMLFMT ?= yamlfmt
YAMLFMT_PIN ?= v0.20.0
MISSING_ACTION ?= "missing required tooling; install before proceeding"
YAMLLINT ?= yamllint

## Build and test all images
all: build-all test-all

## Build all images (single-arch)
build-all: build-goneat-tools build-sbom-tools

## Test all images
test-all: test-goneat-tools test-sbom-tools

# ─────────────────────────────────────────────────────────────────────────────
# goneat-tools targets
# ─────────────────────────────────────────────────────────────────────────────

## Build single-arch (fast local testing)
build-goneat-tools:
	docker build -t $(TAG_LOCAL) images/$(IMAGE_NAME)

## Build multi-arch (linux/amd64 + linux/arm64)
build-goneat-tools-multi:
	docker buildx create --use || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		-t $(TAG_LOCAL) \
		-t $(TAG_LATEST) \
		--push=false \
		images/$(IMAGE_NAME)

## Test the image (run tools, check versions)
test-goneat-tools:
	docker run --rm $(TAG_LOCAL) -c "\
		prettier --version && \
		yamlfmt --version && \
		jq --version && \
		yq --version && \
		rg --version && \
		echo 'All tools OK!'"

# ─────────────────────────────────────────────────────────────────────────────
# sbom-tools targets
# ─────────────────────────────────────────────────────────────────────────────
SBOM_IMAGE_NAME := sbom-tools
SBOM_TAG_LOCAL := $(REGISTRY)/$(SBOM_IMAGE_NAME):local
SBOM_TAG_LATEST := $(REGISTRY)/$(SBOM_IMAGE_NAME):latest

## Build sbom-tools single-arch (fast local testing)
build-sbom-tools:
	docker build -t $(SBOM_TAG_LOCAL) images/$(SBOM_IMAGE_NAME)

## Build sbom-tools multi-arch (linux/amd64 + linux/arm64)
build-sbom-tools-multi:
	docker buildx create --use || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		-t $(SBOM_TAG_LOCAL) \
		-t $(SBOM_TAG_LATEST) \
		--push=false \
		images/$(SBOM_IMAGE_NAME)

## Test sbom-tools (run tools, check versions)
test-sbom-tools:
	docker run --rm $(SBOM_TAG_LOCAL) -c "\
		syft version && \
		grype version && \
		trivy version && \
		echo 'All SBOM tools OK!'"

# ─────────────────────────────────────────────────────────────────────────────

## Clean up local images
clean:
	docker rmi $(TAG_LOCAL) $(TAG_LATEST) $(SBOM_TAG_LOCAL) $(SBOM_TAG_LATEST) || true

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

## Quality bundle: manifest validation + workflow lint + dockerfile lint
quality: validate-manifest lint-workflows lint-dockerfiles

## Precommit bundle: quality checks
precommit:
	@$(MAKE) quality

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

## Get image digests for manual cosign signing (RELEASE_TAG=vX.Y.Z)
release-digests:
	@echo "Image digests for $(RELEASE_TAG):"
	@echo ""
	@GONEAT=$$(docker manifest inspect ghcr.io/fulmenhq/goneat-tools:$(RELEASE_TAG) -v 2>/dev/null | \
	  jq -r 'if type == "array" then .[0].Descriptor.digest else .config.digest end' 2>/dev/null) && \
	  if [ -n "$$GONEAT" ] && [ "$$GONEAT" != "null" ]; then \
	    echo "goneat-tools: $$GONEAT"; \
	    echo "  cosign sign ghcr.io/fulmenhq/goneat-tools@$$GONEAT"; \
	  else \
	    echo "goneat-tools: (waiting for image push or auth required)"; \
	  fi
	@echo ""
	@SBOM=$$(docker manifest inspect ghcr.io/fulmenhq/sbom-tools:$(RELEASE_TAG) -v 2>/dev/null | \
	  jq -r 'if type == "array" then .[0].Descriptor.digest else .config.digest end' 2>/dev/null) && \
	  if [ -n "$$SBOM" ] && [ "$$SBOM" != "null" ]; then \
	    echo "sbom-tools: $$SBOM"; \
	    echo "  cosign sign ghcr.io/fulmenhq/sbom-tools@$$SBOM"; \
	  else \
	    echo "sbom-tools: (waiting for image push or auth required)"; \
	  fi

## Export GPG public key for release (requires PGP_KEY_ID env var)
release-export-gpg-key:
	@if [ -z "$$PGP_KEY_ID" ]; then \
	  echo "❌ PGP_KEY_ID env var not set"; \
	  echo "   Set with: export PGP_KEY_ID='<your-key-id>!'"; \
	  exit 1; \
	fi
	@mkdir -p $(DIST_RELEASE)
	@echo "🔑 Exporting GPG public key ($$PGP_KEY_ID) to $(GPG_KEY_FILE)..."
	@gpg --armor --export "$$PGP_KEY_ID" > $(GPG_KEY_FILE)
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
	echo "✅ Minisign public key copied"

## Export both public keys for release
release-export-keys: release-export-gpg-key release-export-minisign-key

## Verify GPG public key is safe to upload (no private key material)
verify-release-key: release-export-gpg-key
	@scripts/verify-public-key.sh $(GPG_KEY_FILE)

## Upload signed artifacts to GitHub Release (RELEASE_TAG=vX.Y.Z)
release-upload: verify-release-key release-export-minisign-key
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
	@echo "2. INTERACTIVE (run in separate shell - requires passphrase/browser):"
	@echo "   # Cosign (keyless OIDC - opens browser)"
	@echo "   cosign sign ghcr.io/fulmenhq/goneat-tools@sha256:<digest>"
	@echo "   cosign sign ghcr.io/fulmenhq/sbom-tools@sha256:<digest>"
	@echo "   cosign attest --predicate sbom-*.json --type spdxjson ghcr.io/fulmenhq/<image>@sha256:<digest>"
	@echo ""
	@echo "   # GPG (requires passphrase)"
	@echo "   gpg --armor --detach-sign -o SHA256SUMS-goneat-tools.asc SHA256SUMS-goneat-tools"
	@echo "   gpg --armor --detach-sign -o SHA256SUMS-sbom-tools.asc SHA256SUMS-sbom-tools"
	@echo ""
	@echo "   # Minisign (requires passphrase)"
	@echo "   minisign -Sm SHA256SUMS-goneat-tools -t 'fulmen-toolbox goneat-tools <version>'"
	@echo "   minisign -Sm SHA256SUMS-sbom-tools -t 'fulmen-toolbox sbom-tools <version>'"
	@echo ""
	@echo "   # Export public keys"
	@echo "   gpg --armor --export <KEY_ID>! > $(GPG_KEY_FILE)"
	@echo "   cp /path/to/minisign.pub $(MINISIGN_PUB)"
	@echo ""
	@echo "3. AUTOMATED (run via make):"
	@echo "   make verify-release-key"
	@echo "   RELEASE_TAG=v0.1.2 make release-upload"
	@echo ""

## Check required tooling is installed (non-fatal for optional tools)
prereqs bootstrap:
	@missing=0; \
	for cmd in $(PREREQ_CMDS); do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo "$$cmd: ok"; \
		else \
			if [ "$$cmd" = "yamlfmt" ]; then \
				echo "$$cmd: MISSING (install via: go install github.com/google/yamlfmt/cmd/yamlfmt@$(YAMLFMT_PIN))"; \
			elif [ "$$cmd" = "trivy" ]; then \
				echo "$$cmd: MISSING (install via: brew install trivy)"; \
			elif [ "$$cmd" = "cosign" ]; then \
				echo "$$cmd: MISSING (install via: brew install cosign)"; \
			else \
				echo "$$cmd: MISSING"; \
			fi; \
			missing=1; \
		fi; \
	done; \
	if docker buildx version >/dev/null 2>&1; then \
		echo "docker buildx: ok"; \
	else \
		echo "docker buildx: MISSING (install docker buildx)"; missing=1; \
	fi; \
	for cmd in $(OPTIONAL_CMDS); do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo "$$cmd: ok (optional)"; \
		else \
			echo "$$cmd: missing (optional)"; \
		fi; \
	done; \
	if [ $$missing -ne 0 ]; then \
		echo $(MISSING_ACTION); \
	fi; \
	exit $$missing

## Help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

## Usage Examples:
# make build-goneat-tools test-goneat-tools
# make build-goneat-tools-multi
# make size
# make clean
