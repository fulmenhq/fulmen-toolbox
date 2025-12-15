# Release Checklist

This is the SOP for publishing a new `fulmen-toolbox` release (semver-driven).

## Pre-flight

- [ ] Confirm working tree clean and CI green
- [ ] Ensure `VERSION` reflects the intended semver (`make bump-*` to adjust)
- [ ] Ensure GitHub Packages access for verification (for local `gh api`):
  - CI publishing should use `GITHUB_TOKEN` (short-lived) with workflow `permissions: packages: write`.
  - For local `gh api` queries, use a classic PAT with `read:packages`.
  - Avoid `repo` scope for GHCR-only usage; some `gh` interactions may still require additional org access depending on visibility/policy.
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
export RELEASE_TAG=v0.2.0

# GPG key ID (use ! suffix to force specific subkey; single quotes to avoid ! expansion)
export PGP_KEY_ID='448A539320A397AF!'

# OPTIONAL: choose which local GPG homedir to use (script sets GNUPGHOME internally)
# Useful if you keep multiple keyrings.
export GPG_HOMEDIR="$HOME/.gnupg"

# Minisign secret key path
export MINISIGN_KEY="$HOME/.minisign/minisign.key"

# Minisign expects the public key adjacent to the secret key:
#   MINISIGN_KEY=/path/to/minisign.key
#   public key=/path/to/minisign.pub
[ -f "${MINISIGN_KEY%.key}.pub" ] || echo "⚠️ minisign pubkey missing: ${MINISIGN_KEY%.key}.pub"

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
# Defaults to v0.2.x variants; override with IMAGES if needed.
make release-digests RELEASE_TAG=$RELEASE_TAG
```

### Phase 2: Interactive Signing (Human - REQUIRED before upload)

Note: keyless sigstore signing/attestation writes to public transparency logs and may include personal data (e.g., your email) as an immutable record. Read the prompt carefully when it appears.

> **Note:** `make release-upload` will **block** if signatures are missing. Complete all steps below first.

#### Step 2.1: Confirm env vars are set

Required:

- `RELEASE_TAG`
- `PGP_KEY_ID`
- `MINISIGN_KEY`

Optional:

- `GPG_HOMEDIR` (recommended if you use multiple keyrings)
- `COSIGN=0` (disable all cosign operations)
- `ATTACH_SBOM=1` (enable OCI SBOM attachment; deprecated upstream; off by default)

#### Step 2.2: Run signing helper (cosign + checksums)

```bash
make release-sign RELEASE_TAG=$RELEASE_TAG
```

This wraps the interactive signing steps:

- Resolves image digests from GHCR for each image variant (requires registry auth)
- `cosign sign` + `cosign attest` for each image (browser prompts for OIDC)
- Optional: `cosign attach sbom` for registry-native discovery (deprecated upstream; does not sign the SBOM; disabled by default)
- GPG signs `dist/release/SHA256SUMS-*` (passphrase prompts)
- Minisign signs `dist/release/SHA256SUMS-*` (passphrase prompts)

Optional skips (debugging/partial runs):

```bash
COSIGN=0 make release-sign RELEASE_TAG=$RELEASE_TAG
ATTACH_SBOM=0 make release-sign RELEASE_TAG=$RELEASE_TAG
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

Recommended verification before upload:

- `make verify-release-key` (verifies exported GPG public key contains no private material)
- `make verify-minisign-key` (verifies minisign public key was exported/copied)
- `make verify-release-digests RELEASE_TAG=$RELEASE_TAG` (fails if any expected image tag is missing)
- `make release-digests RELEASE_TAG=$RELEASE_TAG` (prints digests for copy/paste)

#### Step 3.1: Stage release notes (optional)

```bash
# Copies docs/releases/$RELEASE_TAG.md into dist/release/ as:
#   dist/release/release-notes-$RELEASE_TAG.md
#
# Note: release-upload will upload it if present.
make release-notes RELEASE_TAG=$RELEASE_TAG

# To enforce (fail if missing):
# RELEASE_NOTES_REQUIRED=1 make release-notes RELEASE_TAG=$RELEASE_TAG
```

#### Step 3.2: Export public keys (recommended)

```bash
# Exports:
# - dist/release/fulmen-toolbox-release-signing-key.asc
# - dist/release/fulmenhq-release-signing.pub
#
# NOTE: minisign expects the public key adjacent to the secret key:
#   MINISIGN_KEY=/path/to/minisign.key
#   public key=/path/to/minisign.pub
make release-export-keys
```

(These exports are also run automatically by `make release-upload` via Makefile dependencies; this step is here to make the workflow explicit and easier to debug.)

#### Step 3.3: Upload signatures + keys (+ optional release notes)

```bash
# Uploads signatures and keys to GitHub Release
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

Repeat for each variant image:

```bash
cosign verify \
  --certificate-oidc-issuer https://accounts.google.com \
  --certificate-identity-regexp ".*@.*" \
  ghcr.io/fulmenhq/goneat-tools-runner@sha256:<digest>
```

### Cosign SBOM (attestation, recommended)

`cosign attest` is the canonical assurance mechanism.

- Note: `--type` is a predicate-type label (string); it must match the value used during attestation.
- Fulmen Toolbox standard: `--type spdxjson` for SPDX-JSON SBOM attestations.

```bash
cosign verify-attestation \
  --type spdxjson \
  ghcr.io/fulmenhq/goneat-tools-runner@sha256:<digest>

# Extract the predicate JSON (SPDX) from the attestation:
cosign verify-attestation --type spdxjson ghcr.io/fulmenhq/goneat-tools-runner@sha256:<digest> \
  | jq -r '.payload' \
  | base64 -d \
  | jq -r '.predicate'
```

### Cosign SBOM (OCI-attached, optional)

OCI attachment is a discovery convenience but is deprecated upstream (`cosign attach sbom`).

```bash
cosign download sbom ghcr.io/fulmenhq/goneat-tools-runner@sha256:<digest>
```

### GPG

```bash
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$RELEASE_TAG/SHA256SUMS-goneat-tools-runner
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$RELEASE_TAG/SHA256SUMS-goneat-tools-runner.asc
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$RELEASE_TAG/fulmen-toolbox-release-signing-key.asc

# Use temp keyring to avoid polluting user's GPG home
GPG_TMPDIR=$(mktemp -d)
gpg --homedir "$GPG_TMPDIR" --import fulmen-toolbox-release-signing-key.asc
gpg --homedir "$GPG_TMPDIR" --verify SHA256SUMS-goneat-tools-runner.asc SHA256SUMS-goneat-tools-runner
rm -rf "$GPG_TMPDIR"
```

### Minisign

```bash
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$RELEASE_TAG/SHA256SUMS-goneat-tools-runner
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$RELEASE_TAG/SHA256SUMS-goneat-tools-runner.minisig
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$RELEASE_TAG/fulmenhq-release-signing.pub

minisign -Vm SHA256SUMS-goneat-tools-runner -p fulmenhq-release-signing.pub
```

## Post-release

- [ ] Verify signatures work with documented verification commands
- [ ] Update README badges if needed
- [ ] Announce release in relevant channels
- [ ] Bump `VERSION` to next `-dev` if using that convention
- [ ] Open follow-up issue/PR for dependency/tool bumps if needed

## Notes

- **GHCR Auth (CI)**: Prefer `GITHUB_TOKEN` with workflow `permissions: packages: write` (no long-lived secrets).
  - If GHCR operations fail due to org policy, fix the org/repo Actions/Packages settings rather than introducing a classic PAT.
  - Classic PATs are still useful for local troubleshooting and `gh api` queries; use `read:packages`/`write:packages` as needed and avoid `repo` scope for GHCR-only usage.
  - Fine-grained PATs don't support packages yet.
  - Classic PAT UI workaround (pre-fills scopes; keeps `repo` unchecked/editable):
    - https://github.com/settings/tokens/new?scopes=write:packages
    - https://github.com/settings/tokens/new?scopes=write:packages,read:packages
    - https://github.com/settings/tokens/new?scopes=write:packages,read:packages,delete:packages
  - If you use the plain `https://github.com/settings/tokens/new` flow, GitHub may auto-select `repo` depending on UI state/policy.
  - Minimal local login (for troubleshooting):

    ```bash
    export FULMEN_TOOLBOX_GHCR_TOKEN=ghp_...
    # Username must match the PAT owner
    echo "$FULMEN_TOOLBOX_GHCR_TOKEN" | docker login ghcr.io -u <pat-owner-username> --password-stdin
    ```
- **Multiple Signing Subkeys**: Use `!` suffix on GPG key ID (e.g., `448A539320A397AF!`) to force specific subkey.
- **4 Browser Prompts**: Keyless cosign requires separate OIDC auth for each sign/attest operation (2 images × 2 ops = 4 prompts).
