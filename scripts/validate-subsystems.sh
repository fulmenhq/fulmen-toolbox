#!/usr/bin/env sh

# validate-subsystems.sh
# Validate subsystems/*/MANIFEST.yaml against schemas/subsystem-manifest.schema.json
# and ensure each subsystem's compose.yaml is syntactically valid.
#
# Notes:
# - MANIFEST.yaml is YAML; we convert it to JSON inside a dockerized node runtime.
# - We deliberately avoid relying on host-side node/npm.

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA="$ROOT/schemas/subsystem-manifest.schema.json"
SUBSYSTEMS_DIR="$ROOT/subsystems"

if [ ! -f "$SCHEMA" ]; then
	echo "subsystem manifest schema missing: $SCHEMA" >&2
	exit 1
fi

if [ ! -d "$SUBSYSTEMS_DIR" ]; then
	echo "subsystems directory missing: $SUBSYSTEMS_DIR" >&2
	exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
	echo "docker is required to validate subsystems" >&2
	exit 1
fi

compose() {
	if docker compose version >/dev/null 2>&1; then
		docker compose "$@"
		return
	fi
	if command -v docker-compose >/dev/null 2>&1; then
		docker-compose "$@"
		return
	fi
	echo "docker compose is required (install Docker Compose v2 plugin or docker-compose v1)" >&2
	exit 1
}

SUBSYSTEM_FILTER="${1:-}"

if [ -n "$SUBSYSTEM_FILTER" ]; then
	if [ ! -d "$SUBSYSTEMS_DIR/$SUBSYSTEM_FILTER" ]; then
		echo "unknown subsystem: $SUBSYSTEM_FILTER" >&2
		exit 1
	fi
fi

# Basic structural validation (host-side)
# Note: iterate over glob directly to avoid SC2125 (glob literal in assignment)
for dir in "$SUBSYSTEMS_DIR"/*; do
	# Skip if filtering to a specific subsystem
	if [ -n "$SUBSYSTEM_FILTER" ] && [ "$(basename "$dir")" != "$SUBSYSTEM_FILTER" ]; then
		continue
	fi
	[ -d "$dir" ] || continue
	name="$(basename "$dir")"
	manifest="$dir/MANIFEST.yaml"
	readme="$dir/README.md"
	compose="$dir/compose.yaml"
	presets_dir="$dir/presets"

	if [ ! -f "$manifest" ]; then
		echo "$name: missing MANIFEST.yaml" >&2
		exit 1
	fi
	if [ ! -f "$readme" ]; then
		echo "$name: missing README.md" >&2
		exit 1
	fi
	if [ ! -f "$compose" ]; then
		echo "$name: missing compose.yaml" >&2
		exit 1
	fi
	if [ ! -d "$presets_dir" ]; then
		echo "$name: missing presets/ directory" >&2
		exit 1
	fi

	# Compose syntax validation
	# Use the dev-fixture preset to satisfy required env vars during interpolation.
	env_file="$dir/presets/dev-fixture.env"
	if [ -f "$env_file" ]; then
		compose --env-file "$env_file" -f "$compose" config --quiet
	else
		compose -f "$compose" config --quiet
	fi

done

# Schema validation (dockerized)
# Convert each MANIFEST.yaml to JSON, then validate with ajv.
docker run --rm -v "$ROOT:/work" node:22-alpine sh -c '
  set -eu

  mkdir -p /tmp/subsystem-validate
  cd /tmp/subsystem-validate

  npm init -y >/dev/null 2>&1
  npm install ajv-cli@5 js-yaml@4 >/dev/null 2>&1

  AJV=./node_modules/.bin/ajv

  filter="'"$SUBSYSTEM_FILTER"'"
  if [ -n "$filter" ]; then
    dirs="/work/subsystems/$filter"
  else
    dirs="/work/subsystems/*"
  fi

  for dir in $dirs; do
    [ -d "$dir" ] || continue
    manifest="$dir/MANIFEST.yaml"
    tmp_json="/tmp/subsystem-validate/manifest.json"

    # Convert YAML -> JSON (file), then validate.
    node -e "const fs=require(\"fs\"); const yaml=require(\"js-yaml\"); const doc=yaml.load(fs.readFileSync(process.argv[1],\"utf8\")); fs.writeFileSync(process.argv[2], JSON.stringify(doc));" "$manifest" "$tmp_json"

    "$AJV" validate --spec=draft2020 -s /work/schemas/subsystem-manifest.schema.json -d "$tmp_json"
  done
'
