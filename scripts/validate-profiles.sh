#!/usr/bin/env bash
# validate-profiles.sh
# Enforce baseline profile conformance against Dockerfiles.
#
# v0.2.0 intent:
# - Dockerfiles remain static (no codegen)
# - `runner` targets must include `profiles.runner_baseline.packages`
# - `slim` targets must not install runner-only baseline packages
#
# Notes:
# - Some packages (e.g. `ca-certificates`) may legitimately appear in slim images.
#   This script only enforces "runner-only" packages (runner_baseline minus an allowlist).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILES_JSON="$ROOT/manifests/profiles.json"

if [ ! -f "$PROFILES_JSON" ]; then
  echo "profiles manifest missing: $PROFILES_JSON" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to validate profiles" >&2
  exit 1
fi

runner_baseline_pkgs=()
while IFS= read -r pkg; do
  runner_baseline_pkgs+=("$pkg")
done < <(jq -r '.profiles.runner_baseline.packages[]' "$PROFILES_JSON")

if [ "${#runner_baseline_pkgs[@]}" -eq 0 ]; then
  echo "runner_baseline is empty in $PROFILES_JSON" >&2
  exit 1
fi

# Packages that may appear in slim images without implying "runner".
# Keep this list small and documented.
slim_allowlist=(
  ca-certificates
)

is_allowed_in_slim() {
  local candidate="$1"
  for allowed in "${slim_allowlist[@]}"; do
    if [ "$candidate" = "$allowed" ]; then
      return 0
    fi
  done
  return 1
}

# Extract a stage body from Dockerfile by stage header.
# shellcheck disable=SC2016
extract_stage() {
  local dockerfile="$1" stage_header_regex="$2"
  awk -v re="$stage_header_regex" '
    $0 ~ re {in_stage=1}
    in_stage {print}
    in_stage && $0 ~ /^FROM / && $0 !~ re {exit}
  ' "$dockerfile"
}

assert_runner_has_pkg() {
  local dockerfile="$1" pkg="$2"

  # Accept either:
  # - pkg
  # - pkg=version
  if ! grep -Eq "(^|[[:space:]])${pkg}([[:space:]]|=|$)" "$dockerfile"; then
    echo "❌ runner missing package '$pkg' in $dockerfile" >&2
    return 1
  fi
}

assert_slim_does_not_have_pkg() {
  local dockerfile="$1" pkg="$2"

  if grep -Eq "(^|[[:space:]])${pkg}([[:space:]]|=|$)" "$dockerfile"; then
    echo "❌ slim includes runner-only package '$pkg' in $dockerfile" >&2
    return 1
  fi
}

validate_image_family() {
  local family="$1"
  local dockerfile="$ROOT/images/$family/Dockerfile"

  if [ ! -f "$dockerfile" ]; then
    echo "Dockerfile not found: $dockerfile" >&2
    return 1
  fi

  local slim_stage runner_stage
  slim_stage="$(extract_stage "$dockerfile" '^FROM .* AS slim$')"
  runner_stage="$(extract_stage "$dockerfile" '^FROM slim AS runner$')"

  if [ -z "$slim_stage" ]; then
    echo "❌ could not find slim stage in $dockerfile" >&2
    return 1
  fi

  if [ -z "$runner_stage" ]; then
    echo "❌ could not find runner stage in $dockerfile" >&2
    return 1
  fi

  local fail=0

  for pkg in "${runner_baseline_pkgs[@]}"; do
    if is_allowed_in_slim "$pkg"; then
      continue
    fi

    if ! assert_slim_does_not_have_pkg <(printf '%s\n' "$slim_stage") "$pkg"; then
      fail=1
    fi

    if ! assert_runner_has_pkg <(printf '%s\n' "$runner_stage") "$pkg"; then
      fail=1
    fi
  done

  return "$fail"
}

fail=0

validate_image_family goneat-tools || fail=1
validate_image_family sbom-tools || fail=1

if [ "$fail" -ne 0 ]; then
  echo "Profile validation failed." >&2
  exit 1
fi

echo "Baseline profile validation passed."
