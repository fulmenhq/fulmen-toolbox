# Release Signing

fulmen-toolbox releases carry two kinds of signature:

- **Checksum manifests.** Each `SHA256SUMS-<image>` lists the image references for that image and the digest each resolves to. It is signed with PGP (`.asc`) and minisign (`.minisig`).
- **Images.** The release workflow signs, with keyless cosign, the multi-arch index digest and each platform manifest the index names, under every published name (image and aliases). Each platform manifest also carries an SPDX attestation of its own SBOM; the index carries none. `DIGESTS-<image>` on the release lists the digests.

## Release keys

```
PGP primary fingerprint:   0CACA49B3119B6BC12B2CA11B9B485F294B9FE07
PGP signing subkey:        DAB70DD758911B26BB45A08C3B75AC591449DEBE
Minisign key blob SHA-256: 3e5b64023230a308ee0876cb9d0693e44c3daac7afe38a064174e476b2b99cb1
```

These are the same keys that sign goneat releases.

**The repository is authoritative.** `keys/expected-fingerprints.txt`, `docs/security/release-signing-keys.asc` and `docs/security/release-minisign.pub` at a release tag are the keys for that release. The copies attached to a GitHub release (`fulmen-toolbox-release-signing-key.asc`, `fulmenhq-release-signing.pub`) are a convenience; verify them against the repository, never on their own.

`keys/expected-fingerprints.txt` holds two lines: `gpg <primary fingerprint>` and `minisign <SHA-256 of the decoded minisign key record>`.

## Release-key pin

`scripts/release-verify.sh` (`make release-verify-signatures`, run by `make release-upload`) reads the three pin files as git objects from the release tag, not from the working tree or `dist/release`, and requires:

- the release tag to be an annotated tag for that version with one good signature by the pinned signing subkey (not checked when `FULMEN_TOOLBOX_RELEASE_PIN_REF` overrides the ref)

- the anchors file to name the pinned PGP primary and minisign key, and the key files to match it
- the PGP keys file to hold exactly one primary, exactly one signing subkey and no secret key material
- every manifest to have exactly one good, unexpired, unrevoked PGP signature by the pinned signing subkey, bound to the pinned primary
- every minisign signature to verify with the pinned key and carry the trusted comment `fulmen-toolbox <image> <version>`
- key assets in `dist/release`, when present, to be the pinned keys

Overrides, for explicit use only:

| Variable                           | Effect                                                                                                                                                     |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FULMEN_TOOLBOX_RELEASE_PIN_REF`   | Read the pin from this ref instead of `refs/tags/<tag>` (for example `HEAD` before tagging, or a tag that predates the pin)                                |
| `FULMEN_TOOLBOX_RELEASE_TRUST=env` | Use `FULMEN_TOOLBOX_TRUST_PGP_KEYS` and `FULMEN_TOOLBOX_TRUST_MINISIGN_PUB` instead of the pin; both must be outside `dist/release` (key-rotation testing) |

`make release-verify-pin` checks the pin at `HEAD`. CI runs it, together with `make test-release-tag` and `make test-release-verify`, on every change to the release scripts or keys.

Tags before v0.5.10 predate the pin. To verify one, set `FULMEN_TOOLBOX_RELEASE_PIN_REF` to a ref that has the pin; those releases were signed with the same keys.

## Signing

`make release-sign` checks the operator keys against the pin at the tag before touching any signature, signs into a staging directory, verifies the result against the pin, and only then promotes it into `dist/release`.

## Rotating a key

A key change is a pin change: commit the new key files and anchors in one reviewed change, and tag only after it lands. Verification of a tag uses the pin committed at that tag, so earlier releases keep verifying against their own keys.

## Verifying a release

See [Verification Commands](../../RELEASE_CHECKLIST.md#verification-commands) for the consumer steps: `scripts/verify-release-pgp.sh` for PGP, `minisign -Vm` for minisign, and `cosign verify` with the release workflow identity for images.
