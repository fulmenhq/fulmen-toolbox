#!/usr/bin/env bash
# release-download.sh - Download release artifacts from GitHub for manual signing
#
# Usage: ./scripts/release-download.sh <tag> [dest_dir]
#
# Downloads SHA256SUMS and SBOM files from GitHub Release for local signing.

set -euo pipefail

TAG=${1:?"Usage: release-download.sh <tag> [dest_dir]"}
DEST=${2:-dist/release}

if ! command -v gh >/dev/null 2>&1; then
  echo "❌ gh CLI is required (https://cli.github.com)" >&2
  exit 1
fi

mkdir -p "$DEST"

echo "⬇️  Downloading release artifacts for ${TAG} into ${DEST}"
gh release download "$TAG" --dir "$DEST" --clobber \
  --pattern 'SHA256SUMS*' \
  --pattern 'sbom-*'

echo ""
echo "✅ Assets downloaded to $DEST:"
ls -la "$DEST"
