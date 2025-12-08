#!/usr/bin/env sh

# bump-version.sh
# Bump the repo VERSION file (semver). Usage: bump-version.sh [major|minor|patch]

set -eu

fail() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF' >&2
Usage: bump-version.sh [major|minor|patch]

Reads the VERSION file (default: ./VERSION), bumps the requested part, writes back.
Environment:
  VERSION_FILE: path to the version file (default: VERSION)
EOF
  exit 1
}

[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

PART=${1-}
[ -n "$PART" ] || usage

case "$PART" in
  major|minor|patch) ;;
  *) usage ;;
esac

VERSION_FILE=${VERSION_FILE:-VERSION}
[ -f "$VERSION_FILE" ] || fail "VERSION file not found at '$VERSION_FILE'"

CURRENT=$(tr -d ' \t\n\r' < "$VERSION_FILE")
printf '%s\n' "$CURRENT" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || fail "VERSION must be semver (e.g., 1.2.3), got '$CURRENT'"

IFS=. set -- $CURRENT
MAJOR=$1
MINOR=$2
PATCH=$3

case "$PART" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "$NEW_VERSION" > "$VERSION_FILE"
printf 'Version bumped: %s -> %s\n' "$CURRENT" "$NEW_VERSION"
