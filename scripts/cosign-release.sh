#!/usr/bin/env bash

set -euo pipefail

# Sign, attest and verify the published images of one release image with
# keyless cosign.
#
# Usage: cosign-release.sh sign|verify <image> <version> <digests-file> <sbom-dir> [alias ...]
#
#   <digests-file>  DIGESTS-<image> as written by the release workflow:
#                     index <sha256:...>
#                     child <sha256:...> <os>/<arch>
#   <sbom-dir>      holds sbom-<image>-<version>-<os>-<arch>.json for each child
#
# Every published name (the image and each alias) is its own registry
# repository, so each name gets its own signatures and attestations; equal
# digests do not share them. For every name:
#   index   signed and verified; no SBOM attestation (one SPDX document cannot
#           describe every platform the index names; the index signature
#           binds the child digests)
#   child   signed and attested with that child's own SBOM, and both verified
# verify also checks that every name resolves to the index in <digests-file>.
#
# Environment:
#   REGISTRY, OWNER                registry and owner (default ghcr.io, fulmenhq)
#   CERT_IDENTITY, CERT_ISSUER     verify identity (required for verify)
#   COSIGN, IMAGE_DIGESTS          commands to run (tests substitute stubs)

die() {
	echo "error: $*" >&2
	exit 1
}

[ $# -ge 5 ] || die "usage: cosign-release.sh sign|verify <image> <version> <digests-file> <sbom-dir> [alias ...]"
CMD=$1
IMAGE=$2
VERSION=$3
DIGESTS=$4
SBOM_DIR=$5
shift 5
NAMES=("${IMAGE}" "$@")

REGISTRY=${REGISTRY:-ghcr.io}
OWNER=${OWNER:-fulmenhq}
COSIGN=${COSIGN:-cosign}
IMAGE_DIGESTS=${IMAGE_DIGESTS:-"$(dirname "$0")/image-digests.sh"}

[ -f "${DIGESTS}" ] || die "missing ${DIGESTS}"
INDEX=$(awk '$1 == "index" { print $2 }' "${DIGESTS}")
[[ "${INDEX}" =~ ^sha256:[0-9a-f]{64}$ ]] && [ "$(awk '$1 == "index"' "${DIGESTS}" | wc -l | tr -d ' ')" = "1" ] ||
	die "${DIGESTS} must hold exactly one index digest"
CHILDREN=$(awk '$1 == "child" { print $2 " " $3 }' "${DIGESTS}")
[ -n "${CHILDREN}" ] || die "${DIGESTS} names no platform manifest"
if awk '$1 != "index" && $1 != "child"' "${DIGESTS}" | grep -q .; then
	die "${DIGESTS} has an unknown entry"
fi

# Each child needs its own SBOM before anything is signed.
sbom_for() {
	local platform=$1 path
	path="${SBOM_DIR}/sbom-${IMAGE}-${VERSION}-${platform//\//-}.json"
	[ -s "${path}" ] || die "missing SBOM for ${platform}: ${path}"
	echo "${path}"
}
while read -r _ platform; do
	sbom_for "${platform}" >/dev/null
done <<<"${CHILDREN}"

sign_name() {
	local name=$1 ref digest platform
	ref="${REGISTRY}/${OWNER}/${name}"
	"${COSIGN}" sign "${ref}@${INDEX}"
	while read -r digest platform; do
		"${COSIGN}" sign "${ref}@${digest}"
		"${COSIGN}" attest --predicate "$(sbom_for "${platform}")" --type spdxjson "${ref}@${digest}"
	done <<<"${CHILDREN}"
}

verify_name() {
	local name=$1 ref got digest platform
	ref="${REGISTRY}/${OWNER}/${name}"
	got=$("${IMAGE_DIGESTS}" "${ref}:v${VERSION}" | awk '$1 == "index" { print $2 }')
	[ "${got}" = "${INDEX}" ] || die "${name}:v${VERSION} resolves to ${got:-nothing}, not ${INDEX}"
	"${COSIGN}" verify --certificate-identity "${CERT_IDENTITY}" --certificate-oidc-issuer "${CERT_ISSUER}" "${ref}@${INDEX}" >/dev/null
	echo "verified: ${name}@${INDEX} index signature"
	while read -r digest platform; do
		"${COSIGN}" verify --certificate-identity "${CERT_IDENTITY}" --certificate-oidc-issuer "${CERT_ISSUER}" "${ref}@${digest}" >/dev/null
		"${COSIGN}" verify-attestation --type spdxjson --certificate-identity "${CERT_IDENTITY}" \
			--certificate-oidc-issuer "${CERT_ISSUER}" "${ref}@${digest}" >/dev/null
		echo "verified: ${name}@${digest} ${platform} signature and SBOM attestation"
	done <<<"${CHILDREN}"
}

case "${CMD}" in
sign)
	for name in "${NAMES[@]}"; do
		sign_name "${name}"
	done
	;;
verify)
	[ -n "${CERT_IDENTITY:-}" ] && [ -n "${CERT_ISSUER:-}" ] || die "verify needs CERT_IDENTITY and CERT_ISSUER"
	for name in "${NAMES[@]}"; do
		verify_name "${name}"
	done
	;;
*) die "usage: cosign-release.sh sign|verify <image> <version> <digests-file> <sbom-dir> [alias ...]" ;;
esac
