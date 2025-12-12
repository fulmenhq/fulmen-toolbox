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

### Manual Signing Env Vars (set once)

```bash
# Release tag
export RELEASE_TAG=v0.1.4

# GPG key ID (use ! suffix to force specific subkey; single quotes to avoid ! expansion)
export PGP_KEY_ID='448A539320A397AF!'

# OPTIONAL: choose which local GPG homedir to use (script sets GNUPGHOME internally)
# Useful if you keep multiple keyrings.
export GPG_HOMEDIR="$HOME/.gnupg"

# Minisign secret key path
export MINISIGN_KEY="$HOME/.minisign/minisign.key"

# OPTIONAL: disable cosign if needed
# export COSIGN=0
```

### Phase 1: Automated Setup (AI/CLI friendly)

```bash
# Clean previous release artifacts (avoids stale file accumulation)
make release-clean

# Download release artifacts
make release-download RELEASE_TAG=$RELEASE_TAG

# OPTIONAL: stage release notes from docs/releases/
# (warns if missing; can enforce with RELEASE_NOTES_REQUIRED=1)
make release-notes RELEASE_TAG=$RELEASE_TAG

# (optional) Get image digests for signing
make release-digests RELEASE_TAG=$RELEASE_TAG
```

### Phase 2: Interactive Signing (Human - REQUIRED before upload)

> **Note:** `make release-upload` will **block** if signatures are missing. Complete all steps below first.

#### Step 2.1: Confirm env vars are set

Required:

- `RELEASE_TAG`
- `PGP_KEY_ID`
- `MINISIGN_KEY`

Optional:

- `GPG_HOMEDIR` (recommended if you use multiple keyrings)
- `COSIGN=0` (disable cosign)

#### Step 2.2: Run signing helper (cosign + checksums)

```bash
make release-sign RELEASE_TAG=$RELEASE_TAG
```

This wraps the interactive signing steps:

- Resolves image digests from GHCR (requires registry auth)
- `cosign sign` + `cosign attest` for each image (browser prompts for OIDC)
- GPG signs `dist/release/SHA256SUMS-*` (passphrase prompts)
- Minisign signs `dist/release/SHA256SUMS-*` (passphrase prompts)

Optional skips (debugging/partial runs):

```bash
COSIGN=0 make release-sign RELEASE_TAG=$RELEASE_TAG
GPG=0 make release-sign RELEASE_TAG=$RELEASE_TAG
MINISIGN=0 make release-sign RELEASE_TAG=$RELEASE_TAG

# (equivalents)
SKIP_COSIGN=1 make release-sign RELEASE_TAG=$RELEASE_TAG
SKIP_GPG=1 make release-sign RELEASE_TAG=$RELEASE_TAG
SKIP_MINISIGN=1 make release-sign RELEASE_TAG=$RELEASE_TAG
```

Verify signatures created:

```bash
ls dist/release/*.asc dist/release/*.minisig
```

### Phase 3: Automated Upload (AI/CLI friendly)

Requires `PGP_KEY_ID` and `MINISIGN_KEY` env vars from Phase 2.
Public keys are automatically exported via Make target dependencies.

```bash
# Upload signatures and keys to GitHub Release
# (automatically exports public keys and verifies GPG key is safe)
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
