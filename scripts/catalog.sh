#!/usr/bin/env bash
# catalog.sh
# Generate a human-readable inventory of what each image variant includes.
#
# Output is derived from manifests (SSOT) and is intended for local use.
# Recommended output path: dist/catalog/ (gitignored).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_JSON="$ROOT/manifests/tools.json"
PROFILES_JSON="$ROOT/manifests/profiles.json"

if [ ! -f "$TOOLS_JSON" ]; then
  echo "tools manifest missing: $TOOLS_JSON" >&2
  exit 1
fi

if [ ! -f "$PROFILES_JSON" ]; then
  echo "profiles manifest missing: $PROFILES_JSON" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to generate catalog" >&2
  exit 1
fi

image_filter=""

usage() {
  cat <<'EOF'
Usage:
  scripts/catalog.sh [--image <image-name>]

Examples:
  scripts/catalog.sh
  scripts/catalog.sh --image goneat-tools-runner
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --image)
      image_filter="${2:-}"
      if [ -z "$image_filter" ]; then
        echo "--image requires a value" >&2
        usage
        exit 2
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

images=()
while IFS= read -r img; do
  images+=("$img")
done < <(jq -r '.tools[].images[]' "$TOOLS_JSON" | sort -u)

profile_for_image() {
  case "$1" in
    *-runner-glibc) echo "runner_baseline_apt" ;;
    *) echo "runner_baseline" ;;
  esac
}

if [ -n "$image_filter" ]; then
  found=0
  for img in "${images[@]}"; do
    if [ "$img" = "$image_filter" ]; then
      found=1
      break
    fi
  done

  if [ $found -ne 1 ]; then
    echo "Unknown image in manifest: $image_filter" >&2
    echo "Known images:" >&2
    printf '  - %s\n' "${images[@]}" >&2
    exit 2
  fi

  images=("$image_filter")
fi

cat <<'EOF'
# Fulmen Toolbox Image Catalog (generated)

This file is generated from the manifest SSOT:

- `manifests/tools.json` (curated tools and pinned versions)
- `manifests/profiles.json` (runner baseline package policy)

Notes:

- This output is intended for local/operator use (write it under `dist/`, which is gitignored).
- For definitive, artifact-level truth, prefer the per-release SBOM assets published on GitHub Releases.
EOF

echo

for image in "${images[@]}"; do
  echo "## $image"
  echo
  echo "### Curated tools (from manifests/tools.json)"
  echo
  echo "| Name | Version | Source |"
  echo "| --- | --- | --- |"

  # Use tab-separated output then render as markdown.
  jq -r --arg img "$image" '.tools[] | select(.images | index($img)) | [.name, .version, .source] | @tsv' "$TOOLS_JSON" \
    | sort -u \
    | while IFS=$'\t' read -r name version source; do
        printf "| \`%s\` | \`%s\` | \`%s\` |\n" "$name" "$version" "$source"
      done

  echo

  if [[ "$image" == *-runner* ]]; then
    profile="$(profile_for_image "$image")"
    echo "### Runner baseline packages (policy; from manifests/profiles.json)"
    echo
    jq -r --arg profile "$profile" '.profiles[$profile].packages[]' "$PROFILES_JSON" | sort -u | while IFS= read -r pkg; do
      printf -- "- \`%s\`\n" "$pkg"
    done
    echo
  fi

done
