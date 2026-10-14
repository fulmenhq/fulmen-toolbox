#!/usr/bin/env bash

set -euo pipefail

# Verify signed per-image checksum manifests for a release.
#
# Usage: release-verify.sh signatures|digests|pin <tag> [dir]
#
#   signatures  every SHA256SUMS-<image> in <dir> has a .asc and a .minisig;
#               each .asc is exactly one good signature by the pinned signing
#               subkey, bound to the pinned primary, checked in a throwaway
#               keyring; each .minisig verifies with the pinned minisign key,
#               and its trusted comment names that image and <tag>
#   digests     runs the signatures check, then requires every image
#               reference listed in the manifests to resolve on the registry
#               to exactly the digest recorded for it
#   pin         checks the committed pin alone: anchors, keys, one signing
#               subkey, no secret key material (no manifests needed)
#
# Trust comes from the release-key pin committed in this repository, read as
# git objects from the pin ref (default refs/tags/<tag>), never from the
# working tree and never from <dir>:
#   keys/expected-fingerprints.txt   "gpg <primary>" then "minisign <sha256>"
#   docs/security/release-signing-keys.asc
#   docs/security/release-minisign.pub
# The public keys in <dir> (written by release-download or release-export-keys)
# are release assets; when present they must equal the pinned keys.
#
# Optional env (explicit overrides):
#   FULMEN_TOOLBOX_RELEASE_PIN_REF - git ref to read the pin from instead of the
#                                    tag (for example HEAD before tagging, or a
#                                    tag that predates the pin)
#   FULMEN_TOOLBOX_RELEASE_TRUST   - "pin" (default) or "env"; env takes the PGP
#                                    key file and minisign key from
#                                    FULMEN_TOOLBOX_TRUST_PGP_KEYS and
#                                    FULMEN_TOOLBOX_TRUST_MINISIGN_PUB, which
#                                    must be outside <dir> (rotation testing)

die() {
	echo "error: $*" >&2
	exit 1
}

CMD=${1:-}
TAG=${2:-}
DIR=${3:-dist/release}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIN_ANCHORS="keys/expected-fingerprints.txt"
PIN_PGP="docs/security/release-signing-keys.asc"
PIN_MINI="docs/security/release-minisign.pub"
ASSET_PGP="fulmen-toolbox-release-signing-key.asc"
ASSET_MINI="fulmenhq-release-signing.pub"

[ -n "${TAG}" ] || die "usage: release-verify.sh signatures|digests|pin <tag> [dir]"

# Trust inputs, set by load_trust.
TRUST_HOME=""
TRUST_PGP=""
TRUST_MINI=""
PRIMARY=""
SUBKEY=""
TRUST_SOURCE=""

cleanup() {
	if [ -n "${TRUST_HOME}" ]; then
		gpgconf --homedir "${TRUST_HOME}/gpg" --kill all >/dev/null 2>&1 || true
		rm -rf "${TRUST_HOME}"
	fi
}
trap cleanup EXIT

# Writes the committed regular file <path> at <commit> to <dest>.
committed() {
	local commit=$1 path=$2 dest=$3 mode type blob
	read -r mode type blob _ < <(git -C "${ROOT}" ls-tree "${commit}" -- "${path}") ||
		die "${path} is not committed in the pin ref (tags before the pin need FULMEN_TOOLBOX_RELEASE_PIN_REF)"
	{ [ "${type}" = "blob" ] && { [ "${mode}" = "100644" ] || [ "${mode}" = "100755" ]; }; } ||
		die "${path} in the pin ref is not a regular file"
	git -C "${ROOT}" cat-file blob "${blob}" >"${dest}"
	[ -s "${dest}" ] || die "${path} in the pin ref is empty"
}

minisign_key_sha256() {
	# Hash of the decoded key record (signature algorithm, key id, public key),
	# the same value goneat records in its anchors file.
	local pub=$1 lines
	lines=$(wc -l <"${pub}" | tr -d ' ')
	if [ "${lines}" != "2" ] || ! head -1 "${pub}" | grep -q '^untrusted comment:'; then
		die "${pub##*/} is not a minisign public key"
	fi
	sed -n 2p "${pub}" | base64 -d 2>/dev/null | { shasum -a 256 2>/dev/null || sha256sum; } | awk '{print $1}'
}

# Imports the PGP keys file and sets PRIMARY and SUBKEY; the file must hold
# exactly one primary, no secret key, and exactly one signing subkey.
import_pgp() {
	local keys=$1 listing
	gpg --homedir "${TRUST_HOME}/gpg" --batch --quiet --import "${keys}" 2>/dev/null ||
		die "cannot import ${keys##*/}"
	[ -z "$(gpg --homedir "${TRUST_HOME}/gpg" --batch --with-colons --list-secret-keys 2>/dev/null)" ] ||
		die "trusted PGP keys contain secret key material"
	listing=$(gpg --homedir "${TRUST_HOME}/gpg" --batch --with-colons --with-subkey-fingerprint --list-keys)
	[ "$(awk -F: '$1 == "pub" { n++ } END { print n + 0 }' <<<"${listing}")" = "1" ] ||
		die "trusted PGP keys must hold exactly one primary"
	PRIMARY=$(awk -F: '$1 == "fpr" { print $10; exit }' <<<"${listing}")
	SUBKEY=$(awk -F: '$1 == "sub" { s = 1; cap = $12; next } s && $1 == "fpr" { if (cap ~ /s/) print $10; s = 0 }' <<<"${listing}")
	[[ "${SUBKEY}" =~ ^[0-9A-F]{40}$ ]] || die "trusted PGP keys must hold exactly one signing subkey"
}

load_pin_trust() {
	local ref commit anchors want_primary want_mini
	command -v git >/dev/null || die "git is required"
	ref=${FULMEN_TOOLBOX_RELEASE_PIN_REF:-refs/tags/${TAG}}
	commit=$(git -C "${ROOT}" rev-parse --verify --quiet "${ref}^{commit}") ||
		die "pin ref not found: ${ref} (fetch the release tag, or set FULMEN_TOOLBOX_RELEASE_PIN_REF)"

	anchors="${TRUST_HOME}/anchors"
	committed "${commit}" "${PIN_ANCHORS}" "${anchors}"
	if [ "$(wc -l <"${anchors}" | tr -d ' ')" != "2" ] ||
		! awk 'NR == 1 && /^gpg [0-9A-F]{40}$/ { a = 1 } NR == 2 && /^minisign [0-9a-f]{64}$/ { b = 1 } END { exit !(a && b) }' "${anchors}"; then
		die "${PIN_ANCHORS} must be exactly a gpg line then a minisign line"
	fi
	want_primary=$(awk 'NR == 1 { print $2 }' "${anchors}")
	want_mini=$(awk 'NR == 2 { print $2 }' "${anchors}")

	TRUST_MINI="${TRUST_HOME}/minisign.pub"
	committed "${commit}" "${PIN_MINI}" "${TRUST_MINI}"
	[ "$(minisign_key_sha256 "${TRUST_MINI}")" = "${want_mini}" ] ||
		die "pinned minisign key differs from its anchor"

	TRUST_PGP="${TRUST_HOME}/keys.asc"
	committed "${commit}" "${PIN_PGP}" "${TRUST_PGP}"
	! grep -qi 'PRIVATE KEY' "${TRUST_PGP}" || die "pinned PGP keys contain private key armor"
	import_pgp "${TRUST_PGP}"
	[ "${PRIMARY}" = "${want_primary}" ] || die "pinned PGP primary ${PRIMARY} differs from its anchor ${want_primary}"

	TRUST_SOURCE="committed release-key pin at ${ref} (${commit:0:12})"
}

# Fails when <path> resolves inside <dir>.
outside_dir() {
	local path=$1 name=$2 abs dir
	[ -f "${path}" ] && [ ! -L "${path}" ] || die "${name} must be a regular file: ${path}"
	abs=$(cd "$(dirname "${path}")" && pwd -P)
	dir=$(cd "${DIR}" && pwd -P)
	case "${abs}/" in
	"${dir}/"*) die "${name} must be outside ${DIR}" ;;
	esac
}

load_env_trust() {
	local keys=${FULMEN_TOOLBOX_TRUST_PGP_KEYS:-} mini=${FULMEN_TOOLBOX_TRUST_MINISIGN_PUB:-}
	[ -n "${keys}" ] && [ -n "${mini}" ] ||
		die "FULMEN_TOOLBOX_RELEASE_TRUST=env needs FULMEN_TOOLBOX_TRUST_PGP_KEYS and FULMEN_TOOLBOX_TRUST_MINISIGN_PUB"
	outside_dir "${keys}" FULMEN_TOOLBOX_TRUST_PGP_KEYS
	outside_dir "${mini}" FULMEN_TOOLBOX_TRUST_MINISIGN_PUB
	minisign_key_sha256 "${mini}" >/dev/null
	TRUST_PGP=${keys}
	TRUST_MINI=${mini}
	import_pgp "${TRUST_PGP}"
	TRUST_SOURCE="operator environment (FULMEN_TOOLBOX_RELEASE_TRUST=env)"
}

load_trust() {
	command -v gpg >/dev/null || die "gpg is required"
	TRUST_HOME=$(mktemp -d "/tmp/rverify.XXXXXX")
	mkdir -m 700 "${TRUST_HOME}/gpg"
	case "${FULMEN_TOOLBOX_RELEASE_TRUST:-pin}" in
	pin) load_pin_trust ;;
	env) load_env_trust ;;
	*) die "FULMEN_TOOLBOX_RELEASE_TRUST must be pin or env" ;;
	esac
}

# The key assets published with a release must be the trusted keys. The
# minisign asset is compared byte for byte. The PGP asset must hold the
# trusted primary and signing subkey and no key the trust does not hold (it
# may omit the encryption subkey).
check_key_assets() {
	local asset home have trusted fpr
	asset="${DIR}/${ASSET_MINI}"
	if [ -e "${asset}" ]; then
		cmp -s "${asset}" "${TRUST_MINI}" || die "${ASSET_MINI} is not the trusted minisign key"
	fi
	asset="${DIR}/${ASSET_PGP}"
	if [ -e "${asset}" ]; then
		! grep -qi 'PRIVATE KEY' "${asset}" || die "${ASSET_PGP} contains private key armor"
		home="${TRUST_HOME}/asset-gpg"
		mkdir -m 700 "${home}"
		gpg --homedir "${home}" --batch --quiet --import "${asset}" 2>/dev/null || die "cannot import ${ASSET_PGP}"
		have=$(gpg --homedir "${home}" --batch --with-colons --with-subkey-fingerprint --list-keys |
			awk -F: '$1 == "fpr" { print $10 }')
		gpgconf --homedir "${home}" --kill all >/dev/null 2>&1 || true
		trusted=$(gpg --homedir "${TRUST_HOME}/gpg" --batch --with-colons --with-subkey-fingerprint --list-keys |
			awk -F: '$1 == "fpr" { print $10 }')
		for fpr in "${PRIMARY}" "${SUBKEY}"; do
			grep -qx "${fpr}" <<<"${have}" || die "${ASSET_PGP} does not hold the trusted key ${fpr}"
		done
		while read -r fpr; do
			grep -qx "${fpr}" <<<"${trusted}" || die "${ASSET_PGP} holds a key the trust does not: ${fpr}"
		done <<<"${have}"
	fi
}

# Sets MANIFESTS to the SHA256SUMS-<image> manifests in DIR. Fails when there
# are none, or when a .asc or .minisig has no manifest: release-upload would
# publish those signatures unverified.
MANIFESTS=()
load_manifests() {
	local m base
	for m in "${DIR}"/SHA256SUMS-*; do
		[ -e "${m}" ] || continue
		case "${m}" in
		*.asc | *.minisig)
			base=${m%.*}
			[ -f "${base}" ] || die "${m##*/} has no manifest ${base##*/}"
			continue
			;;
		esac
		[ -f "${m}" ] || die "${m##*/} is not a regular file"
		MANIFESTS+=("${m}")
	done
	[ "${#MANIFESTS[@]}" -gt 0 ] || die "no SHA256SUMS-* manifests in ${DIR}"
}

verify_pgp() {
	local m=$1 status record
	status=$(gpg --homedir "${TRUST_HOME}/gpg" --batch --no-auto-key-retrieve --status-fd 1 \
		--verify "${m}.asc" "${m}" 2>/dev/null) ||
		die "PGP verification failed for ${m##*/}"
	if printf '%s\n' "${status}" | grep -qE '^\[GNUPG:\] (BADSIG|ERRSIG|EXPSIG|EXPKEYSIG|REVKEYSIG|KEYREVOKED) '; then
		die "${m##*/}.asc has an expired, revoked, bad or unverifiable signature"
	fi
	[ "$(printf '%s\n' "${status}" | grep -c '^\[GNUPG:\] VALIDSIG ')" -eq 1 ] ||
		die "${m##*/}.asc is not exactly one good signature"
	read -r -a record < <(printf '%s\n' "${status}" | grep '^\[GNUPG:\] VALIDSIG ')
	[ "${record[2]}" = "${SUBKEY}" ] || die "${m##*/}.asc was not made by the pinned signing subkey ${SUBKEY}"
	[ "${record[${#record[@]} - 1]}" = "${PRIMARY}" ] || die "${m##*/}.asc is not bound to the pinned primary ${PRIMARY}"
}

cmd_signatures() {
	local count=0 m comment image
	command -v minisign >/dev/null || die "minisign is required"
	[ -d "${DIR}" ] || die "${DIR} is not a directory"
	load_trust
	check_key_assets

	load_manifests
	for m in "${MANIFESTS[@]}"; do
		[ -f "${m}.asc" ] || die "missing ${m}.asc"
		[ -f "${m}.minisig" ] || die "missing ${m}.minisig"
		verify_pgp "${m}"

		comment=$(minisign -Vm "${m}" -p "${TRUST_MINI}" 2>/dev/null | sed -n 's/^Trusted comment: //p') ||
			die "minisign verification failed for ${m##*/}"
		image=${m##*/SHA256SUMS-}
		if [ "${comment}" != "fulmen-toolbox ${image} ${TAG#v}" ]; then
			die "${m##*/}.minisig trusted comment '${comment}' is not 'fulmen-toolbox ${image} ${TAG#v}'"
		fi
		count=$((count + 1))
	done

	[ "${count}" -eq "${#MANIFESTS[@]}" ] || die "verified ${count} of ${#MANIFESTS[@]} manifests"
	echo "verified: ${count} manifest(s) for ${TAG} with PGP and minisign"
	echo "  trust source: ${TRUST_SOURCE}"
	echo "  pgp primary: ${PRIMARY}  signing subkey: ${SUBKEY}"
}

cmd_pin() {
	load_trust
	echo "pin consistent: pgp primary ${PRIMARY}, signing subkey ${SUBKEY}, minisign key $(minisign_key_sha256 "${TRUST_MINI}")"
	echo "  trust source: ${TRUST_SOURCE}"
}

cmd_digests() {
	local m name digest ref got total=0 bad=0
	command -v docker >/dev/null || die "docker (buildx imagetools) is required"
	# Digests are only meaningful from manifests that verify.
	(cmd_signatures) || die "manifest signatures did not verify; digests not checked"
	load_manifests
	for m in "${MANIFESTS[@]}"; do
		name=${m##*/}
		# The second test reads a final line that has no trailing newline.
		while read -r digest ref || [ -n "${digest}" ]; do
			[ -n "${digest}" ] || continue
			[[ "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]] || die "${name}: invalid digest '${digest}'"
			[[ "${ref}" =~ ^[a-z0-9][a-z0-9._/:@-]*$ ]] || die "${name}: invalid image reference '${ref}'"
			total=$((total + 1))
			got=$(docker buildx imagetools inspect --format '{{json .Manifest.Digest}}' -- "${ref}" 2>/dev/null | tr -d '"') || got=""
			if [ "${got}" != "${digest}" ]; then
				echo "mismatch: ${ref} signed ${digest} registry ${got:-unresolved}" >&2
				bad=$((bad + 1))
			fi
		done <"${m}"
	done
	[ "${total}" -gt 0 ] || die "no image references in the manifests"
	[ "${bad}" -eq 0 ] || die "${bad} of ${total} image reference(s) do not match their signed digest"
	echo "verified: ${total} image reference(s) for ${TAG} match their signed digests"
}

case "${CMD}" in
signatures) cmd_signatures ;;
digests) cmd_digests ;;
pin) cmd_pin ;;
*) die "usage: release-verify.sh signatures|digests|pin <tag> [dir]" ;;
esac
