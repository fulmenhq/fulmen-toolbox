# docker-bake.hcl - Parallel multi-image builds with shared cache
#
# Usage:
#   docker buildx bake                     # All images, native arch
#   docker buildx bake --set *.platform=linux/amd64,linux/arm64  # All images, multi-arch
#   docker buildx bake goneat-runner-musl  # Single image
#   docker buildx bake goneat              # All goneat variants
#   docker buildx bake sbom                # All sbom variants
#
# With local cache:
#   docker buildx bake --set *.cache-from=type=local,src=.buildcache \
#                      --set *.cache-to=type=local,dest=.buildcache,mode=max

variable "REGISTRY" {
  default = "ghcr.io/fulmenhq"
}

variable "TAG" {
  default = "local"
}

# Groups for convenient building
group "default" {
  targets = ["goneat", "sbom", "valkey"]
}

group "goneat" {
  targets = ["goneat-runner-musl", "goneat-slim-musl", "goneat-runner-glibc"]
}

group "sbom" {
  targets = ["sbom-runner-musl", "sbom-slim-musl", "sbom-runner-glibc"]
}

group "valkey" {
  targets = ["valkey-server-glibc"]
}

group "runners" {
  targets = ["goneat-runner-musl", "goneat-runner-glibc", "sbom-runner-musl", "sbom-runner-glibc"]
}

group "slim" {
  targets = ["goneat-slim-musl", "sbom-slim-musl"]
}

# Common settings inherited by all targets
target "_common" {
  # Default to native platform for fast local builds
  # Override with --set *.platform=linux/amd64,linux/arm64 for multi-arch
  platforms = []
}

# ─────────────────────────────────────────────────────────────────────────────
# goneat-tools targets
# ─────────────────────────────────────────────────────────────────────────────

target "goneat-runner-musl" {
  inherits   = ["_common"]
  context    = "."
  dockerfile = "images/goneat-tools/Dockerfile"
  target     = "runner"
  tags       = ["${REGISTRY}/goneat-tools-runner-musl:${TAG}"]
}

target "goneat-slim-musl" {
  inherits   = ["_common"]
  context    = "."
  dockerfile = "images/goneat-tools/Dockerfile"
  target     = "slim"
  tags       = ["${REGISTRY}/goneat-tools-slim-musl:${TAG}"]
}

target "goneat-runner-glibc" {
  inherits   = ["_common"]
  context    = "."
  dockerfile = "images/goneat-tools-glibc/Dockerfile"
  target     = "runner"
  tags       = ["${REGISTRY}/goneat-tools-runner-glibc:${TAG}"]
}

# ─────────────────────────────────────────────────────────────────────────────
# sbom-tools targets
# ─────────────────────────────────────────────────────────────────────────────

target "sbom-runner-musl" {
  inherits   = ["_common"]
  context    = "."
  dockerfile = "images/sbom-tools/Dockerfile"
  target     = "runner"
  tags       = ["${REGISTRY}/sbom-tools-runner-musl:${TAG}"]
}

target "sbom-slim-musl" {
  inherits   = ["_common"]
  context    = "."
  dockerfile = "images/sbom-tools/Dockerfile"
  target     = "slim"
  tags       = ["${REGISTRY}/sbom-tools-slim-musl:${TAG}"]
}

target "sbom-runner-glibc" {
  inherits   = ["_common"]
  context    = "."
  dockerfile = "images/sbom-tools-glibc/Dockerfile"
  target     = "runner"
  tags       = ["${REGISTRY}/sbom-tools-runner-glibc:${TAG}"]
}

# ─────────────────────────────────────────────────────────────────────────────
# Application images
# ─────────────────────────────────────────────────────────────────────────────

target "valkey-server-glibc" {
  inherits   = ["_common"]
  context    = "."
  dockerfile = "images/valkey/Dockerfile"
  target     = "server"
  tags       = ["${REGISTRY}/valkey-server-glibc:${TAG}"]
}
