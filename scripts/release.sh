#!/usr/bin/env sh

# release.sh
# Produce a repeatable release plan for the current VERSION.
# This is intentionally conservative: it prints commands to run manually.

set -eu

VERSION_FILE=${VERSION_FILE:-VERSION}
[ -f "$VERSION_FILE" ] || { echo "VERSION file missing at $VERSION_FILE" >&2; exit 1; }
VERSION=$(tr -d ' \t\n\r' < "$VERSION_FILE")

commands_required="docker cosign gpg minisign syft"

echo "Planned release for version: $VERSION"
echo
echo "Prereqs (install if missing):"
for cmd in $commands_required; do
  if command -v $cmd >/dev/null 2>&1; then
    echo "  - $cmd: ok"
  else
    echo "  - $cmd: MISSING"
  fi
done
if docker buildx version >/dev/null 2>&1; then
  echo "  - docker buildx: ok"
else
  echo "  - docker buildx: MISSING"
fi
echo
cat <<EOF
Suggested steps (manual for now):
1) Build multi-arch image:
   docker buildx create --use || true
   docker buildx build --platform linux/amd64,linux/arm64 \\
     -t ghcr.io/fulmenhq/goneat-tools:${VERSION} \\
     -t ghcr.io/fulmenhq/goneat-tools:latest \\
     -t ghcr.io/fulmenhq/goneat-tools:v${VERSION%%.*} \\
     --push images/goneat-tools

2) Generate SBOM:
   syft ghcr.io/fulmenhq/goneat-tools@<digest> -o spdx-json > sbom-${VERSION}.json

3) Sign image (cosign):
   COSIGN_EXPERIMENTAL=1 cosign sign ghcr.io/fulmenhq/goneat-tools@<digest>

4) Attach attestations (provenance + SBOM):
   cosign attest --predicate provenance.json --type slsaprovenance ghcr.io/fulmenhq/goneat-tools@<digest>
   cosign attest --predicate sbom-${VERSION}.json --type spdxjson ghcr.io/fulmenhq/goneat-tools@<digest>

5) Produce SHA256SUMS and signatures:
   printf "<digest>  ghcr.io/fulmenhq/goneat-tools:${VERSION}\\n" > SHA256SUMS
   gpg --batch --yes --armor --detach-sign --output SHA256SUMS.asc SHA256SUMS
   minisign -Sm SHA256SUMS -x SHA256SUMS.minisig

6) Git tag:
   git tag v${VERSION}
   git push origin v${VERSION}

7) Publish artifacts:
   - Upload SBOM and signed SHA256SUMS to release assets
   - Document verification commands in RELEASE_NOTES.md

NOTE: Replace <digest> with the pushed digest from step 1. Enforce issuer/subject in cosign verify per policy.
EOF
