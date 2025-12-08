# ADR-0001-versioning

- Status: Accepted
- Date: 2025-12-07

## Context
Tool images need predictable upgrade semantics and compatibility signals. Users expect to know whether an update is safe for existing workflows, while also seeing freshness.

## Decision
- Use semver as the primary scheme. Major = breaking defaults/tool changes; Minor = additive; Patch = non-breaking fixes/rebuilds/security bumps.
- Maintain `VERSION` at repo root as the single source of truth; Docker tags derive from it (`:<semver>`, `:v<major>`, `:latest`).
- Optionally publish a calver alias per release for freshness signaling; it does not replace semver.

## Consequences
- Compatibility expectations are clear for consumers.
- Bump policy is explicit and automated via bump targets/scripts.
- Release docs and CI must read from `VERSION` to stay consistent.
