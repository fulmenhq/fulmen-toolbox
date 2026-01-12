#!/usr/bin/env sh

# bootstrap-tools.sh
# Trust-anchor bootstrap for local development tooling:
# - Requires sfetch (verified via self-verify)
# - Uses sfetch to install goneat (pinned version)
# - Uses goneat to install repo toolchain via .goneat/tools.yaml
#
# This script does NOT install Docker runtimes (Colima/Docker Desktop) or Docker
# Compose; those are prerequisites and are validated separately.

set -eu

# Config
GONEAT_VERSION="${GONEAT_VERSION:-v0.4.4}"

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
		echo "→ Installing goneat $GONEAT_VERSION to $bindir" >&2
		"$sfetch" --repo fulmenhq/goneat --tag "$GONEAT_VERSION" --dest-dir "$bindir"
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
