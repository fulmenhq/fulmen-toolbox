#!/usr/bin/env bash

# test-subsystem-echo-proxy-fixture.sh
# Fast smoke test for subsystems/echo-proxy-fixture.

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/subsystems/echo-proxy-fixture"

if [ ! -d "$DIR" ]; then
	echo "subsystem directory not found: $DIR" >&2
	exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
	echo "docker is required to run subsystem smoke tests" >&2
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

if ! command -v curl >/dev/null 2>&1; then
	echo "curl is required to run subsystem smoke tests" >&2
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	echo "jq is required to run subsystem smoke tests" >&2
	exit 1
fi

cd "$DIR"

cp presets/dev-fixture.env .env

cleanup() {
	compose -f compose.yaml down -v >/dev/null 2>&1 || true
	rm -f .env >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Basic compose validation

compose -f compose.yaml config --quiet

# Start

compose -f compose.yaml up -d --quiet-pull

# Wait for proxy health
deadline=$((SECONDS + 30))
while :; do
	if curl -sf "http://127.0.0.1:${PROXY_PORT:-8080}/health" >/dev/null; then
		break
	fi
	if [ "$SECONDS" -ge "$deadline" ]; then
		echo "timeout waiting for proxy health" >&2
		exit 1
	fi
	sleep 2

done

# Proxy routes to echo, and nginx injects identifying header
resp=$(curl -sf "http://127.0.0.1:${PROXY_PORT:-8080}/")
echo "$resp" | jq -e 'tostring | test("x-fulmen-proxy"; "i")' >/dev/null
echo "$resp" | jq -e 'tostring | test("echo-proxy-fixture"; "i")' >/dev/null
