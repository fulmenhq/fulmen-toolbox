# Release Checklist

This is the SOP for publishing a new `fulmen-toolbox` release (semver-driven).

## Pre-flight

- [ ] Confirm working tree clean and CI green
- [ ] Ensure `VERSION` reflects the intended semver (`make bump-*` to adjust)
- [ ] Update `CHANGELOG.md` and `RELEASE_NOTES.md` with the release entry
- [ ] Sync pins: update `manifests/tools.json`, Dockerfile ARGs, and `docs/images/goneat-tools.md`
- [ ] Run local checks: `make precommit` (manifest + workflows lint) and `make prepush` (quality + build + test)
- [ ] Validate docs reflect current tooling (inventory, architecture, ADRs)

## Build & Publish (CI-driven)

- [ ] Tag repo: `git tag v$(cat VERSION) && git push origin --tags`
- [ ] CI release workflow triggers on tag push:
  - Builds multi-arch images for all matrix entries
  - Pushes to GHCR (`:latest`, `:v<major>`, and semver tag)
  - Generates SBOMs and SHA256SUMS per-image
  - Uploads artifacts to GitHub Release
- [ ] Verify release artifacts appear on GitHub Release page

## Manual Signing Workflow

CI generates artifacts but signing requires interactive authentication. Use this workflow:

### Phase 1: Automated Setup (AI/CLI friendly)

```bash
# Set the release tag
export RELEASE_TAG=v0.1.2

# Download release artifacts
make release-download RELEASE_TAG=$RELEASE_TAG

# Get image digests for signing
make release-digests RELEASE_TAG=$RELEASE_TAG
```

### Phase 2: Interactive Signing (Human in separate shell)

**Cosign (keyless OIDC - opens browser for each operation):**

```bash
cd dist/release

# Sign image digests (2 browser prompts)
COSIGN_YES=true cosign sign ghcr.io/fulmenhq/goneat-tools@sha256:<digest>
COSIGN_YES=true cosign sign ghcr.io/fulmenhq/sbom-tools@sha256:<digest>

# Attest SBOMs (2 browser prompts)
COSIGN_YES=true cosign attest --predicate sbom-goneat-tools-*.json --type spdxjson \
  ghcr.io/fulmenhq/goneat-tools@sha256:<digest>
COSIGN_YES=true cosign attest --predicate sbom-sbom-tools-*.json --type spdxjson \
  ghcr.io/fulmenhq/sbom-tools@sha256:<digest>
```

**GPG Signing (requires passphrase):**

```bash
cd dist/release

# Sign SHA256SUMS files (use ! suffix if multiple signing subkeys)
gpg --armor --detach-sign --local-user <KEY_ID>! -o SHA256SUMS-goneat-tools.asc SHA256SUMS-goneat-tools
gpg --armor --detach-sign --local-user <KEY_ID>! -o SHA256SUMS-sbom-tools.asc SHA256SUMS-sbom-tools

# Export public key for release
gpg --armor --export <KEY_ID>! > fulmen-toolbox-release-signing-key.asc
```

**Minisign Signing (requires passphrase):**

```bash
cd dist/release

# Sign SHA256SUMS files
minisign -Sm SHA256SUMS-goneat-tools -s /path/to/minisign.key -t "fulmen-toolbox goneat-tools $RELEASE_TAG"
minisign -Sm SHA256SUMS-sbom-tools -s /path/to/minisign.key -t "fulmen-toolbox sbom-tools $RELEASE_TAG"

# Copy public key for release
cp /path/to/minisign.pub fulmenhq-release-signing.pub
```

### Phase 3: Automated Upload (AI/CLI friendly)

```bash
# Verify GPG public key is safe (no private key material)
make verify-release-key

# Upload signatures and keys to GitHub Release
make release-upload RELEASE_TAG=$RELEASE_TAG
```

### Quick Reference

```bash
# Show full workflow help
make release-signing-help
```

## Verification Commands

Document these in release notes for consumers:

### Cosign (keyless)

```bash
cosign verify \
  --certificate-oidc-issuer https://accounts.google.com \
  --certificate-identity-regexp ".*@.*" \
  ghcr.io/fulmenhq/goneat-tools@sha256:<digest>
```

### GPG

```bash
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$RELEASE_TAG/SHA256SUMS-goneat-tools
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$RELEASE_TAG/SHA256SUMS-goneat-tools.asc
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$RELEASE_TAG/fulmen-toolbox-release-signing-key.asc

# Use temp keyring to avoid polluting user's GPG home
GPG_TMPDIR=$(mktemp -d)
gpg --homedir "$GPG_TMPDIR" --import fulmen-toolbox-release-signing-key.asc
gpg --homedir "$GPG_TMPDIR" --verify SHA256SUMS-goneat-tools.asc SHA256SUMS-goneat-tools
rm -rf "$GPG_TMPDIR"
```

### Minisign

```bash
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$RELEASE_TAG/SHA256SUMS-goneat-tools
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$RELEASE_TAG/SHA256SUMS-goneat-tools.minisig
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$RELEASE_TAG/fulmenhq-release-signing.pub

minisign -Vm SHA256SUMS-goneat-tools -p fulmenhq-release-signing.pub
```

## Post-release

- [ ] Verify signatures work with documented verification commands
- [ ] Update README badges if needed
- [ ] Announce release in relevant channels
- [ ] Bump `VERSION` to next `-dev` if using that convention
- [ ] Open follow-up issue/PR for dependency/tool bumps if needed

## Notes

- **GHCR Token Scope**: Manual cosign signing requires a classic PAT with `write:packages` scope. Fine-grained PATs don't support packages yet.
- **Multiple Signing Subkeys**: Use `!` suffix on GPG key ID (e.g., `448A539320A397AF!`) to force specific subkey.
- **4 Browser Prompts**: Keyless cosign requires separate OIDC auth for each sign/attest operation (2 images × 2 ops = 4 prompts).
