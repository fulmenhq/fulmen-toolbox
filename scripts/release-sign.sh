#!/usr/bin/env bash
# release-sign.sh - Sign the per-image checksum manifests of a release with
# PGP and minisign.
#
# Usage: ./scripts/release-sign.sh <tag> [dir]
#
# Examples:
#   export FULMEN_TOOLBOX_RELEASE_TAG=v0.5.10
#   export FULMEN_TOOLBOX_PGP_KEY_ID='DAB70DD758911B26BB45A08C3B75AC591449DEBE!'
#   export FULMEN_TOOLBOX_MINISIGN_KEY="$HOME/.minisign/minisign.key"
#   make release-download FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG
#   make release-sign FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG
#
# Environment variables:
#   FULMEN_TOOLBOX_PGP_KEY_ID    - PGP signing key selector (required)
#   FULMEN_TOOLBOX_GPG_HOMEDIR   - GPG home directory holding the secret key (optional)
#   FULMEN_TOOLBOX_MINISIGN_KEY  - minisign secret key; its public key must sit
#                                  next to it as <name>.pub (required)
#   FULMEN_TOOLBOX_IMAGES        - space-delimited images (default: manifests/tools.json)
#   FULMEN_TOOLBOX_RELEASE_PIN_REF - pin ref override (see release-verify.sh)
#
# Before any existing signature is touched, the operator keys must be the
# release-key pin committed at the tag: the PGP selector must resolve to the
# pinned primary and sign with the pinned signing subkey, and the minisign
# public key must match its anchor. Signatures are written to a staging
# directory, verified there against the pin with release-verify.sh, and only
# then moved into <dir>.
#
# Images are signed with keyless cosign by the release workflow, not here.
# This script does NOT upload anything; use make release-upload afterwards.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

TAG=${1:?"Usage: release-sign.sh <tag> [dir]"}
DIR=${2:-dist/release}

# Derive image list from manifest unless explicitly overridden.
IMAGES=${FULMEN_TOOLBOX_IMAGES:-"$(bash "$ROOT/scripts/list-images.sh" --format space)"}
IMAGES=$(printf '%s' "$IMAGES" | tr '\n' ' ' | xargs)

PGP_KEY_ID=${FULMEN_TOOLBOX_PGP_KEY_ID:-}
GPG_HOMEDIR=${FULMEN_TOOLBOX_GPG_HOMEDIR:-}
MINISIGN_KEY=${FULMEN_TOOLBOX_MINISIGN_KEY:-}
VERSION=${TAG#v}

fail() {
	echo "❌ $*" >&2
	exit 1
}

need_cmd() {
	command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

gpg_cmd() {
	if [ -n "$GPG_HOMEDIR" ]; then
		env GNUPGHOME="$GPG_HOMEDIR" gpg "$@"
	else
		gpg "$@"
	fi
}

need_cmd gpg
need_cmd minisign
need_cmd git

[ -d "$DIR" ] || fail "Directory not found: $DIR (run make release-download first)"
[ -n "$PGP_KEY_ID" ] || fail "FULMEN_TOOLBOX_PGP_KEY_ID is required"
[ -n "$MINISIGN_KEY" ] || fail "FULMEN_TOOLBOX_MINISIGN_KEY is required"
[ -f "$MINISIGN_KEY" ] || fail "FULMEN_TOOLBOX_MINISIGN_KEY not found: $MINISIGN_KEY"
MINISIGN_PUB="${MINISIGN_KEY%.key}.pub"
[ -f "$MINISIGN_PUB" ] || fail "minisign public key not found next to the secret key: $MINISIGN_PUB"
if [ -n "$GPG_HOMEDIR" ] && [ ! -d "$GPG_HOMEDIR" ]; then
	fail "FULMEN_TOOLBOX_GPG_HOMEDIR does not exist: $GPG_HOMEDIR"
fi

for image in $IMAGES; do
	[ -f "$DIR/SHA256SUMS-$image" ] || fail "Missing checksum file: $DIR/SHA256SUMS-$image (run make release-download first)"
done

# ── Preflight: the operator keys must be the pinned keys ──────────────────
# Read the pin the same way release-verify.sh does (git objects at the tag).
PIN=$(FULMEN_TOOLBOX_RELEASE_TRUST=pin bash "$ROOT/scripts/release-verify.sh" pin "$TAG") ||
	fail "cannot read the release-key pin for $TAG"
PIN_PRIMARY=$(printf '%s\n' "$PIN" | sed -n 's/.*pgp primary \([0-9A-F]\{40\}\),.*/\1/p')
PIN_SUBKEY=$(printf '%s\n' "$PIN" | sed -n 's/.*signing subkey \([0-9A-F]\{40\}\),.*/\1/p')
PIN_MINI=$(printf '%s\n' "$PIN" | sed -n 's/.*minisign key \([0-9a-f]\{64\}\).*/\1/p')
[ -n "$PIN_PRIMARY" ] && [ -n "$PIN_SUBKEY" ] && [ -n "$PIN_MINI" ] || fail "cannot parse the release-key pin"

# The selector must resolve to exactly one key, the pinned primary, with a
# usable secret for the pinned signing subkey.
records=$(gpg_cmd --batch --with-colons --with-subkey-fingerprint --list-secret-keys "${PGP_KEY_ID%!}" 2>/dev/null) ||
	fail "No GPG secret key for FULMEN_TOOLBOX_PGP_KEY_ID=$PGP_KEY_ID${GPG_HOMEDIR:+ in $GPG_HOMEDIR}"
[ "$(awk -F: '$1 == "sec"' <<<"$records" | wc -l | tr -d ' ')" = "1" ] ||
	fail "FULMEN_TOOLBOX_PGP_KEY_ID=$PGP_KEY_ID must select exactly one key"
primary=$(awk -F: '$1 == "fpr" { print $10; exit }' <<<"$records")
[ "$primary" = "$PIN_PRIMARY" ] ||
	fail "FULMEN_TOOLBOX_PGP_KEY_ID selects $primary, not the pinned primary $PIN_PRIMARY"
grep -q "^fpr:::::::::${PIN_SUBKEY}:" <<<"$records" ||
	fail "the selected key has no pinned signing subkey $PIN_SUBKEY"
# A full fingerprint selector other than the primary must be the pinned subkey.
selector=$(printf '%s' "${PGP_KEY_ID%!}" | tr '[:lower:]' '[:upper:]')
if [[ "$selector" =~ ^[0-9A-F]{40}$ ]] && [ "$selector" != "$PIN_PRIMARY" ] && [ "$selector" != "$PIN_SUBKEY" ]; then
	fail "FULMEN_TOOLBOX_PGP_KEY_ID=$PGP_KEY_ID is not the pinned signing subkey $PIN_SUBKEY"
fi

mini=$(sed -n 2p "$MINISIGN_PUB" | base64 -d 2>/dev/null | { shasum -a 256 2>/dev/null || sha256sum; } | awk '{print $1}')
[ "$mini" = "$PIN_MINI" ] || fail "minisign key $MINISIGN_PUB is not the pinned minisign key"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Release signing preflight"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tag:      $TAG"
echo "Dir:      $DIR"
echo "Images:   $IMAGES"
echo "PGP:      pinned primary $PIN_PRIMARY, signing subkey $PIN_SUBKEY"
echo "minisign: pinned key $PIN_MINI"

# ── Sign into a staging directory ─────────────────────────────────────────
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/release-sign.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
for image in $IMAGES; do
	cp "$DIR/SHA256SUMS-$image" "$STAGE/"
done

for image in $IMAGES; do
	m="$STAGE/SHA256SUMS-$image"
	echo "🔏 [gpg] Signing SHA256SUMS-$image"
	gpg_cmd --local-user "${PIN_SUBKEY}!" --detach-sign --armor -o "$m.asc" "$m"
	echo "🔏 [minisign] Signing SHA256SUMS-$image"
	minisign -S -s "$MINISIGN_KEY" -t "fulmen-toolbox $image $VERSION" -m "$m"
done

# ── Verify the staged signatures against the pin, then promote ────────────
# Always against the pin: an environment trust override left over from
# rotation testing must not decide what gets promoted.
FULMEN_TOOLBOX_RELEASE_TRUST=pin bash "$ROOT/scripts/release-verify.sh" signatures "$TAG" "$STAGE" ||
	fail "staged signatures do not verify against the pin; $DIR is unchanged"

for image in $IMAGES; do
	for ext in asc minisig; do
		mv -f "$STAGE/SHA256SUMS-$image.$ext" "$DIR/SHA256SUMS-$image.$ext"
	done
done

echo ""
echo "✅ Release signing complete for $TAG"
echo "   Next: make release-upload FULMEN_TOOLBOX_RELEASE_TAG=$TAG  (exports keys and verifies signatures first)"
