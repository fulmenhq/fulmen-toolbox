#!/usr/bin/env bash

set -euo pipefail

# Print the digests that must be signed for a published image reference.
#
# Usage: image-digests.sh <image-ref>
#        image-digests.sh --from-json <file> (reads the raw manifest; for tests)
#
# Output, one per line:
#   index <sha256:...>              the digest the reference resolves to
#   child <sha256:...> <os>/<arch>  each platform manifest the index names
#
# A single-platform manifest prints only its own digest as "index". Index
# entries for buildx attestation manifests (platform unknown/unknown, or a
# vnd.docker.reference.type annotation) are not platforms and are skipped.
# Fails when the reference does not resolve, when an index names no
# platform manifest, or when two entries claim the same platform.

die() {
	echo "error: $*" >&2
	exit 1
}

[ $# -ge 1 ] || die "usage: image-digests.sh <image-ref> | --from-json <file>"
command -v jq >/dev/null || die "jq is required"

if [ "$1" = "--from-json" ]; then
	[ $# -eq 3 ] || die "usage: image-digests.sh --from-json <file> <digest>"
	raw=$(cat "$2")
	digest=$3
else
	[ $# -eq 1 ] || die "usage: image-digests.sh <image-ref>"
	command -v docker >/dev/null || die "docker (buildx imagetools) is required"
	ref=$1
	raw=$(docker buildx imagetools inspect --raw -- "${ref}" 2>/dev/null) ||
		die "cannot resolve ${ref}"
	digest=$(docker buildx imagetools inspect --format '{{json .Manifest}}' -- "${ref}" 2>/dev/null |
		jq -r '.digest') || die "cannot resolve the digest of ${ref}"
fi

[[ "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]] || die "invalid digest '${digest}'"
echo "index ${digest}"

media=$(printf '%s' "${raw}" | jq -r '.mediaType // empty')
case "${media}" in
application/vnd.oci.image.index.v1+json | application/vnd.docker.distribution.manifest.list.v2+json) ;;
application/vnd.oci.image.manifest.v1+json | application/vnd.docker.distribution.manifest.v2+json)
	exit 0
	;;
*) die "unsupported manifest media type '${media}'" ;;
esac

children=$(printf '%s' "${raw}" | jq -r '
	.manifests[]
	| select((.annotations["vnd.docker.reference.type"] // "") == "")
	| select(.platform.os != "unknown" and .platform.architecture != "unknown")
	| "\(.digest) \(.platform.os)/\(.platform.architecture)\(if .platform.variant then "/" + .platform.variant else "" end)"')
[ -n "${children}" ] || die "index ${digest} names no platform manifest"

dups=$(printf '%s\n' "${children}" | awk '{print $2}' | sort | uniq -d)
[ -z "${dups}" ] || die "index ${digest} names more than one manifest for: ${dups}"

while read -r d platform; do
	[[ "${d}" =~ ^sha256:[0-9a-f]{64}$ ]] || die "invalid child digest '${d}'"
	echo "child ${d} ${platform}"
done <<<"${children}"
