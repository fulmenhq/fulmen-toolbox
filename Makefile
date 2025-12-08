.PHONY: all build-all test-all \
	build-goneat-tools build-goneat-tools-multi test-goneat-tools \
	build-sbom-tools build-sbom-tools-multi test-sbom-tools \
	clean help bump-major bump-minor bump-patch lint-sh fmt-sh release-plan prereqs bootstrap \
	validate-manifest lint-workflows lint-dockerfiles quality precommit prepush check-clean

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
PREREQ_CMDS ?= docker cosign gpg minisign syft yamlfmt
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

## Validate Dockerfiles syntax (docker build --check, requires Docker 25+/BuildKit)
## TODO: Add trivy config scanning for best practices in future release
lint-dockerfiles:
	@if docker build --help 2>&1 | grep -q '\-\-check'; then \
		echo "Validating Dockerfile syntax (docker build --check)..."; \
		for df in images/*/Dockerfile; do \
			echo "  checking $$df"; \
			DOCKER_BUILDKIT=1 docker build --check -f "$$df" "$$(dirname $$df)" > /dev/null || exit 1; \
		done; \
		echo "All Dockerfiles valid."; \
	else \
		echo "docker build --check not available (requires Docker 25+/BuildKit). Skipping Dockerfile lint."; \
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

## Check required tooling is installed (non-fatal for optional tools)
prereqs bootstrap:
	@missing=0; \
	for cmd in $(PREREQ_CMDS); do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo "$$cmd: ok"; \
		else \
			if [ "$$cmd" = "yamlfmt" ]; then \
				echo "$$cmd: MISSING (install via: go install github.com/google/yamlfmt/cmd/yamlfmt@$(YAMLFMT_PIN))"; \
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
