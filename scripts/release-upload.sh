#!/usr/bin/env bash
# release-upload.sh - Upload signed release artifacts to GitHub
#
# Usage: ./scripts/release-upload.sh <tag> [dir]
#
# Uploads signatures (.asc, .minisig) and public keys to GitHub Release.
# Run after manual signing is complete.

set -euo pipefail

TAG=${1:?"Usage: release-upload.sh <tag> [dir]"}
DIR=${2:-dist/release}

if ! command -v gh >/dev/null 2>&1; then
  echo "❌ gh CLI is required" >&2
  exit 1
fi

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
RELEASE_NOTES=("$DIR"/release-notes-"$TAG".md)
shopt -u nullglob

# Validate that actual signatures exist (not just public keys)
missing=0
if [ ${#GPG_SIGS[@]} -eq 0 ]; then
  echo "❌ No GPG signatures (SHA256SUMS-*.asc) found in $DIR" >&2
  echo "   Run GPG signing first (per image):" >&2
  echo "   gpg --local-user \"\$PGP_KEY_ID\" --detach-sign --armor dist/release/SHA256SUMS-<image>" >&2
  missing=1
fi

if [ ${#MINISIG_SIGS[@]} -eq 0 ]; then
  echo "❌ No minisign signatures (SHA256SUMS-*.minisig) found in $DIR" >&2
  echo "   Run minisign signing first (per image):" >&2
  echo "   minisign -S -s \"\$MINISIGN_KEY\" -m dist/release/SHA256SUMS-<image>" >&2
  missing=1
fi

if [ $missing -ne 0 ]; then
  echo "" >&2
  echo "⚠️  Upload blocked: signatures required before upload" >&2
  echo "   See RELEASE_CHECKLIST.md Phase 2 for signing steps" >&2
  exit 1
fi

SIGNATURES=("${GPG_SIGS[@]}" "${MINISIG_SIGS[@]}")

echo "📤 Uploading signatures for ${TAG}..."
echo "   Files: ${SIGNATURES[*]}"
gh release upload "$TAG" "${SIGNATURES[@]}" --clobber

if [ ${#PUBKEYS[@]} -gt 0 ]; then
  echo ""
  echo "📤 Uploading public keys..."
  echo "   Files: ${PUBKEYS[*]}"
  gh release upload "$TAG" "${PUBKEYS[@]}" --clobber
else
  echo ""
  echo "⚠️  No public key files found (skipping)"
fi

# Optional: release notes as an uploaded asset
NOTES_REQUIRED=${RELEASE_NOTES_REQUIRED:-0}
if [ ${#RELEASE_NOTES[@]} -gt 0 ]; then
  echo ""
  echo "📤 Uploading release notes asset..."
  echo "   Files: ${RELEASE_NOTES[*]}"
  gh release upload "$TAG" "${RELEASE_NOTES[@]}" --clobber
else
  if [ "$NOTES_REQUIRED" = "1" ]; then
    echo "" >&2
    echo "❌ Release notes required but not found" >&2
    echo "   Expected: $DIR/release-notes-$TAG.md" >&2
    echo "   Create: docs/releases/$TAG.md" >&2
    echo "   Stage: make release-notes RELEASE_TAG=$TAG" >&2
    exit 1
  fi
  echo ""
  echo "⚠️  No release notes asset found (skip)"
  echo "   To stage: make release-notes RELEASE_TAG=$TAG"
fi

echo ""
echo "✅ Release ${TAG} updated with signatures"
echo ""
echo "Verify with: gh release view ${TAG} --json assets -q '.assets[].name'"
