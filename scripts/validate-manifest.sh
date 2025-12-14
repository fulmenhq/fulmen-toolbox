#!/usr/bin/env sh

# validate-manifest.sh
# Validate manifests/*.json against schemas/*.schema.json using ajv (via Docker).

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL_SCHEMA="$ROOT/schemas/tool-manifest.schema.json"
TOOL_DATA="$ROOT/manifests/tools.json"
PROFILE_SCHEMA="$ROOT/schemas/profile-manifest.schema.json"
PROFILE_DATA="$ROOT/manifests/profiles.json"

if [ ! -f "$TOOL_SCHEMA" ] || [ ! -f "$TOOL_DATA" ]; then
  echo "tool schema or manifest missing" >&2
  exit 1
fi

if [ ! -f "$PROFILE_SCHEMA" ] || [ ! -f "$PROFILE_DATA" ]; then
  echo "profile schema or manifest missing" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to run validator" >&2
  exit 1
fi

docker run --rm -v "$ROOT:/work" -w /work node:22-alpine sh -c "\
  npm install -g ajv-cli@5 >/dev/null 2>&1 && \
  ajv validate --spec=draft2020 -s schemas/tool-manifest.schema.json -d manifests/tools.json && \
  ajv validate --spec=draft2020 -s schemas/profile-manifest.schema.json -d manifests/profiles.json"
