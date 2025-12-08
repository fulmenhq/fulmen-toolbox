#!/usr/bin/env sh

# validate-manifest.sh
# Validate manifests/tools.json against schemas/tool-manifest.schema.json using ajv (via Docker).

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA="$ROOT/schemas/tool-manifest.schema.json"
DATA="$ROOT/manifests/tools.json"

if [ ! -f "$SCHEMA" ] || [ ! -f "$DATA" ]; then
  echo "schema or manifest missing" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to run validator" >&2
  exit 1
fi

docker run --rm -v "$ROOT:/work" -w /work node:22-alpine sh -c "\
  npm install -g ajv-cli@5 >/dev/null 2>&1 && \
  ajv validate --spec=draft2020 -s schemas/tool-manifest.schema.json -d manifests/tools.json"
