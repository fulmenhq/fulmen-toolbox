#!/usr/bin/env bash
# release-sign.sh - Perform the interactive signing phase for a release
#
# This script is intended to reduce PKI/cosign footguns for maintainers by
# providing a single entrypoint for the manual signing phase.
#
# Usage: ./scripts/release-sign.sh <tag> [dir]
#
# Examples:
#   export RELEASE_TAG=v0.2.0
#   export PGP_KEY_ID='448A539320A397AF!'
#   export MINISIGN_KEY="$HOME/.minisign/minisign.key"
#   make release-download RELEASE_TAG=$RELEASE_TAG
#   make release-sign RELEASE_TAG=$RELEASE_TAG
#
# Environment variables:
#   REGISTRY      - Container registry (default: ghcr.io)
#   OWNER         - Registry owner/org (default: fulmenhq)
#   IMAGES        - Space-delimited images to sign
#                  (default: "goneat-tools-runner goneat-tools-slim sbom-tools-runner sbom-tools-slim")
#   PGP_KEY_ID    - GPG key ID for signing SHA256SUMS-*
#   GPG_HOMEDIR   - Optional GPG home directory (script sets GNUPGHOME internally)
#   MINISIGN_KEY  - Path to minisign secret key for signing SHA256SUMS-*
#   COSIGN        - Set to 0 to disable all cosign operations
#   ATTACH_SBOM   - Set to 0 to skip OCI SBOM attach
#   GPG           - Set to 0 to disable GPG signing
#   MINISIGN      - Set to 0 to disable minisign signing
#   SKIP_COSIGN   - Set to 1 to skip cosign sign/attest
#   SKIP_GPG      - Set to 1 to skip GPG signing
#   SKIP_MINISIGN - Set to 1 to skip minisign signing
#
# Notes:
# - cosign signing is keyless by default and may open a browser for OIDC.
# - This script does NOT upload anything; use make release-upload afterwards.

set -euo pipefail

TAG=${1:?
"Usage: release-sign.sh <tag> [dir]\n\nExample: release-sign.sh v0.2.0 dist/release"}
DIR=${2:-dist/release}

REGISTRY=${REGISTRY:-ghcr.io}
OWNER=${OWNER:-fulmenhq}
IMAGES=${IMAGES:-"goneat-tools-runner goneat-tools-slim sbom-tools-runner sbom-tools-slim"}

PGP_KEY_ID=${PGP_KEY_ID:-}
GPG_HOMEDIR=${GPG_HOMEDIR:-}
MINISIGN_KEY=${MINISIGN_KEY:-}

# NOTE: `cosign attach sbom` is deprecated upstream; attestations are the canonical SBOM signal.
# Default to attestation-only; set ATTACH_SBOM=1 to enable legacy OCI attachment.
ATTACH_SBOM=${ATTACH_SBOM:-0}

SKIP_COSIGN=${SKIP_COSIGN:-0}
SKIP_GPG=${SKIP_GPG:-0}
SKIP_MINISIGN=${SKIP_MINISIGN:-0}

# Allow COSIGN=0 / GPG=0 / MINISIGN=0 toggles for quick opt-out.
if [ "${COSIGN:-1}" = "0" ]; then
	SKIP_COSIGN=1
	ATTACH_SBOM=0
fi
if [ "${GPG:-1}" = "0" ]; then
	SKIP_GPG=1
fi
if [ "${MINISIGN:-1}" = "0" ]; then
	SKIP_MINISIGN=1
fi

fail() {
	echo "❌ $*" >&2
	exit 1
}

need_cmd() {
	local cmd="$1"
	command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
}

gpg_cmd() {
	if [ -n "$GPG_HOMEDIR" ]; then
		env GNUPGHOME="$GPG_HOMEDIR" gpg "$@"
	else
		gpg "$@"
	fi
}

gpg_has_secret_key() {
	local key_id="$1"
	gpg_cmd --batch --with-colons --list-secret-keys "$key_id" 2>/dev/null | grep -q '^sec'
}

if [ ! -d "$DIR" ]; then
	fail "Directory not found: $DIR (run make release-download first)"
fi

VERSION=${TAG#v}

resolve_digest() {
	local image="$1"
	local ref="$REGISTRY/$OWNER/$image:$TAG"

	# This mirrors the existing Makefile release-digests logic.
	docker manifest inspect "$ref" -v 2>/dev/null |
		jq -r 'if type == "array" then .[0].Descriptor.digest else .config.digest end' 2>/dev/null
}

resolve_sbom_file() {
	local image="$1"
	local expected="$DIR/sbom-$image-$VERSION.json"

	if [ -f "$expected" ]; then
		echo "$expected"
		return 0
	fi

	# Fallback for slightly different naming (or multiple downloads).
	shopt -s nullglob
	local matches=("$DIR"/sbom-"$image"-*.json)
	shopt -u nullglob

	if [ ${#matches[@]} -eq 1 ]; then
		echo "${matches[0]}"
		return 0
	fi

	if [ ${#matches[@]} -eq 0 ]; then
		fail "SBOM not found for $image in $DIR (expected $expected)"
	fi

	fail "Multiple SBOMs found for $image in $DIR: ${matches[*]}"
}

attach_sbom() {
	local image="$1" digest="$2" sbom_file="$3"
	local ref="$REGISTRY/$OWNER/$image@$digest"

	echo "📎 cosign attach sbom: $ref"
	# NOTE: cosign upstream marks attach-sbom as deprecated.
	# We still use it for registry-native SBOM discovery convenience.
	cosign attach sbom --sbom "$sbom_file" --type spdx --input-format json "$ref"
}

sign_cosign() {
	local image="$1" digest="$2" sbom_file="$3"
	local ref="$REGISTRY/$OWNER/$image@$digest"

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "🔐 cosign: $ref"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

	cosign sign "$ref"
	cosign attest --predicate "$sbom_file" --type spdxjson "$ref"

	if [ "$ATTACH_SBOM" != "0" ]; then
		attach_sbom "$image" "$digest" "$sbom_file"
	fi
}

sign_gpg() {
	local checksum_file="$1"

	[ -n "$PGP_KEY_ID" ] || fail "PGP_KEY_ID is required for GPG signing"

	echo "🔏 [gpg] Signing $(basename "$checksum_file")"
	rm -f "${checksum_file}.asc"
	gpg_cmd --local-user "$PGP_KEY_ID" --detach-sign --armor -o "${checksum_file}.asc" "$checksum_file"
}

sign_minisign() {
	local checksum_file="$1" comment="$2"

	[ -n "$MINISIGN_KEY" ] || fail "MINISIGN_KEY is required for minisign signing"
	[ -f "$MINISIGN_KEY" ] || fail "MINISIGN_KEY not found: $MINISIGN_KEY"

	echo "🔏 [minisign] Signing $(basename "$checksum_file")"
	rm -f "${checksum_file}.minisig"
	minisign -S -s "$MINISIGN_KEY" -t "$comment" -m "$checksum_file"
}

# Preconditions / tooling checks
need_cmd jq
need_cmd docker

if [ "$SKIP_COSIGN" != "1" ] || [ "$ATTACH_SBOM" != "0" ]; then
	need_cmd cosign
fi

if [ "$SKIP_GPG" != "1" ]; then
	need_cmd gpg
fi

if [ "$SKIP_MINISIGN" != "1" ]; then
	need_cmd minisign
fi

# Ensure required assets exist for each image.
missing=0
for image in $IMAGES; do
	if [ ! -f "$DIR/SHA256SUMS-$image" ]; then
		echo "❌ Missing checksum file: $DIR/SHA256SUMS-$image" >&2
		missing=1
	fi
	if [ "$SKIP_COSIGN" != "1" ] || [ "$ATTACH_SBOM" != "0" ]; then
		if ! resolve_sbom_file "$image" >/dev/null; then
			missing=1
		fi
	fi
done

if [ $missing -ne 0 ]; then
	fail "Missing required release assets in $DIR (run make release-download first)"
fi

# Validate required env vars for enabled signing methods.
if [ "$SKIP_GPG" != "1" ] && [ -z "$PGP_KEY_ID" ]; then
	fail "PGP_KEY_ID is required (example: export PGP_KEY_ID='448A539320A397AF!')"
fi

if [ "$SKIP_MINISIGN" != "1" ] && [ -z "$MINISIGN_KEY" ]; then
	fail "MINISIGN_KEY is required (example: export MINISIGN_KEY=\"\$HOME/.minisign/minisign.key\")"
fi

if [ -n "$GPG_HOMEDIR" ]; then
	if [ ! -d "$GPG_HOMEDIR" ]; then
		fail "GPG_HOMEDIR is set but directory does not exist: $GPG_HOMEDIR"
	fi
fi

if [ "$SKIP_GPG" != "1" ]; then
	if ! gpg_has_secret_key "$PGP_KEY_ID"; then
		echo "" >&2
		echo "❌ No GPG secret key available for PGP_KEY_ID=$PGP_KEY_ID" >&2
		if [ -n "$GPG_HOMEDIR" ]; then
			echo "   Searched GPG_HOMEDIR=$GPG_HOMEDIR" >&2
		else
			echo "   Searched default GPG home (~/.gnupg)" >&2
			echo "   If you use multiple keyrings, set GPG_HOMEDIR to the right one." >&2
		fi
		echo "" >&2
		fail "GPG signing cannot proceed"
	fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Release signing preflight"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tag:      $TAG"
echo "Dir:      $DIR"
echo "Registry: $REGISTRY/$OWNER"
echo "Images:   $IMAGES"
echo ""
echo "Signing modes:"
if [ "$SKIP_COSIGN" != "1" ]; then
	echo "  - cosign: enabled (keyless sign+attest; may open browser)"
else
	echo "  - cosign: skipped (SKIP_COSIGN=1)"
fi
if [ "$ATTACH_SBOM" != "0" ]; then
	echo "  - sbom attach: enabled (registry write; no OIDC)"
else
	echo "  - sbom attach: skipped (ATTACH_SBOM=0)"
fi
if [ "$SKIP_GPG" != "1" ]; then
	if [ -n "$GPG_HOMEDIR" ]; then
		echo "  - gpg: enabled (PGP_KEY_ID=$PGP_KEY_ID, GPG_HOMEDIR=$GPG_HOMEDIR)"
	else
		echo "  - gpg: enabled (PGP_KEY_ID=$PGP_KEY_ID)"
	fi
else
	echo "  - gpg: skipped (SKIP_GPG=1)"
fi
if [ "$SKIP_MINISIGN" != "1" ]; then
	echo "  - minisign: enabled (MINISIGN_KEY=$MINISIGN_KEY)"
else
	echo "  - minisign: skipped (SKIP_MINISIGN=1)"
fi

echo ""
echo "Assets to be signed:"
for image in $IMAGES; do
	checksum_file="$DIR/SHA256SUMS-$image"
	echo "  - $image:"
	echo "    - checksum: $checksum_file"
	if [ "$SKIP_COSIGN" != "1" ] || [ "$ATTACH_SBOM" != "0" ]; then
		digest=$(resolve_digest "$image")
		if [ -z "$digest" ] || [ "$digest" = "null" ]; then
			fail "Unable to resolve digest for $image (need registry auth? waiting for push?)"
		fi
		sbom_file=$(resolve_sbom_file "$image")
		echo "    - digest:   $digest"
		echo "    - sbom:     $sbom_file"
		echo "    - ref:      $REGISTRY/$OWNER/$image@$digest"
	fi
done

# Cosign signing/attestation (interactive)
if [ "$SKIP_COSIGN" != "1" ]; then
	for image in $IMAGES; do
		digest=$(resolve_digest "$image")
		if [ -z "$digest" ] || [ "$digest" = "null" ]; then
			fail "Unable to resolve digest for $image (need registry auth? waiting for push?)"
		fi

		sbom_file=$(resolve_sbom_file "$image")
		sign_cosign "$image" "$digest" "$sbom_file"
	done
else
	echo "⚠️  SKIP_COSIGN=1 set; skipping cosign signing/attestation"
fi

# Checksum signing (GPG + minisign)
for image in $IMAGES; do
	checksum_file="$DIR/SHA256SUMS-$image"

	if [ "$SKIP_GPG" != "1" ]; then
		sign_gpg "$checksum_file"
	else
		echo "⚠️  SKIP_GPG=1 set; skipping GPG signing for $image"
	fi

	if [ "$SKIP_MINISIGN" != "1" ]; then
		sign_minisign "$checksum_file" "fulmen-toolbox $image $VERSION"
	else
		echo "⚠️  SKIP_MINISIGN=1 set; skipping minisign signing for $image"
	fi
done

echo ""
echo "✅ Release signing complete for $TAG"
echo "   Next: make verify-release-key && make release-upload RELEASE_TAG=$TAG"
