#!/usr/bin/env bash
#
# validate-apk-pins.sh
# Verify that APK package versions pinned in manifests/tools.json
# are actually available in the Alpine package repositories.
#
# This catches version drift (e.g., 0.12-r0 → 0.12-r1) before CI fails.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/manifests/tools.json"

if [ ! -f "$MANIFEST" ]; then
  echo "Manifest not found: $MANIFEST" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required (install jq or run via goneat-tools image)" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to validate APK pins" >&2
  exit 1
fi

echo "Validating APK package availability..."

fail=0

# Process each unique Alpine base image
for alpine_img in "node:22-alpine" "alpine:3.21"; do
  # Extract APK pins for this Alpine image
  case "$alpine_img" in
    "node:22-alpine")
      image_filter="goneat-tools"
      ;;
    "alpine:3.21")
      image_filter="sbom-tools"
      ;;
  esac

  # Get packages for this base image
  packages=$(jq -r --arg filter "$image_filter" '
    .tools[]
    | select(.source == "apk")
    | select(.images[] | startswith($filter))
    | "\(.name)=\(.version)"
  ' "$MANIFEST" | sort -u)

  if [ -z "$packages" ]; then
    continue
  fi

  echo "  Checking against $alpine_img..."

  # Check each package individually for clear error reporting
  for pkg_spec in $packages; do
    pkg_name="${pkg_spec%%=*}"
    pkg_version="${pkg_spec#*=}"

    # Query Alpine repo for available version using apk policy
    policy_output=$(docker run --rm "$alpine_img" sh -c "apk update >/dev/null 2>&1 && apk policy '$pkg_name' 2>/dev/null" 2>/dev/null || true)

    if echo "$policy_output" | grep -qF "$pkg_version"; then
      echo "    ✓ $pkg_name=$pkg_version"
    else
      echo "    ❌ $pkg_name=$pkg_version not available"
      # Extract available version from policy output (second line, trimmed)
      available_ver=$(echo "$policy_output" | sed -n '2p' | tr -d ' :')
      if [ -n "$available_ver" ]; then
        echo "       Available: $available_ver"
      else
        echo "       Package not found in repository"
      fi
      fail=1
    fi
  done
done

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "APK pin validation failed. Update manifests/tools.json and Dockerfile ARGs."
  exit 1
fi

echo "All APK pins validated against upstream repositories."
