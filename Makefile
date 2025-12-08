.PHONY: all build-goneat-tools build-goneat-tools-multi test-goneat-tools clean help \
	bump-major bump-minor bump-patch lint-sh fmt-sh release-plan prereqs bootstrap \
	validate-manifest lint-workflows quality precommit prepuh prepush

# Fulmen Toolbox - Local Development Makefile
# Supports building/testing goneat-tools (Phase 1)
# Extend for future images as needed

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

all: build-goneat-tools test-goneat-tools

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

## Clean up local images
clean:
	docker rmi $(TAG_LOCAL) $(TAG_LATEST) || true

## Show Docker image sizes
size:
	docker images $(REGISTRY)/$(IMAGE_NAME)*

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

## Quality bundle: manifest validation + workflow lint
quality: validate-manifest lint-workflows

## Precommit bundle: quality checks
precommit:
	@$(MAKE) quality

## Prepush bundle: quality + build + test (requires docker daemon)
prepush prepuh:
	@$(MAKE) quality
	@$(MAKE) build-goneat-tools
	@$(MAKE) test-goneat-tools

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
