#!/usr/bin/env bash
# validate-licenses.sh
# Build images (single-arch) and assert curated license/notice paths exist.
#
# Source of truth: manifests/tools.json fields:
# - license_path (required for automated checks)
# - notice_required / notice_path (optional)
#
# We only enforce for tools that declare `license_path`.
# This avoids pretending we fully track all transitive deps.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/manifests/tools.json"

if [ ! -f "$MANIFEST" ]; then
  echo "Manifest not found: $MANIFEST" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to validate licenses" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to validate licenses" >&2
  exit 1
fi

# Map canonical image name -> docker build target + family path.
family_for_image() {
  case "$1" in
    goneat-tools-slim|goneat-tools-runner) echo "goneat-tools" ;;
    sbom-tools-slim|sbom-tools-runner) echo "sbom-tools" ;;
    *) return 1 ;;
  esac
}

target_for_image() {
  case "$1" in
    *-slim) echo "slim" ;;
    *-runner) echo "runner" ;;
    *) return 1 ;;
  esac
}

# Build once per image and validate all declared paths.
validate_image() {
  local image="$1"
  local family target tag

  family="$(family_for_image "$image")"
  target="$(target_for_image "$image")"
  tag="fulmen-toolbox/${image}:validate"

  echo "==> Building ${image} (${target})"
  docker build --target "$target" -t "$tag" "$ROOT/images/$family" >/dev/null

  echo "==> Validating license/notice paths in ${image}"

  # Collect checks for this image
  local checks_json
  checks_json=$(jq -c --arg image "$image" '
    [
      .tools[]
      | select((.images | index($image)) != null)
      | select((.license_path? != null) or (.license_paths? != null))
      | {
          name,
          license_path: (.license_path // ""),
          license_paths: (.license_paths // []),
          notice_required: (.notice_required // false),
          notice_path: (.notice_path // "")
        }
    ]
  ' "$MANIFEST")

  local count
  count=$(jq -r 'length' <<<"$checks_json")
  if [ "$count" -eq 0 ]; then
    echo "⚠️  no curated license checks for ${image} (no license_path entries)"
    return 0
  fi

  # Always require base dirs
  docker run --rm "$tag" -c "test -d /licenses && test -d /notices" >/dev/null

  while IFS= read -r item; do
    local name license_path notice_required notice_path
    name=$(jq -r '.name' <<<"$item")
    license_path=$(jq -r '.license_path' <<<"$item")
    notice_required=$(jq -r '.notice_required' <<<"$item")
    notice_path=$(jq -r '.notice_path' <<<"$item")

    if [ -n "$license_path" ]; then
      docker run --rm "$tag" -c "test -f '$license_path'" >/dev/null || {
        echo "❌ missing license for ${image}: ${name} (${license_path})" >&2
        return 1
      }
    else
      while IFS= read -r lp; do
        docker run --rm "$tag" -c "test -f '$lp'" >/dev/null || {
          echo "❌ missing license for ${image}: ${name} (${lp})" >&2
          return 1
        }
      done < <(jq -r '.license_paths[]' <<<"$item")
    fi

    if [ "$notice_required" = "true" ]; then
      if [ -z "$notice_path" ]; then
        echo "❌ notice_required=true but notice_path empty for ${image}: ${name}" >&2
        return 1
      fi
      docker run --rm "$tag" -c "test -f '$notice_path'" >/dev/null || {
        echo "❌ missing NOTICE for ${image}: ${name} (${notice_path})" >&2
        return 1
      }
    fi
  done < <(jq -c '.[]' <<<"$checks_json")

  echo "✅ ${image} license checks passed"
}

images=$(jq -r '[.tools[].images[]] | unique | .[]' "$MANIFEST")

fail=0
while IFS= read -r image; do
  # Only validate images we know how to build.
  if ! family_for_image "$image" >/dev/null 2>&1; then
    continue
  fi

  if ! validate_image "$image"; then
    fail=1
  fi
done <<<"$images"

if [ "$fail" -ne 0 ]; then
  echo "License validation failed." >&2
  exit 1
fi

echo "All license validations passed."
