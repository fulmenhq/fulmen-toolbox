# Secrets

This subsystem supports mounting secrets at `/secrets` (worker container only).

By default, the `dev-fixture` preset uses explicit environment values (NOT FOR PRODUCTION).

For production-ish presets, place secret files here and reference them from configuration where supported.
