#!/usr/bin/env bash
#
# validate-pins.sh
# Ensure Dockerfiles contain the pinned versions declared in manifests/tools.json.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/manifests/tools.json"

if [ ! -f "$MANIFEST" ]; then
	echo "Manifest not found: $MANIFEST" >&2
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	echo "jq is required to validate pins (install jq or run via goneat-tools image)" >&2
	exit 1
fi

get_version() {
	local name="$1" image="$2"
	jq -r --arg name "$name" --arg image "$image" '
    (.tools[] | select(.name == $name and (.images | index($image))) | .version) // empty
  ' "$MANIFEST"
}

check_pin() {
	local file="$1" label="$2" needle="$3"
	if ! grep -qF "$needle" "$file"; then
		echo "❌ $label: missing pin \"$needle\" in $file"
		return 1
	fi
	return 0
}

fail=0

# sbom-tools pins
sbom_df="$ROOT/images/sbom-tools/Dockerfile"
sbom_alpine=$(get_version "alpine-base" "sbom-tools-slim-musl")
sbom_syft=$(get_version "syft" "sbom-tools-slim-musl")
sbom_grype=$(get_version "grype" "sbom-tools-slim-musl")
sbom_trivy=$(get_version "trivy" "sbom-tools-slim-musl")
sbom_jq=$(get_version "jq" "sbom-tools-slim-musl")
sbom_yq=$(get_version "yq-go" "sbom-tools-slim-musl")
sbom_git=$(get_version "git" "sbom-tools-runner-musl")
sbom_curl=$(get_version "curl" "sbom-tools-runner-musl")

for name in sbom_alpine sbom_syft sbom_grype sbom_trivy sbom_jq sbom_yq sbom_git sbom_curl; do
	if [ -z "${!name:-}" ]; then
		echo "❌ Missing manifest entry for ${name#sbom_}"
		fail=1
	fi
done

check_pin "$sbom_df" "sbom-tools base image" "ARG ALPINE_IMAGE=${sbom_alpine}" || fail=1
check_pin "$sbom_df" "sbom-tools syft" "ARG SYFT_VERSION=${sbom_syft}" || fail=1
check_pin "$sbom_df" "sbom-tools grype" "ARG GRYPE_VERSION=${sbom_grype}" || fail=1
check_pin "$sbom_df" "sbom-tools trivy" "ARG TRIVY_VERSION=${sbom_trivy}" || fail=1
check_pin "$sbom_df" "sbom-tools jq" "ARG JQ_VERSION=${sbom_jq}" || fail=1
check_pin "$sbom_df" "sbom-tools yq-go" "ARG YQ_VERSION=${sbom_yq}" || fail=1
check_pin "$sbom_df" "sbom-tools git" "ARG GIT_VERSION=${sbom_git}" || fail=1
check_pin "$sbom_df" "sbom-tools curl" "ARG CURL_VERSION=${sbom_curl}" || fail=1

# sbom-tools-glibc pins
sbom_glibc_df="$ROOT/images/sbom-tools-glibc/Dockerfile"
sbom_glibc_base=$(get_version "debian-base" "sbom-tools-runner-glibc")
sbom_glibc_syft=$(get_version "syft" "sbom-tools-runner-glibc")
sbom_glibc_grype=$(get_version "grype" "sbom-tools-runner-glibc")
sbom_glibc_trivy=$(get_version "trivy" "sbom-tools-runner-glibc")
sbom_glibc_jq=$(get_version "jq" "sbom-tools-runner-glibc")
sbom_glibc_yq=$(get_version "yq-go" "sbom-tools-runner-glibc")

for name in sbom_glibc_base sbom_glibc_syft sbom_glibc_grype sbom_glibc_trivy sbom_glibc_jq sbom_glibc_yq; do
	if [ -z "${!name:-}" ]; then
		echo "❌ Missing manifest entry for ${name#sbom_glibc_}"
		fail=1
	fi
done

check_pin "$sbom_glibc_df" "sbom-tools-glibc base image" "ARG DEBIAN_IMAGE=${sbom_glibc_base}" || fail=1
check_pin "$sbom_glibc_df" "sbom-tools-glibc syft" "ARG SYFT_VERSION=${sbom_glibc_syft}" || fail=1
check_pin "$sbom_glibc_df" "sbom-tools-glibc grype" "ARG GRYPE_VERSION=${sbom_glibc_grype}" || fail=1
check_pin "$sbom_glibc_df" "sbom-tools-glibc trivy" "ARG TRIVY_VERSION=${sbom_glibc_trivy}" || fail=1
check_pin "$sbom_glibc_df" "sbom-tools-glibc jq" "ARG JQ_VERSION=${sbom_glibc_jq}" || fail=1
check_pin "$sbom_glibc_df" "sbom-tools-glibc yq-go" "ARG YQ_VERSION=${sbom_glibc_yq}" || fail=1

# goneat-tools pins
goneat_df="$ROOT/images/goneat-tools/Dockerfile"
goneat_node=$(get_version "node-base" "goneat-tools-slim-musl")
goneat_go=$(get_version "golang-builder" "goneat-tools-slim-musl")
goneat_prettier=$(get_version "prettier" "goneat-tools-slim-musl")
goneat_biome=$(get_version "biome" "goneat-tools-slim-musl")
goneat_npm=$(get_version "npm" "goneat-tools-slim-musl")
goneat_yamlfmt=$(get_version "yamlfmt" "goneat-tools-slim-musl")
goneat_shfmt=$(get_version "shfmt" "goneat-tools-slim-musl")
goneat_checkmake=$(get_version "checkmake" "goneat-tools-slim-musl")
goneat_actionlint=$(get_version "actionlint" "goneat-tools-slim-musl")
goneat_jq=$(get_version "jq" "goneat-tools-slim-musl")
goneat_yq=$(get_version "yq-go" "goneat-tools-slim-musl")
goneat_ripgrep=$(get_version "ripgrep" "goneat-tools-slim-musl")
goneat_taplo=$(get_version "taplo" "goneat-tools-slim-musl")
goneat_minisign=$(get_version "minisign" "goneat-tools-slim-musl")
goneat_goneat=$(get_version "goneat" "goneat-tools-slim-musl")
goneat_sfetch=$(get_version "sfetch" "goneat-tools-slim-musl")
goneat_bash=$(get_version "bash" "goneat-tools-runner-musl")
goneat_git=$(get_version "git" "goneat-tools-runner-musl")
goneat_curl=$(get_version "curl" "goneat-tools-runner-musl")
goneat_ruff=$(get_version "ruff" "goneat-tools-runner-musl")
goneat_gover=$(get_version "go" "goneat-tools-runner-musl")
goneat_rust=$(get_version "rustc" "goneat-tools-runner-musl")
goneat_pytest=$(get_version "pytest" "goneat-tools-runner-musl")
goneat_golangci=$(get_version "golangci-lint" "goneat-tools-runner-musl")

for name in goneat_node goneat_go goneat_prettier goneat_biome goneat_npm goneat_yamlfmt goneat_shfmt goneat_checkmake goneat_actionlint goneat_jq goneat_yq goneat_ripgrep goneat_taplo goneat_bash goneat_git goneat_curl goneat_minisign goneat_goneat goneat_sfetch goneat_ruff goneat_gover goneat_rust goneat_pytest goneat_golangci; do
	if [ -z "${!name:-}" ]; then
		echo "❌ Missing manifest entry for ${name#goneat_}"
		fail=1
	fi
done

check_pin "$goneat_df" "goneat-tools node base" "ARG NODE_IMAGE=${goneat_node}" || fail=1
check_pin "$goneat_df" "goneat-tools golang builder" "ARG GO_IMAGE=${goneat_go}" || fail=1
check_pin "$goneat_df" "goneat-tools prettier" "ARG PRETTIER_VERSION=${goneat_prettier}" || fail=1
check_pin "$goneat_df" "goneat-tools biome" "ARG BIOME_VERSION=${goneat_biome}" || fail=1
check_pin "$goneat_df" "goneat-tools npm" "ARG NPM_VERSION=${goneat_npm}" || fail=1
check_pin "$goneat_df" "goneat-tools yamlfmt" "ARG YAMLFMT_VERSION=${goneat_yamlfmt}" || fail=1
check_pin "$goneat_df" "goneat-tools shfmt" "ARG SHFMT_VERSION=${goneat_shfmt}" || fail=1
check_pin "$goneat_df" "goneat-tools checkmake" "ARG CHECKMAKE_VERSION=${goneat_checkmake}" || fail=1
check_pin "$goneat_df" "goneat-tools actionlint" "ARG ACTIONLINT_VERSION=${goneat_actionlint}" || fail=1
check_pin "$goneat_df" "goneat-tools jq" "ARG JQ_VERSION=${goneat_jq}" || fail=1
check_pin "$goneat_df" "goneat-tools yq-go" "ARG YQ_VERSION=${goneat_yq}" || fail=1
check_pin "$goneat_df" "goneat-tools ripgrep" "ARG RIPGREP_VERSION=${goneat_ripgrep}" || fail=1
check_pin "$goneat_df" "goneat-tools taplo" "ARG TAPLO_VERSION=${goneat_taplo}" || fail=1
check_pin "$goneat_df" "goneat-tools bash" "ARG BASH_VERSION=${goneat_bash}" || fail=1
check_pin "$goneat_df" "goneat-tools git" "ARG GIT_VERSION=${goneat_git}" || fail=1
check_pin "$goneat_df" "goneat-tools curl" "ARG CURL_VERSION=${goneat_curl}" || fail=1
check_pin "$goneat_df" "goneat-tools minisign" "ARG MINISIGN_VERSION=${goneat_minisign}" || fail=1
check_pin "$goneat_df" "goneat-tools goneat" "ARG GONEAT_VERSION=${goneat_goneat}" || fail=1
check_pin "$goneat_df" "goneat-tools sfetch" "ARG SFETCH_VERSION=${goneat_sfetch}" || fail=1
check_pin "$goneat_df" "goneat-tools ruff" "ARG RUFF_VERSION=${goneat_ruff}" || fail=1
# The Go toolchain shipped at /opt/go. Kept in lockstep with GO_IMAGE (see the
# GO_IMAGE <-> GO_VERSION rule); unchecked until v0.5.0, during which the
# manifest silently drifted to 1.26.2 while the Dockerfiles carried 1.26.4.
check_pin "$goneat_df" "goneat-tools go toolchain" "ARG GO_VERSION=${goneat_gover}" || fail=1
check_pin "$goneat_df" "goneat-tools rust toolchain" "ARG RUST_VERSION=${goneat_rust}" || fail=1
check_pin "$goneat_df" "goneat-tools pytest" "ARG PYTEST_VERSION=${goneat_pytest}" || fail=1
check_pin "$goneat_df" "goneat-tools golangci-lint" "ARG GOLANGCI_LINT_VERSION=${goneat_golangci}" || fail=1

# goneat-tools-glibc pins
goneat_glibc_df="$ROOT/images/goneat-tools-glibc/Dockerfile"
goneat_glibc_node=$(get_version "node-base-glibc" "goneat-tools-runner-glibc")
goneat_glibc_go=$(get_version "golang-builder-glibc" "goneat-tools-runner-glibc")
goneat_glibc_prettier=$(get_version "prettier" "goneat-tools-runner-glibc")
goneat_glibc_biome=$(get_version "biome" "goneat-tools-runner-glibc")
goneat_glibc_npm=$(get_version "npm" "goneat-tools-runner-glibc")
goneat_glibc_yamlfmt=$(get_version "yamlfmt" "goneat-tools-runner-glibc")
goneat_glibc_shfmt=$(get_version "shfmt" "goneat-tools-runner-glibc")
goneat_glibc_checkmake=$(get_version "checkmake" "goneat-tools-runner-glibc")
goneat_glibc_actionlint=$(get_version "actionlint" "goneat-tools-runner-glibc")
goneat_glibc_jq=$(get_version "jq" "goneat-tools-runner-glibc")
goneat_glibc_yq=$(get_version "yq-go" "goneat-tools-runner-glibc")
goneat_glibc_ripgrep=$(get_version "ripgrep" "goneat-tools-runner-glibc")
goneat_glibc_taplo=$(get_version "taplo" "goneat-tools-runner-glibc")
goneat_glibc_minisign=$(get_version "minisign" "goneat-tools-runner-glibc")
goneat_glibc_goneat=$(get_version "goneat" "goneat-tools-runner-glibc")
goneat_glibc_sfetch=$(get_version "sfetch" "goneat-tools-runner-glibc")
goneat_glibc_ruff=$(get_version "ruff" "goneat-tools-runner-glibc")
goneat_glibc_gover=$(get_version "go" "goneat-tools-runner-glibc")
goneat_glibc_rust=$(get_version "rustc" "goneat-tools-runner-glibc")
goneat_glibc_pytest=$(get_version "pytest" "goneat-tools-runner-glibc")
goneat_glibc_golangci=$(get_version "golangci-lint" "goneat-tools-runner-glibc")

for name in goneat_glibc_node goneat_glibc_go goneat_glibc_prettier goneat_glibc_biome goneat_glibc_npm goneat_glibc_yamlfmt goneat_glibc_shfmt goneat_glibc_checkmake goneat_glibc_actionlint goneat_glibc_jq goneat_glibc_yq goneat_glibc_ripgrep goneat_glibc_taplo goneat_glibc_minisign goneat_glibc_goneat goneat_glibc_sfetch goneat_glibc_ruff goneat_glibc_gover goneat_glibc_rust goneat_glibc_pytest goneat_glibc_golangci; do
	if [ -z "${!name:-}" ]; then
		echo "❌ Missing manifest entry for ${name#goneat_glibc_}"
		fail=1
	fi
done

check_pin "$goneat_glibc_df" "goneat-tools-glibc node base" "ARG NODE_IMAGE=${goneat_glibc_node}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc golang builder" "ARG GO_IMAGE=${goneat_glibc_go}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc prettier" "ARG PRETTIER_VERSION=${goneat_glibc_prettier}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc biome" "ARG BIOME_VERSION=${goneat_glibc_biome}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc npm" "ARG NPM_VERSION=${goneat_glibc_npm}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc yamlfmt" "ARG YAMLFMT_VERSION=${goneat_glibc_yamlfmt}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc shfmt" "ARG SHFMT_VERSION=${goneat_glibc_shfmt}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc checkmake" "ARG CHECKMAKE_VERSION=${goneat_glibc_checkmake}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc actionlint" "ARG ACTIONLINT_VERSION=${goneat_glibc_actionlint}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc jq" "ARG JQ_VERSION=${goneat_glibc_jq}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc yq-go" "ARG YQ_VERSION=${goneat_glibc_yq}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc ripgrep" "ARG RIPGREP_VERSION=${goneat_glibc_ripgrep}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc taplo" "ARG TAPLO_VERSION=${goneat_glibc_taplo}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc minisign" "ARG MINISIGN_VERSION=${goneat_glibc_minisign}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc goneat" "ARG GONEAT_VERSION=${goneat_glibc_goneat}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc sfetch" "ARG SFETCH_VERSION=${goneat_glibc_sfetch}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc ruff" "ARG RUFF_VERSION=${goneat_glibc_ruff}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc go toolchain" "ARG GO_VERSION=${goneat_glibc_gover}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc rust toolchain" "ARG RUST_VERSION=${goneat_glibc_rust}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc pytest" "ARG PYTEST_VERSION=${goneat_glibc_pytest}" || fail=1
check_pin "$goneat_glibc_df" "goneat-tools-glibc golangci-lint" "ARG GOLANGCI_LINT_VERSION=${goneat_glibc_golangci}" || fail=1

# apt security pins (glibc runners) — inline-pinned in the apt install line,
# not an ARG. Presence enforced here; availability enforced by validate-apt-pins.sh.
libgnutls30_ver=$(get_version "libgnutls30" "goneat-tools-runner-glibc")
if [ -z "${libgnutls30_ver:-}" ]; then
	echo "❌ Missing manifest entry for libgnutls30"
	fail=1
fi
check_pin "$goneat_glibc_df" "goneat-tools-glibc libgnutls30 security pin" "libgnutls30=${libgnutls30_ver}" || fail=1
check_pin "$sbom_glibc_df" "sbom-tools-glibc libgnutls30 security pin" "libgnutls30=${libgnutls30_ver}" || fail=1

if [ "$fail" -ne 0 ]; then
	echo "Pin validation failed."
	exit 1
fi

echo "All pins validated against manifests/tools.json."
