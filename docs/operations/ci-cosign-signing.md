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
2. **Collect digests** with `scripts/image-digests.sh <image>:<tag>`:
   - Use the manifest-derived image list (from `manifests/tools.json`) to avoid per-variant hand edits.
   - It prints the index digest and each platform manifest digest; buildx attestation-manifest entries are skipped. Never take the first entry of the platform list.
3. **Sign + attest in CI** with `scripts/cosign-release.sh sign`, for every published name (the image and each alias; each is its own registry repository, so equal digests do not share signatures):
   - Sign the index digest and every platform manifest digest.
   - Attest each platform manifest with its own SBOM (`sbom-<image>-<version>-<os>-<arch>.json`, generated from that digest). The index gets no SBOM attestation.
4. **Verify in CI** with `scripts/cosign-release.sh verify`: every name resolves to the same index, and every signature and attestation verifies against the release workflow identity at the tag.

## Release Checklist Integration

When CI signing is enabled:

- Remove manual cosign signing steps from the release checklist.
- Keep GPG/minisign manual signing if desired (artifacts still require local signatures).
- Verify cosign transparency logs via `cosign verify` in release notes.

## Verification (Consumer)

The release workflow signs and attests each image's multi-arch index digest and every platform manifest the index names, then verifies all of them before the job succeeds. `DIGESTS-<image>` on the release lists the digests. Verify against the workflow identity at the tag, not any identity:

```bash
IDENTITY="https://github.com/fulmenhq/fulmen-toolbox/.github/workflows/release.yml@refs/tags/<tag>"
ISSUER="https://token.actions.githubusercontent.com"

cosign verify --certificate-identity "$IDENTITY" --certificate-oidc-issuer "$ISSUER" \
  ghcr.io/fulmenhq/goneat-tools-runner-musl@sha256:<digest>

cosign verify-attestation --type spdxjson \
  --certificate-identity "$IDENTITY" --certificate-oidc-issuer "$ISSUER" \
  ghcr.io/fulmenhq/goneat-tools-runner-musl@sha256:<digest>
```

## Notes

- Keyless signing writes to the public transparency log.
- Environment approvals provide the human gate once per release without local prompts.
- The canonical image list should come from the manifest to scale with new catalog variants.
