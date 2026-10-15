#!/usr/bin/env bash
# release-upload.sh - Upload signed release artifacts to GitHub
#
# Usage: ./scripts/release-upload.sh <tag> [dir]
#
# Checks that the manifests on the draft GitHub Release are the signed local
# copies, uploads signatures (.asc, .minisig) and public keys, downloads the
# release again and verifies it against the pin, and only then publishes it
# with docs/releases/<tag>.md as its notes. The
# release workflow creates the release as a draft; it becomes public only
# here, after make release-upload has verified the signatures.
# Run after manual signing is complete.

set -euo pipefail

TAG=${1:?"Usage: release-upload.sh <tag> [dir]"}
DIR=${2:-dist/release}

# GH: the gh command (tests substitute a stub).
GH=${GH:-gh}
if ! command -v "$GH" >/dev/null 2>&1; then
	echo "❌ gh CLI is required" >&2
	exit 1
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -d "$DIR" ]; then
	echo "❌ Directory $DIR not found" >&2
	exit 1
fi

# Collect files to upload
shopt -s nullglob
# Actual signatures (not public keys)
GPG_SIGS=("$DIR"/SHA256SUMS-*.asc)
MINISIG_SIGS=("$DIR"/SHA256SUMS-*.minisig)
PUBKEYS=("$DIR"/*-signing-key.asc "$DIR"/*-signing.pub)
RELEASE_NOTES=()
[ -f "$DIR/release-notes-$TAG.md" ] && RELEASE_NOTES=("$DIR/release-notes-$TAG.md")
shopt -u nullglob

# Validate that actual signatures exist (not just public keys)
missing=0
if [ ${#GPG_SIGS[@]} -eq 0 ]; then
	echo "❌ No GPG signatures (SHA256SUMS-*.asc) found in $DIR" >&2
	echo "   Run GPG signing first (per image):" >&2
	echo "   gpg --local-user \"\$FULMEN_TOOLBOX_PGP_KEY_ID\" --detach-sign --armor dist/release/SHA256SUMS-<image>" >&2
	missing=1
fi

if [ ${#MINISIG_SIGS[@]} -eq 0 ]; then
	echo "❌ No minisign signatures (SHA256SUMS-*.minisig) found in $DIR" >&2
	echo "   Run minisign signing first (per image):" >&2
	echo "   minisign -S -s \"\$FULMEN_TOOLBOX_MINISIGN_KEY\" -m dist/release/SHA256SUMS-<image>" >&2
	missing=1
fi

if [ $missing -ne 0 ]; then
	echo "" >&2
	echo "⚠️  Upload blocked: signatures required before upload" >&2
	echo "   See RELEASE_CHECKLIST.md Phase 2 for signing steps" >&2
	exit 1
fi

SIGNATURES=("${GPG_SIGS[@]}" "${MINISIG_SIGS[@]}")

# The signatures are for the local manifests. Before anything is uploaded,
# the manifests on the release must be those exact bytes.
shopt -s nullglob
MANIFESTS=()
for m in "$DIR"/SHA256SUMS-*; do
	case "$m" in *.asc | *.minisig) continue ;; esac
	MANIFESTS+=("$m")
done
shopt -u nullglob
REMOTE=$(mktemp -d "${TMPDIR:-/tmp}/release-upload.XXXXXX")
trap 'rm -rf "$REMOTE"' EXIT
echo "🔎 Comparing the release manifests with the signed local manifests..."
for m in "${MANIFESTS[@]}"; do
	name=${m##*/}
	"$GH" release download "$TAG" --pattern "$name" --dir "$REMOTE/before" ||
		{
			echo "❌ $name is not on release $TAG" >&2
			exit 1
		}
	cmp -s "$m" "$REMOTE/before/$name" ||
		{
			echo "❌ $name on release $TAG differs from the signed local copy; nothing uploaded" >&2
			exit 1
		}
done

echo "📤 Uploading signatures for ${TAG}..."
echo "   Files: ${SIGNATURES[*]}"
"$GH" release upload "$TAG" "${SIGNATURES[@]}" --clobber

if [ ${#PUBKEYS[@]} -gt 0 ]; then
	echo ""
	echo "📤 Uploading public keys..."
	echo "   Files: ${PUBKEYS[*]}"
	"$GH" release upload "$TAG" "${PUBKEYS[@]}" --clobber
else
	echo ""
	echo "⚠️  No public key files found (skipping)"
fi

# Optional: release notes as an uploaded asset
NOTES_REQUIRED=${FULMEN_TOOLBOX_RELEASE_NOTES_REQUIRED:-0}
if [ ${#RELEASE_NOTES[@]} -gt 0 ]; then
	echo ""
	echo "📤 Uploading release notes asset..."
	echo "   Files: ${RELEASE_NOTES[*]}"
	"$GH" release upload "$TAG" "${RELEASE_NOTES[@]}" --clobber
else
	if [ "$NOTES_REQUIRED" = "1" ]; then
		echo "" >&2
		echo "❌ Release notes required but not found" >&2
		echo "   Expected: $DIR/release-notes-$TAG.md" >&2
		echo "   Create: docs/releases/$TAG.md" >&2
		echo "   Stage: make release-notes FULMEN_TOOLBOX_RELEASE_TAG=$TAG" >&2
		exit 1
	fi
	echo ""
	echo "⚠️  No release notes asset found (skip)"
	echo "   To stage: make release-notes FULMEN_TOOLBOX_RELEASE_TAG=$TAG"
fi

# Re-download what is now on the release and verify it against the pin
# before publishing: the manifests, their signatures and the key assets.
echo ""
echo "🔎 Verifying the uploaded release against the pin before publishing..."
"$GH" release download "$TAG" --dir "$REMOTE/after" \
	--pattern 'SHA256SUMS-*' --pattern '*-signing-key.asc' --pattern '*-signing.pub' ||
	{
		echo "❌ cannot download release $TAG for verification; left as draft" >&2
		exit 1
	}
for m in "${MANIFESTS[@]}"; do
	name=${m##*/}
	for f in "$name" "$name.asc" "$name.minisig"; do
		cmp -s "$DIR/$f" "$REMOTE/after/$f" ||
			{
				echo "❌ $f on release $TAG differs from the verified local copy; left as draft" >&2
				exit 1
			}
	done
done
FULMEN_TOOLBOX_RELEASE_TRUST=pin bash "$ROOT/scripts/release-verify.sh" signatures "$TAG" "$REMOTE/after" ||
	{
		echo "❌ release $TAG does not verify against the pin; left as draft" >&2
		exit 1
	}

# Publish: notes from docs/releases/<tag>.md as the release description.
NOTES_FILE="$ROOT/docs/releases/$TAG.md"
[ -s "$NOTES_FILE" ] || {
	echo "❌ $NOTES_FILE is missing or empty; release $TAG left as draft" >&2
	exit 1
}
publish=(--draft=false --notes-file "$NOTES_FILE")
case "$TAG" in
*-*) publish+=(--prerelease --latest=false) ;;
*) publish+=(--latest) ;;
esac
echo ""
echo "🚀 Publishing release ${TAG}..."
"$GH" release edit "$TAG" "${publish[@]}"
state=$("$GH" release view "$TAG" --json isDraft --jq .isDraft) ||
	{
		echo "❌ cannot read release $TAG after publishing" >&2
		exit 1
	}
[ "$state" = "false" ] || {
	echo "❌ release $TAG is still a draft after publishing" >&2
	exit 1
}

echo ""
echo "✅ Release ${TAG} signed and published"
echo ""
echo "Verify with: gh release view ${TAG} --json assets -q '.assets[].name'"
