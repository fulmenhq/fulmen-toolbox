# Ops Runbook: CI Cosign Signing (OIDC, Non-Interactive)

This runbook defines the preferred release signing approach: cosign keyless signing/attestation in CI with protected approvals. It removes local browser prompts while preserving transparency logs and keyless verification.

## Goal

- Use GitHub OIDC keyless signing for all image digests.
- Require human approval via a protected environment.
- Keep local signing optional (for troubleshooting only).

## Preconditions

- Release workflow runs on semver tags (`vX.Y.Z`).
- CI has permission to sign (OIDC).
- GHCR login is available in the workflow.

Required workflow permissions:

```yaml
permissions:
  id-token: write
  packages: write
  contents: read
```

## Environment Gate

Create a protected environment named `release-signing`:

- Require reviewers (at least one maintainer).
- Limit to `main`/tag workflows.
- Enable environment secrets if needed (not required for keyless).

### What “protected environment” means (plain language)

This is a **GitHub Actions feature**, not a local machine or Docker concept.
The environment is associated with a **repository** rather than with an **organization**.

- It lives in the **GitHub repo settings** (Actions → Environments).
- It adds a **human approval gate** before a job runs.
- It does **not** require a special dev machine, container, or shell setup.
- If you only have a laptop and a bash shell, that’s fine — the approvals happen in GitHub.

Recommended settings:

- **Deployment branches**: only `main` and tags matching `v*.*.*`.
- **Required reviewers**: at least one maintainer.
- **Wait timer**: optional (use 0 unless you want a cooling-off period).

Workflow usage example:

```yaml
jobs:
  sign:
    environment: release-signing
    permissions:
      id-token: write
      packages: write
      contents: read
```

## CI Signing Flow (Recommended)

1. **Build & push images** (existing release workflow).
2. **Collect digests** from the build outputs:
   - Use the manifest-derived image list (from `manifests/tools.json`) to avoid per-variant hand edits.
   - For each image, record the pushed digest (`ghcr.io/...@sha256:...`).
3. **Sign + attest in CI** using cosign keyless:
   - Set `COSIGN_YES=true` to avoid prompts.
   - Use `cosign sign` and `cosign attest --type spdxjson` per digest.
4. **(Optional) Attach SBOM** if legacy discovery is desired:
   - Use `cosign attach sbom --sbom <file> --type spdx --input-format json`.

## Example CI Step (Skeleton)

```bash
export COSIGN_YES=true
for ref in ${IMAGE_DIGESTS}; do
  cosign sign "${ref}"
  cosign attest --predicate "${SBOM_FILE}" --type spdxjson "${ref}"
done
```

## Release Checklist Integration

When CI signing is enabled:

- Remove manual cosign signing steps from the release checklist.
- Keep GPG/minisign manual signing if desired (artifacts still require local signatures).
- Verify cosign transparency logs via `cosign verify` in release notes.

## Verification (Consumer)

Document these commands in release notes:

```bash
cosign verify \
  --certificate-oidc-issuer https://accounts.google.com \
  --certificate-identity-regexp ".*@.*" \
  ghcr.io/fulmenhq/goneat-tools-runner-musl@sha256:<digest>

cosign verify-attestation --type spdxjson \
  ghcr.io/fulmenhq/goneat-tools-runner-musl@sha256:<digest>
```

## Notes

- Keyless signing writes to the public transparency log.
- Environment approvals provide the human gate once per release without local prompts.
- The canonical image list should come from the manifest to scale with new catalog variants.
