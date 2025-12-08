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

**Set signing key identifiers:**

```bash
# GPG key ID (use ! suffix to force specific subkey)
export PGP_KEY_ID="448A539320A397AF!"

# Minisign secret key path
export MINISIGN_KEY="$HOME/.minisign/minisign.key"

# Get digests from Phase 1 output or:
GONEAT_DIGEST=$(docker manifest inspect ghcr.io/fulmenhq/goneat-tools:$RELEASE_TAG -v 2>/dev/null | \
  jq -r 'if type == "array" then .[0].Descriptor.digest else .config.digest end')
SBOM_DIGEST=$(docker manifest inspect ghcr.io/fulmenhq/sbom-tools:$RELEASE_TAG -v 2>/dev/null | \
  jq -r 'if type == "array" then .[0].Descriptor.digest else .config.digest end')
```

**Cosign (keyless OIDC - opens browser for each operation):**

```bash
# Sign image digests (2 browser prompts)
cosign sign \
  ghcr.io/fulmenhq/goneat-tools@$GONEAT_DIGEST

cosign sign \
  ghcr.io/fulmenhq/sbom-tools@$SBOM_DIGEST

# Attest SBOMs (2 browser prompts)
cosign attest \
  --predicate dist/release/sbom-goneat-tools-*.json \
  --type spdxjson \
  ghcr.io/fulmenhq/goneat-tools@$GONEAT_DIGEST

cosign attest \
  --predicate dist/release/sbom-sbom-tools-*.json \
  --type spdxjson \
  ghcr.io/fulmenhq/sbom-tools@$SBOM_DIGEST
```

**GPG Signing (requires passphrase):**

```bash
# Sign SHA256SUMS files
gpg --local-user "$PGP_KEY_ID" \
  --detach-sign --armor \
  dist/release/SHA256SUMS-goneat-tools

gpg --local-user "$PGP_KEY_ID" \
  --detach-sign --armor \
  dist/release/SHA256SUMS-sbom-tools

# Export public key for release (first time only)
gpg --armor --export "$PGP_KEY_ID" > \
  dist/release/fulmen-toolbox-release-signing-key.asc
```

**Minisign Signing (requires passphrase):**

```bash
# Sign SHA256SUMS files
minisign -S \
  -s "$MINISIGN_KEY" \
  -m dist/release/SHA256SUMS-goneat-tools

minisign -S \
  -s "$MINISIGN_KEY" \
  -m dist/release/SHA256SUMS-sbom-tools

# Copy public key for release (first time only)
cp "${MINISIGN_KEY%.key}.pub" \
  dist/release/fulmenhq-release-signing.pub
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
