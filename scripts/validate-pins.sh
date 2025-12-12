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
sbom_alpine=$(get_version "alpine-base" "sbom-tools")
sbom_syft=$(get_version "syft" "sbom-tools")
sbom_grype=$(get_version "grype" "sbom-tools")
sbom_trivy=$(get_version "trivy" "sbom-tools")
sbom_jq=$(get_version "jq" "sbom-tools")
sbom_yq=$(get_version "yq-go" "sbom-tools")
sbom_git=$(get_version "git" "sbom-tools")

for name in sbom_alpine sbom_syft sbom_grype sbom_trivy sbom_jq sbom_yq sbom_git; do
  if [ -z "${!name:-}" ]; then
    echo "❌ Missing manifest entry for ${name#sbom_}"
    fail=1
  fi
done

check_pin "$sbom_df" "sbom-tools base image" "ARG ALPINE_IMAGE=${sbom_alpine}" || fail=1
check_pin "$sbom_df" "sbom-tools syft" "ARG SYFT_VERSION=${sbom_syft}" || fail=1
check_pin "$sbom_df" "sbom-tools grype" "ARG GRYPE_VERSION=${sbom_grype}" || fail=1
check_pin "$sbom_df" "sbom-tools trivy" "ARG TRIVY_VERSION=${sbom_trivy}" || fail=1
check_pin "$sbom_df" "sbom-tools jq" "jq=${sbom_jq}" || fail=1
check_pin "$sbom_df" "sbom-tools yq-go" "yq-go=${sbom_yq}" || fail=1
check_pin "$sbom_df" "sbom-tools git" "git=${sbom_git}" || fail=1

# goneat-tools pins
goneat_df="$ROOT/images/goneat-tools/Dockerfile"
goneat_node=$(get_version "node-base" "goneat-tools")
goneat_go=$(get_version "golang-builder" "goneat-tools")
goneat_prettier=$(get_version "prettier" "goneat-tools")
goneat_biome=$(get_version "biome" "goneat-tools")
goneat_yamlfmt=$(get_version "yamlfmt" "goneat-tools")
goneat_shfmt=$(get_version "shfmt" "goneat-tools")
goneat_checkmake=$(get_version "checkmake" "goneat-tools")
goneat_actionlint=$(get_version "actionlint" "goneat-tools")
goneat_jq=$(get_version "jq" "goneat-tools")
goneat_yq=$(get_version "yq-go" "goneat-tools")
goneat_ripgrep=$(get_version "ripgrep" "goneat-tools")
goneat_taplo=$(get_version "taplo" "goneat-tools")
goneat_bash=$(get_version "bash" "goneat-tools")
goneat_git=$(get_version "git" "goneat-tools")
goneat_curl=$(get_version "curl" "goneat-tools")

for name in goneat_node goneat_go goneat_prettier goneat_biome goneat_yamlfmt goneat_shfmt goneat_checkmake goneat_actionlint goneat_jq goneat_yq goneat_ripgrep goneat_taplo goneat_bash goneat_git goneat_curl; do
  if [ -z "${!name:-}" ]; then
    echo "❌ Missing manifest entry for ${name#goneat_}"
    fail=1
  fi
done

check_pin "$goneat_df" "goneat-tools node base" "ARG NODE_IMAGE=${goneat_node}" || fail=1
check_pin "$goneat_df" "goneat-tools golang builder" "ARG GO_IMAGE=${goneat_go}" || fail=1
check_pin "$goneat_df" "goneat-tools prettier" "ARG PRETTIER_VERSION=${goneat_prettier}" || fail=1
check_pin "$goneat_df" "goneat-tools biome" "ARG BIOME_VERSION=${goneat_biome}" || fail=1
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

if [ "$fail" -ne 0 ]; then
  echo "Pin validation failed."
  exit 1
fi

echo "All pins validated against manifests/tools.json."
