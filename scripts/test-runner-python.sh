#!/usr/bin/env bash
# test-runner-python.sh
# Python lint/format parity e2e for the goneat-tools runner images.
#
# Proves ruff is not merely installed but reachable by goneat's formatter
# dispatch:
#   tests/fixtures/python/good -> `goneat format --check` exits 0
#   tests/fixtures/python/bad  -> exits non-zero for FORMAT DRIFT
#
# The bad-fixture failure REASON carries the real assertion. goneat >= v0.5.15
# fails closed when a selected external formatter is unavailable, so an image
# WITHOUT ruff also fails `--check` on the bad fixture -- but reports
# `tool-unavailable=`. Only a genuine, dispatchable ruff yields the
# "files need formatting" drift message. Asserting on exit status alone would
# pass vacuously on a ruff-less image.

set -euo pipefail

TAG="${1:?usage: test-runner-python.sh <image-tag>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/tests/fixtures/python"

if [ ! -d "$FIXTURES/good" ] || [ ! -d "$FIXTURES/bad" ]; then
	echo "❌ python fixtures missing under $FIXTURES" >&2
	exit 1
fi

run() {
	docker run --rm -v "$FIXTURES:/fixture:ro" "$TAG" -c "$1"
}

echo "▶ ruff present in $TAG"
run 'ruff --version'

echo "▶ good fixture passes goneat format --check"
run 'goneat format --check /fixture/good'

echo "▶ bad fixture fails for format drift, not a missing tool"
if output=$(run 'goneat format --check /fixture/bad' 2>&1); then
	echo "❌ expected 'goneat format --check /fixture/bad' to fail, but it succeeded" >&2
	printf '%s\n' "$output" >&2
	exit 1
fi

# goneat >= v0.5.15 signals an unreachable formatter two different ways, and the
# guard must match both:
#
#   result_class=tool-unavailable  -- the preflight fails CLOSED and aborts the
#       run before execution. This is the usual path for a missing ruff, and it
#       emits NO per-class counters at all.
#   tool-unavailable=<n>           -- the per-run execution summary, reached only
#       when the run proceeds. It enumerates EVERY class, so 'tool-unavailable=0'
#       is present even on a clean format-drift run; only a nonzero count means
#       a tool was actually missing.
#
# Matching a bare 'tool-unavailable=' would false-positive on the =0 in every
# summary line; matching only the counter would miss the preflight abort, which
# is the very case this test exists to detect.
if printf '%s' "$output" | grep -qE 'result_class=tool-unavailable|tool-unavailable=[1-9]'; then
	echo "❌ bad fixture failed for a MISSING TOOL, not format drift." >&2
	echo "   ruff is not reachable by goneat's formatter dispatch in this image." >&2
	printf '%s\n' "$output" >&2
	exit 1
fi

# Pre-v0.5.15 goneat has no typed format errors -- it reports the generic
# "N files failed to process" instead of "N files need formatting". The drift
# assertion below cannot distinguish drift from anything else on such a build,
# so fail with the real cause rather than a misleading "unexpected reason".
if printf '%s' "$output" | grep -q 'files failed to process'; then
	echo "❌ this image's goneat predates the typed format errors (needs >= v0.5.15)." >&2
	echo "   Cannot verify the failure REASON on this build; check GONEAT_VERSION." >&2
	printf '%s\n' "$output" >&2
	exit 1
fi

if ! printf '%s' "$output" | grep -qi 'need formatting'; then
	echo "❌ bad fixture failed for an unexpected reason (expected format drift)" >&2
	printf '%s\n' "$output" >&2
	exit 1
fi

echo "✅ ${TAG} python lint/format parity OK"
