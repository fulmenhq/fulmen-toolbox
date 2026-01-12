# authentik-idp

Authentik identity provider subsystem used as:

- A working **enterprise-style IdP fixture** for auth-backed middleware/proxy development.
- A reusable local IdP for small internal deployments.

## Quick Start (Dev Fixture)

From the repo root:

```bash
cp subsystems/authentik-idp/presets/dev-fixture.env subsystems/authentik-idp/.env
docker compose -f subsystems/authentik-idp/compose.yaml up -d

curl -sf "http://127.0.0.1:${AUTHENTIK_HTTP_PORT:-9000}/-/health/ready/" >/dev/null
curl -sf "http://127.0.0.1:${AUTHENTIK_HTTP_PORT:-9000}/application/o/${OIDC_APP_SLUG:-test-app}/.well-known/openid-configuration" | jq -r .issuer

docker compose -f subsystems/authentik-idp/compose.yaml down -v
```

From the subsystem directory:

```bash
cd subsystems/authentik-idp
cp presets/dev-fixture.env .env
docker compose up -d

curl -sf "http://127.0.0.1:${AUTHENTIK_HTTP_PORT:-9000}/-/health/ready/" >/dev/null
curl -sf "http://127.0.0.1:${AUTHENTIK_HTTP_PORT:-9000}/application/o/${OIDC_APP_SLUG:-test-app}/.well-known/openid-configuration" | jq -r .issuer

docker compose down -v
```

## Smoke Test Contract

See `docs/standards/subsystem-standard.md` and `.plans/active/v0.3.1/subsystems/README.md` for the current CI contract.

## Notes

- Blueprint is mounted into the worker container at `/blueprints/custom/fulmen-fixture.yaml` (preserves Authentik default blueprints).
- Blueprint ordering is not guaranteed upstream; this subsystem uses a single self-contained blueprint.
- The `dev-fixture` preset uses known credentials and must not be used for production.
