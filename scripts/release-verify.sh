#!/usr/bin/env bash

set -euo pipefail

# Verify signed per-image checksum manifests for a release.
#
# Usage: release-verify.sh signatures|digests <tag> [dir]
#
#   signatures  every SHA256SUMS-<image> in <dir> has a .asc and a .minisig;
#               each .asc is one good signature made under the exported GPG
#               public key, checked in a throwaway keyring; each .minisig
#               verifies with the exported minisign public key
#   digests     every image reference listed in the manifests resolves on the
#               registry to exactly the digest recorded for it
#
# Inputs in <dir> (default dist/release): SHA256SUMS-*, their .asc and
# .minisig signatures, fulmen-toolbox-release-signing-key.asc and
# fulmenhq-release-signing.pub (as written by release-download, release-sign
# and release-export-keys).
#
# Optional env:
#   FULMEN_TOOLBOX_PGP_FINGERPRINT - expected 40-hex primary fingerprint; when
#                                    set, the exported key must be exactly it

die() {
	echo "error: $*" >&2
	exit 1
}

CMD=${1:-}
TAG=${2:-}
DIR=${3:-dist/release}
GPG_KEY_FILE="${DIR}/fulmen-toolbox-release-signing-key.asc"
MINISIGN_PUB="${DIR}/fulmenhq-release-signing.pub"

[ -n "${TAG}" ] || die "usage: release-verify.sh signatures|digests <tag> [dir]"
[ -d "${DIR}" ] || die "${DIR} is not a directory"

manifests() {
	local m found=0
	for m in "${DIR}"/SHA256SUMS-*; do
		[ -e "${m}" ] || continue
		case "${m}" in
		*.asc | *.minisig) continue ;;
		esac
		found=1
		printf '%s\n' "${m}"
	done
	[ "${found}" -eq 1 ] || die "no SHA256SUMS-* manifests in ${DIR}"
}

cmd_signatures() {
	local home primary status count=0 m
	command -v gpg >/dev/null || die "gpg is required"
	command -v minisign >/dev/null || die "minisign is required"
	[ -f "${GPG_KEY_FILE}" ] || die "missing ${GPG_KEY_FILE}; run make release-export-keys or release-download"
	[ -f "${MINISIGN_PUB}" ] || die "missing ${MINISIGN_PUB}; run make release-export-keys or release-download"

	home=$(mktemp -d "${TMPDIR:-/tmp}/rverify-gpg.XXXXXX")
	trap 'gpgconf --homedir "'"${home}"'" --kill all >/dev/null 2>&1 || true; rm -rf "'"${home}"'"' EXIT
	chmod 700 "${home}"
	gpg --homedir "${home}" --batch --quiet --import "${GPG_KEY_FILE}" 2>/dev/null ||
		die "cannot import ${GPG_KEY_FILE}"

	primary=$(gpg --homedir "${home}" --batch --with-colons --fixed-list-mode --list-keys |
		awk -F: '$1 == "pub" { want = 1; n++; next } $1 == "fpr" && want { want = 0; print $10 } END { if (n != 1) exit 1 }') ||
		die "${GPG_KEY_FILE} must contain exactly one primary key"
	if [ -n "${FULMEN_TOOLBOX_PGP_FINGERPRINT:-}" ]; then
		local want
		want=$(printf '%s' "${FULMEN_TOOLBOX_PGP_FINGERPRINT}" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
		[ "${primary}" = "${want}" ] || die "exported key ${primary} is not FULMEN_TOOLBOX_PGP_FINGERPRINT ${want}"
	fi

	while IFS= read -r m; do
		[ -f "${m}.asc" ] || die "missing ${m}.asc"
		[ -f "${m}.minisig" ] || die "missing ${m}.minisig"

		status=$(gpg --homedir "${home}" --batch --status-fd 1 --verify "${m}.asc" "${m}" 2>/dev/null) ||
			die "PGP verification failed for $(basename "${m}")"
		if [ "$(printf '%s\n' "${status}" | grep -c '^\[GNUPG:\] VALIDSIG ')" -ne 1 ] ||
			printf '%s\n' "${status}" | grep -qE '^\[GNUPG:\] (BADSIG|ERRSIG|EXPSIG|EXPKEYSIG|REVKEYSIG) '; then
			die "$(basename "${m}").asc is not a single good signature"
		fi
		if [ "$(printf '%s\n' "${status}" | awk '$2 == "VALIDSIG" { print $NF }')" != "${primary}" ]; then
			die "$(basename "${m}").asc was not signed under ${primary}"
		fi

		minisign -Vqm "${m}" -p "${MINISIGN_PUB}" >/dev/null 2>&1 ||
			die "minisign verification failed for $(basename "${m}")"
		count=$((count + 1))
	done < <(manifests)

	echo "verified: ${count} manifest(s) for ${TAG} with PGP and minisign"
	echo "  pgp primary: ${primary}"
}

cmd_digests() {
	local m name digest ref got total=0 bad=0
	command -v docker >/dev/null || die "docker (buildx imagetools) is required"
	while IFS= read -r m; do
		name=${m##*/}
		while read -r digest ref; do
			[ -n "${digest}" ] || continue
			[[ "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]] || die "${name}: invalid digest '${digest}'"
			total=$((total + 1))
			got=$(docker buildx imagetools inspect "${ref}" --format '{{json .Manifest.Digest}}' 2>/dev/null | tr -d '"') || got=""
			if [ "${got}" != "${digest}" ]; then
				echo "mismatch: ${ref} signed ${digest} registry ${got:-unresolved}" >&2
				bad=$((bad + 1))
			fi
		done <"${m}"
	done < <(manifests)
	[ "${total}" -gt 0 ] || die "no image references in the manifests"
	[ "${bad}" -eq 0 ] || die "${bad} of ${total} image reference(s) do not match their signed digest"
	echo "verified: ${total} image reference(s) for ${TAG} match their signed digests"
}

case "${CMD}" in
signatures) cmd_signatures ;;
digests) cmd_digests ;;
*) die "usage: release-verify.sh signatures|digests <tag> [dir]" ;;
esac
