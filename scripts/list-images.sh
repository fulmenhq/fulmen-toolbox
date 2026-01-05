#!/usr/bin/env bash
# list-images.sh
# Emit the canonical image list from manifests/tools.json.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_JSON="$ROOT/manifests/tools.json"
FORMAT="newline"

usage() {
	cat <<'EOF'
Usage:
  scripts/list-images.sh [--format newline|space]

Examples:
  scripts/list-images.sh
  scripts/list-images.sh --format space
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
	--format)
		FORMAT="${2:-}"
		if [ -z "$FORMAT" ]; then
			echo "--format requires a value" >&2
			usage
			exit 2
		fi
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage
		exit 2
		;;
	esac
done

if [ ! -f "$TOOLS_JSON" ]; then
	echo "tools manifest missing: $TOOLS_JSON" >&2
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	echo "jq is required to list images" >&2
	exit 1
fi

images=$(jq -r '[.tools[].images[]] | unique | .[]' "$TOOLS_JSON")

case "$FORMAT" in
newline)
	printf "%s\n" "$images"
	;;
space)
	printf "%s" "$images" | tr '\n' ' ' | xargs
	;;
*)
	echo "Unknown format: $FORMAT" >&2
	usage
	exit 2
	;;
esac
