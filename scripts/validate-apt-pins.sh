#!/usr/bin/env bash
#
# validate-apt-pins.sh
# Verify that APT package versions pinned in manifests/tools.json
# are actually available in the Debian package repositories (incl. the
# bookworm-security repo).
#
# This is the apt analog of validate-apk-pins.sh. It catches the same drift
# class that bit the alpine pins in v0.4.2: a security-patched package version
# (e.g. libgnutls30 3.7.9-2+deb12u7) that we pin deterministically can be
# rotated out of the repo by a newer point release, which would otherwise only
# surface as a hard `apt-get install` failure deep in a 15-minute build.
#
# It also emits an informational hint when a *newer* candidate than the pin is
# available, so security pins don't silently fall behind upstream.

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
	echo "docker is required to validate APT pins" >&2
	exit 1
fi

echo "Validating APT package availability..."

fail=0
checked=0

# Process each Debian base image that ships a glibc runner. The image filter
# maps a base to the tools.json image name whose final runtime layer is that
# base (see node-base-glibc / debian-base entries).
for debian_img in "node:22-bookworm-slim" "debian:bookworm-slim"; do
	case "$debian_img" in
	"node:22-bookworm-slim")
		image_filter="goneat-tools-runner-glibc"
		;;
	"debian:bookworm-slim")
		image_filter="sbom-tools-runner-glibc"
		;;
	esac

	# Get apt-sourced pins applicable to this base image.
	packages=$(jq -r --arg img "$image_filter" '
    .tools[]
    | select(.source == "apt")
    | select(.images | index($img))
    | "\(.name)=\(.version)"
  ' "$MANIFEST" | sort -u)

	if [ -z "$packages" ]; then
		continue
	fi

	echo "  Checking against $debian_img..."

	# One container per package for clear error reporting (mirrors validate-apk-pins).
	for pkg_spec in $packages; do
		pkg_name="${pkg_spec%%=*}"
		pkg_version="${pkg_spec#*=}"
		checked=$((checked + 1))

		policy_output=$(docker run --rm "$debian_img" sh -c "apt-get update >/dev/null 2>&1 && apt-cache policy '$pkg_name' 2>/dev/null" 2>/dev/null || true)
		candidate=$(echo "$policy_output" | awk -F': ' '/Candidate:/{print $2; exit}' | tr -d ' ')

		if echo "$policy_output" | grep -qF "$pkg_version"; then
			echo "    ✓ $pkg_name=$pkg_version"
			# Informational: flag if a newer candidate than the pin exists.
			if [ -n "$candidate" ] && [ "$candidate" != "$pkg_version" ]; then
				echo "       ℹ newer candidate available: $candidate (pinned: $pkg_version) — review for security relevance"
			fi
		else
			echo "    ❌ $pkg_name=$pkg_version not available"
			if [ -n "$candidate" ]; then
				echo "       Available candidate: $candidate"
			else
				echo "       Package not found in repository"
			fi
			fail=1
		fi
	done
done

if [ "$checked" -eq 0 ]; then
	echo "No apt-sourced pins found in manifests/tools.json (nothing to validate)."
	exit 0
fi

if [ "$fail" -ne 0 ]; then
	echo ""
	echo "APT pin validation failed. Update manifests/tools.json and the glibc Dockerfile apt install lines."
	exit 1
fi

echo "All APT pins validated against upstream repositories."
