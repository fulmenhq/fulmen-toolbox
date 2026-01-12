#!/usr/bin/env bash

# test-subsystem-authentik-idp.sh
# Smoke test for subsystems/authentik-idp (non-browser, CI-friendly).

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/subsystems/authentik-idp"

if [ ! -d "$DIR" ]; then
	echo "subsystem directory not found: $DIR" >&2
	exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
	echo "docker is required to run subsystem smoke tests" >&2
	exit 1
fi

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

# docker compose reads .env automatically; the smoke test also needs these vars.
set -a
# shellcheck source=/dev/null
. ./.env
set +a

cleanup() {
	docker compose -f compose.yaml down -v >/dev/null 2>&1 || true
	rm -f .env >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Compose syntax validation

docker compose -f compose.yaml config --quiet

# Start

docker compose -f compose.yaml up -d --quiet-pull

# Wait for Authentik to respond

deadline=$((SECONDS + 420))
while :; do
	if curl -sf "http://127.0.0.1:${AUTHENTIK_HTTP_PORT:-9000}/-/health/ready/" >/dev/null; then
		break
	fi
	if [ "$SECONDS" -ge "$deadline" ]; then
		echo "timeout waiting for authentik ready health" >&2
		exit 1
	fi
	sleep 3

done

base="http://127.0.0.1:${AUTHENTIK_HTTP_PORT:-9000}"
slug="${OIDC_APP_SLUG:-test-app}"

# Wait for OIDC discovery (blueprint/app provisioning can lag DB readiness)

deadline=$((SECONDS + 420))
while :; do
	if curl -sf "$base/application/o/$slug/.well-known/openid-configuration" >/dev/null; then
		break
	fi
	if [ "$SECONDS" -ge "$deadline" ]; then
		echo "timeout waiting for OIDC discovery endpoint" >&2
		exit 1
	fi
	sleep 3

done

# OIDC discovery must be coherent

discovery=$(curl -sf "$base/application/o/$slug/.well-known/openid-configuration")

echo "$discovery" | jq -e '.issuer' >/dev/null
echo "$discovery" | jq -e '.authorization_endpoint' >/dev/null
echo "$discovery" | jq -e '.token_endpoint' >/dev/null
echo "$discovery" | jq -e '.jwks_uri' >/dev/null

echo "$discovery" | jq -e --arg expected "$base/application/o/$slug/" '.issuer == $expected' >/dev/null

jwks_uri=$(echo "$discovery" | jq -r '.jwks_uri')
curl -sf "$jwks_uri" | jq -e '.keys | length >= 1' >/dev/null

# Validate fixture provisioning via Postgres (avoids reliance on upstream bootstrap token behavior)

pg_container=$(docker compose -f compose.yaml ps -q postgres)
if [ -z "$pg_container" ]; then
	echo "unable to resolve postgres container" >&2
	exit 1
fi

# Users from blueprint
users_count=$(docker exec "$pg_container" sh -c "PGPASSWORD='$PG_PASS' psql -U authentik -d authentik -Atc \"select count(*) from authentik_core_user where username in ('alice','bob');\"")
[ "$users_count" -eq 2 ]

# Groups from blueprint
groups_count=$(docker exec "$pg_container" sh -c "PGPASSWORD='$PG_PASS' psql -U authentik -d authentik -Atc \"select count(*) from authentik_core_group where name in ('developers','admins');\"")
[ "$groups_count" -eq 2 ]

# Application + provider from blueprint
app_count=$(docker exec "$pg_container" sh -c "PGPASSWORD='$PG_PASS' psql -U authentik -d authentik -Atc \"select count(*) from authentik_core_application where slug = '$slug';\"")
[ "$app_count" -ge 1 ]

provider_count=$(docker exec "$pg_container" sh -c "PGPASSWORD='$PG_PASS' psql -U authentik -d authentik -Atc \"select count(*) from authentik_providers_oauth2_oauth2provider where client_id = '$OIDC_CLIENT_ID';\"")
[ "$provider_count" -ge 1 ]
