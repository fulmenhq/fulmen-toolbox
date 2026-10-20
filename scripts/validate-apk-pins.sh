#!/usr/bin/env bash
#
# validate-apk-pins.sh
# Verify that APK package versions pinned in manifests/tools.json
# are actually available in the Alpine package repositories.
#
# This catches version drift (e.g., 0.12-r0 → 0.12-r1) before CI fails.
# Each pin is checked on linux/amd64 and linux/arm64. The host architecture
# and DOCKER_DEFAULT_PLATFORM do not choose which index is queried.

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

check_pkg() {
	local alpine_img="$1" platform="$2" pkg_name="$3" pkg_version="$4"
	local policy_output available_ver

	# Query Alpine repo for available version using apk policy.
	# --platform selects the index; do not follow DOCKER_DEFAULT_PLATFORM.
	policy_output=$(docker run --rm --platform "$platform" "$alpine_img" sh -c "apk update >/dev/null 2>&1 && apk policy '$pkg_name' 2>/dev/null" 2>/dev/null || true)

	if echo "$policy_output" | grep -qF "$pkg_version"; then
		echo "    ✓ $pkg_name=$pkg_version ($platform)"
		return 0
	fi

	echo "    ❌ $pkg_name=$pkg_version not available ($platform)"
	# Extract available version from policy output (second line, trimmed)
	available_ver=$(echo "$policy_output" | sed -n '2p' | tr -d ' :')
	if [ -n "$available_ver" ]; then
		echo "       Available: $available_ver"
	else
		echo "       Package not found in repository"
	fi
	fail=1
}

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

	for platform in linux/amd64 linux/arm64; do
		echo "  Checking against $alpine_img ($platform)..."

		# Check each package individually for clear error reporting
		for pkg_spec in $packages; do
			pkg_name="${pkg_spec%%=*}"
			pkg_version="${pkg_spec#*=}"
			check_pkg "$alpine_img" "$platform" "$pkg_name" "$pkg_version"
		done
	done
done

if [ "$fail" -ne 0 ]; then
	echo ""
	echo "APK pin validation failed. Update manifests/tools.json and Dockerfile ARGs."
	exit 1
fi

echo "All APK pins validated against upstream repositories."
