# Release Checklist

This is the SOP for publishing a new `fulmen-toolbox` release (semver-driven).

## Pre-flight

- [ ] Confirm working tree clean and CI green
- [ ] Ensure `VERSION` reflects the intended semver (`make bump-*` to adjust)
- [ ] Set release env vars (avoid cross-repo collisions):
  - `FULMEN_TOOLBOX_RELEASE_TAG` (must be `v<semver>`, e.g. `v0.2.2`)
  - `FULMEN_TOOLBOX_PGP_KEY_ID` (GPG key ID, with `!` suffix to force subkey)
  - `FULMEN_TOOLBOX_MINISIGN_KEY` (path to minisign secret key)
  - `FULMEN_TOOLBOX_GPG_HOMEDIR` (optional; multiple keyrings)
  - `FULMEN_TOOLBOX_ATTACH_SBOM=1` (optional; enable OCI SBOM attach)
  - `FULMEN_TOOLBOX_IMAGES` (optional; override default image set for digests/signing)
- [ ] Ensure GitHub Packages access for verification (for local `gh api`):
  - CI publishing should use `GITHUB_TOKEN` (short-lived) with workflow `permissions: packages: write`.
  - For local `gh api` queries, use a classic PAT with `read:packages`.
  - Avoid `repo` scope for GHCR-only usage; some `gh` interactions may still require additional org access depending on visibility/policy.
- [ ] Update `CHANGELOG.md` and `RELEASE_NOTES.md` with the release entry
- [ ] Sync pins: update `manifests/tools.json`, Dockerfile ARGs, and `docs/images/goneat-tools.md`
- [ ] If adding a new image, confirm `manifests/tools.json` includes it (release signing/digests derive from the manifest list)
- [ ] Run local checks: `make precommit` (manifest + workflows lint) and `make prepush` (quality + build + test)
  - **Timing note**: `make prepush` builds and smoke-tests images cold; expect **~30 minutes** on a clean cache, **~3-5 min** when layers are warm. If running under an automation harness, set the command timeout to **at least 45 min** to avoid spurious cancellation.
- [ ] Run `make validate-licenses` (builds all images and validates license/notice paths)
  - **Timing note**: **~5-10 min cold**, **~1-2 min** if `make prepush` already populated the BuildKit cache. Same 45-min timeout guidance applies for cold runs.
- [ ] Validate docs reflect current tooling (inventory, architecture, ADRs)
- [ ] Review CI cosign signing runbook: `docs/operations/ci-cosign-signing.md`

## Build & Publish (CI-driven)

- [ ] Tag repo: `git tag v$(cat VERSION) && git push origin --tags`
- [ ] CI release workflow triggers on tag push:
  - Builds multi-arch images for all matrix entries
  - Pushes to GHCR (`:latest`, `:v<major>`, and semver tag)
  - Generates SBOMs and SHA256SUMS per-image
  - Uploads artifacts to GitHub Release
- [ ] Approve the `release-signing` environment for the cosign job:
  - GitHub → Actions → **Release (build, sbom, checksums)** → “Review deployments”
  - Approve the `release-signing` job so keyless cosign signing/attestation runs once
- [ ] Verify release artifacts appear on GitHub Release page

## Manual Signing Workflow

CI generates artifacts but signing requires interactive authentication. Use this workflow:

### Manual Signing Env Vars (set once)

```bash
# Release tag (v<semver> convention)
export FULMEN_TOOLBOX_RELEASE_TAG=v<x.y.z> # e.g., v0.2.2

# GPG key ID (use ! suffix to force specific subkey; single quotes to avoid ! expansion) - ex: '44234232EF!' (not a real value - see gpg keyring)
export FULMEN_TOOLBOX_PGP_KEY_ID=<subkey in single quotes>

# OPTIONAL: choose which local GPG homedir to use (script sets GNUPGHOME internally)
# Useful if you keep multiple keyrings.  Default value shown but change as appropriate
export FULMEN_TOOLBOX_GPG_HOMEDIR="$HOME/.gnupg"

# Minisign secret key path - default value shown but change as appropriate
export FULMEN_TOOLBOX_MINISIGN_KEY="$HOME/.minisign/minisign.key"

# Minisign expects the public key adjacent to the secret key:
#   FULMEN_TOOLBOX_MINISIGN_KEY=/path/to/minisign.key
#   public key=/path/to/minisign.pub
[ -f "${FULMEN_TOOLBOX_MINISIGN_KEY%.key}.pub" ] || echo "⚠️ minisign pubkey missing: ${FULMEN_TOOLBOX_MINISIGN_KEY%.key}.pub"

# OPTIONAL: disable cosign if needed
# export FULMEN_TOOLBOX_COSIGN=0
```

### Phase 1: Automated Setup (AI/CLI friendly)

```bash
# Clean previous release artifacts (avoids stale file accumulation)
make release-clean

# Download release artifacts
make release-download FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG

# OPTIONAL: stage release notes from docs/releases/
# (warns if missing; can enforce with FULMEN_TOOLBOX_RELEASE_NOTES_REQUIRED=1)
make release-notes FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG

# (optional) Get image digests for signing
# Defaults to the current image set (runner/slim + glibc). Override with FULMEN_TOOLBOX_IMAGES if needed.
make release-digests FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG
```

### Phase 2: Manual Artifact Signing (Human - REQUIRED before upload)

Cosign signing/attestation now runs in CI under the `release-signing` environment (see `docs/operations/ci-cosign-signing.md`). Manual signing is only for checksum artifacts (GPG + minisign).

> **Note:** `make release-upload` will **block** if signatures are missing. Complete all steps below first.

#### Step 2.1: Confirm env vars are set

Required:

- `FULMEN_TOOLBOX_RELEASE_TAG`
- `FULMEN_TOOLBOX_PGP_KEY_ID`
- `FULMEN_TOOLBOX_MINISIGN_KEY`

Optional:

- `FULMEN_TOOLBOX_GPG_HOMEDIR` (recommended if you use multiple keyrings)
- `FULMEN_TOOLBOX_COSIGN=0` (disable all cosign operations)
- `FULMEN_TOOLBOX_ATTACH_SBOM=1` (enable OCI SBOM attachment; deprecated upstream; off by default)

#### Step 2.2: Run signing helper (checksums only)

```bash
make release-sign FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG
```

This wraps the interactive signing steps:

- GPG signs `dist/release/SHA256SUMS-*` (passphrase prompts)
- Minisign signs `dist/release/SHA256SUMS-*` (passphrase prompts)

Optional skips (debugging/partial runs):

```bash
FULMEN_TOOLBOX_GPG=0 make release-sign FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG
FULMEN_TOOLBOX_MINISIGN=0 make release-sign FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG

# (equivalents)
FULMEN_TOOLBOX_SKIP_GPG=1 make release-sign FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG
FULMEN_TOOLBOX_SKIP_MINISIGN=1 make release-sign FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG
```

Verify signatures created:

```bash
ls dist/release/*.asc dist/release/*.minisig
```

### Phase 3: Automated Upload (AI/CLI friendly)

Requires `FULMEN_TOOLBOX_PGP_KEY_ID` and `FULMEN_TOOLBOX_MINISIGN_KEY` env vars from Phase 2.

Recommended verification before upload:

- `make verify-release-key` (verifies exported GPG public key contains no private material)
- `make verify-minisign-key` (verifies minisign public key was exported/copied)
- `make verify-release-digests FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG` (fails if any expected image tag is missing)
- `make release-digests FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG` (prints digests for copy/paste)

#### Step 3.1: Stage release notes (optional)

```bash
# Copies docs/releases/$FULMEN_TOOLBOX_RELEASE_TAG.md into dist/release/ as:
#   dist/release/release-notes-$FULMEN_TOOLBOX_RELEASE_TAG.md
#
# Note: release-upload will upload it if present.
make release-notes FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG

# To enforce (fail if missing):
# FULMEN_TOOLBOX_RELEASE_NOTES_REQUIRED=1 make release-notes FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG
```

#### Step 3.2: Export public keys (recommended)

```bash
# Exports:
# - dist/release/fulmen-toolbox-release-signing-key.asc
# - dist/release/fulmenhq-release-signing.pub
#
# NOTE: minisign expects the public key adjacent to the secret key:
#   FULMEN_TOOLBOX_MINISIGN_KEY=/path/to/minisign.key
#   public key=/path/to/minisign.pub
make release-export-keys
```

(These exports are also run automatically by `make release-upload` via Makefile dependencies; this step is here to make the workflow explicit and easier to debug.)

#### Step 3.3: Upload signatures + keys (+ optional release notes)

```bash
# Uploads signatures and keys to GitHub Release
# (automatically exports public keys and verifies GPG key is safe)
make release-upload FULMEN_TOOLBOX_RELEASE_TAG=$FULMEN_TOOLBOX_RELEASE_TAG
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
  ghcr.io/fulmenhq/goneat-tools-runner-musl@sha256:<digest>
```

### Cosign SBOM (attestation, recommended)

`cosign attest` is the canonical assurance mechanism.

- Note: `--type` is a predicate-type label (string); it must match the value used during attestation.
- Fulmen Toolbox standard: `--type spdxjson` for SPDX-JSON SBOM attestations.

```bash
cosign verify-attestation \
  --type spdxjson \
  ghcr.io/fulmenhq/goneat-tools-runner-musl@sha256:<digest>

# Extract the predicate JSON (SPDX) from the attestation:
cosign verify-attestation --type spdxjson ghcr.io/fulmenhq/goneat-tools-runner-musl@sha256:<digest> \
  | jq -r '.payload' \
  | base64 -d \
  | jq -r '.predicate'
```

### Cosign SBOM (OCI-attached, optional)

OCI attachment is a discovery convenience but is deprecated upstream (`cosign attach sbom`).

```bash
cosign download sbom ghcr.io/fulmenhq/goneat-tools-runner-musl@sha256:<digest>
```

### GPG

```bash
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$FULMEN_TOOLBOX_RELEASE_TAG/SHA256SUMS-goneat-tools-runner-musl
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$FULMEN_TOOLBOX_RELEASE_TAG/SHA256SUMS-goneat-tools-runner-musl.asc
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$FULMEN_TOOLBOX_RELEASE_TAG/fulmen-toolbox-release-signing-key.asc

# Use temp keyring to avoid polluting user's GPG home
GPG_TMPDIR=$(mktemp -d)
gpg --homedir "$GPG_TMPDIR" --import fulmen-toolbox-release-signing-key.asc
gpg --homedir "$GPG_TMPDIR" --verify SHA256SUMS-goneat-tools-runner-musl.asc SHA256SUMS-goneat-tools-runner-musl
rm -rf "$GPG_TMPDIR"
```

### Minisign

```bash
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$FULMEN_TOOLBOX_RELEASE_TAG/SHA256SUMS-goneat-tools-runner-musl
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$FULMEN_TOOLBOX_RELEASE_TAG/SHA256SUMS-goneat-tools-runner-musl.minisig
curl -LO https://github.com/fulmenhq/fulmen-toolbox/releases/download/$FULMEN_TOOLBOX_RELEASE_TAG/fulmenhq-release-signing.pub

minisign -Vm SHA256SUMS-goneat-tools-runner-musl -p fulmenhq-release-signing.pub
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

- **Multiple Signing Subkeys**: Use `!` suffix on GPG key ID (e.g., `485823223AF!`) to force specific subkey.
- **Cosign approvals**: CI signing is gated once via the `release-signing` environment; local cosign prompts only apply if you opt into manual cosign.
