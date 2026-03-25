#!/usr/bin/env sh

# bootstrap-tools.sh
# Trust-anchor bootstrap for local development tooling:
# - Requires sfetch (verified via self-verify)
# - Uses sfetch to install goneat (pinned version)
# - Uses goneat to install repo toolchain via .goneat/tools.yaml
#
# This script does NOT install Docker runtimes (Colima/Docker Desktop) or Docker
# Compose; those are prerequisites and are validated separately.
#
# Usage: bootstrap-tools.sh [--goneat-version <ver>]
#   --goneat-version  Goneat version to install (default: from GONEAT_VERSION env
#                     or Makefile pin)

set -eu

fail() {
	echo "error: $*" >&2
	exit 1
}

usage() {
	cat <<'EOF' >&2
Usage: bootstrap-tools.sh [--goneat-version <ver>]

Options:
  --goneat-version <ver>  Goneat version tag to install (e.g., v0.5.9)
                          Falls back to GONEAT_VERSION env, then Makefile pin.
  -h, --help              Show this help message.
EOF
	exit 1
}

# Read GONEAT_VERSION from Makefile as the repo-level default
read_makefile_goneat_version() {
	root="$1"
	if [ -f "$root/Makefile" ]; then
		mk_ver="$(grep -E '^GONEAT_VERSION\s*\?=' "$root/Makefile" | head -n1 | sed 's/.*?=\s*//' | tr -d ' \t\r')"
		if [ -n "$mk_ver" ]; then
			echo "$mk_ver"
			return
		fi
	fi
	echo ""
}

resolve_bindir() {
	# Prefer user-local bin
	if [ -n "${BINDIR:-}" ]; then
		echo "$BINDIR"
		return
	fi

	os_raw="$(uname -s 2>/dev/null || echo unknown)"
	case "$os_raw" in
	MINGW* | MSYS* | CYGWIN*)
		if [ -n "${USERPROFILE:-}" ]; then
			if command -v cygpath >/dev/null 2>&1; then
				echo "$(cygpath -u "$USERPROFILE")/bin"
			else
				echo "$USERPROFILE/bin"
			fi
		elif [ -n "${HOME:-}" ]; then
			echo "$HOME/bin"
		else
			echo "./bin"
		fi
		;;
	*)
		if [ -n "${HOME:-}" ]; then
			echo "$HOME/.local/bin"
		else
			echo "./bin"
		fi
		;;
	esac
}

find_cmd() {
	cmd="$1"
	bindir="$2"

	if [ -x "$bindir/$cmd" ]; then
		echo "$bindir/$cmd"
		return
	fi

	path_cmd="$(command -v "$cmd" 2>/dev/null || true)"
	if [ -n "$path_cmd" ]; then
		echo "$path_cmd"
		return
	fi

	echo ""
}

main() {
	root="$(cd "$(dirname "$0")/.." && pwd)"

	# Parse args
	arg_goneat_version=""
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help) usage ;;
		--goneat-version)
			[ $# -ge 2 ] || fail "--goneat-version requires a value"
			arg_goneat_version="$2"
			shift 2
			;;
		*)
			fail "unknown argument: $1"
			;;
		esac
	done

	# Resolve goneat version: arg > env > Makefile pin
	if [ -n "$arg_goneat_version" ]; then
		goneat_version="$arg_goneat_version"
	elif [ -n "${GONEAT_VERSION:-}" ]; then
		goneat_version="$GONEAT_VERSION"
	else
		goneat_version="$(read_makefile_goneat_version "$root")"
		[ -n "$goneat_version" ] || fail "could not determine goneat version (pass --goneat-version, set GONEAT_VERSION, or ensure Makefile has GONEAT_VERSION)"
	fi

	bindir="$(resolve_bindir)"
	mkdir -p "$bindir"

	sfetch="$(find_cmd sfetch "$bindir")"
	if [ -z "$sfetch" ]; then
		echo "❌ sfetch not found (required trust anchor)." >&2
		echo "Install sfetch, verify it, then re-run bootstrap:" >&2
		echo "  curl -sSfL https://github.com/3leaps/sfetch/releases/latest/download/install-sfetch.sh | bash" >&2
		echo "  sfetch --self-verify" >&2
		exit 1
	fi

	echo "→ sfetch self-verify (trust anchor)"
	"$sfetch" --self-verify

	goneat="$(find_cmd goneat "$bindir")"
	if [ -z "$goneat" ]; then
		echo "→ Installing goneat $goneat_version to $bindir" >&2
		"$sfetch" --repo fulmenhq/goneat --tag "$goneat_version" --dest-dir "$bindir"
		goneat="$bindir/goneat"
	fi

	if [ ! -x "$goneat" ]; then
		echo "❌ goneat install failed (expected executable at $goneat)" >&2
		exit 1
	fi

	echo "→ goneat: $($goneat --version 2>&1 | head -n1 || true)" >&2

	if [ ! -f "$root/.goneat/tools.yaml" ]; then
		echo "❌ missing $root/.goneat/tools.yaml" >&2
		exit 1
	fi

	echo "→ Validating .goneat/tools.yaml" >&2
	"$goneat" doctor tools --config "$root/.goneat/tools.yaml" --validate-config

	echo "→ Installing repo foundation tools via goneat doctor" >&2
	"$goneat" doctor tools \
		--config "$root/.goneat/tools.yaml" \
		--scope foundation \
		--install \
		--install-package-managers \
		--yes \
		--no-cooling

	echo "✅ Tool bootstrap complete (ensure $bindir is on PATH)" >&2
}

main "$@"
