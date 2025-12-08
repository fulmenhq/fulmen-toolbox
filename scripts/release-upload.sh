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
SIGNATURES=("$DIR"/*.asc "$DIR"/*.minisig)
PUBKEYS=("$DIR"/*-signing-key.asc "$DIR"/*-signing.pub)
shopt -u nullglob

if [ ${#SIGNATURES[@]} -eq 0 ]; then
  echo "❌ No signature files (.asc, .minisig) found in $DIR" >&2
  exit 1
fi

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

echo ""
echo "✅ Release ${TAG} updated with signatures"
echo ""
echo "Verify with: gh release view ${TAG} --json assets -q '.assets[].name'"
