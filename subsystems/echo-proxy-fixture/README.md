# echo-proxy-fixture

A minimal evaluation-scale subsystem used to validate the **subsystem mechanics** (manifest schema, compose conventions, mounted config, smoke testing) with fast feedback.

## Quick Start

From the repo root:

```bash
cp subsystems/echo-proxy-fixture/presets/dev-fixture.env subsystems/echo-proxy-fixture/.env
docker compose -f subsystems/echo-proxy-fixture/compose.yaml up -d
curl -sf "http://127.0.0.1:${PROXY_PORT:-8080}/health"
curl -sf "http://127.0.0.1:${PROXY_PORT:-8080}/"
docker compose -f subsystems/echo-proxy-fixture/compose.yaml down -v
```

From the subsystem directory:

```bash
cd subsystems/echo-proxy-fixture
cp presets/dev-fixture.env .env
docker compose up -d
curl -sf "http://127.0.0.1:${PROXY_PORT:-8080}/health"
curl -sf "http://127.0.0.1:${PROXY_PORT:-8080}/"
docker compose down -v
```

## Checks-Enabled Variant (Probe Container)

To validate readiness mechanics without relying on tooling inside upstream images, run the probe overlay:

```bash
cd subsystems/echo-proxy-fixture
cp presets/dev-fixture.env .env
docker compose -f compose.yaml -f compose.with-checks.yaml up -d

# Probe runs in-container checks of proxy+echo reachability
docker compose ps
```

The nginx config injects `X-Fulmen-Proxy: echo-proxy-fixture` into proxied requests. The echo backend reflects this in its response, which lets smoke tests prove requests passed through nginx.

## Smoke Test Contract

See `docs/standards/subsystem-standard.md` for the current smoke test contract used by CI.
