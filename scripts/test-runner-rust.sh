#!/usr/bin/env bash
# Exercise goneat's Rust formatter and clippy with the runner's bundled toolchain.
# shellcheck disable=SC2016 # Single-quoted commands expand inside the container.
set -euo pipefail

TAG="${1:?usage: test-runner-rust.sh <image-tag>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/tests/fixtures/rust"

run() {
	docker run --rm -e CARGO_TARGET_DIR=/tmp/toolbox-rust-target -v "$FIXTURES:/fixture:ro" "$TAG" -c "$1"
}

echo "▶ bundled goneat, Rust and scanner versions in $TAG"
run 'goneat version | grep -q "goneat v0.6.1" && cargo --version && rustfmt --version && cargo clippy --version && cargo deny --version | grep -q "0.20.2"'
run 'cd /fixture/good && cargo deny check licenses'

case "$TAG" in
*-runner-musl:*)
	# Upstream distributes only a glibc cargo-audit archive for arm64.
	run 'set -e
		if [ "$(uname -m)" = aarch64 ]; then
			test -x /usr/local/bin/cargo-audit || exit 1
			readelf -h /usr/local/bin/cargo-audit | grep -q "Machine:.*AArch64" || exit 1
			readelf -l /usr/local/bin/cargo-audit | grep -q "/lib/ld-linux-aarch64.so.1" || exit 1
			if output=$(cargo audit --version 2>&1); then
				echo "❌ unexpected cargo-audit support on arm64 musl" >&2; exit 1
			fi
			echo "$output" | grep -Eq "Error relocating .*/cargo-audit: __res_init: symbol not found|/lib/ld-linux-aarch64.so.1: (not found|No such file)" || {
				echo "❌ unexpected cargo-audit failure: $output" >&2; exit 1
			}
			echo "cargo-audit glibc arm64 artifact is present but unusable on musl"
		else
			cargo audit --version | grep -q "0.22.2"
			cargo audit --no-yanked --file /fixture/good/Cargo.lock
		fi'
	;;
*) run 'cargo audit --version | grep -q "0.22.2" && cargo audit --no-yanked --file /fixture/good/Cargo.lock' ;;
esac

echo '▶ Rust formatting passes on clean fixture'
run 'goneat format --check /fixture/good'

echo '▶ Rust formatting fails for drift, not missing tools'
if output=$(run 'goneat format --check /fixture/bad-format' 2>&1); then
	echo '❌ expected Rust format drift' >&2
	exit 1
fi
if printf '%s\n' "$output" | grep -qE 'result_class=tool-unavailable|tool-unavailable=[1-9]|files failed to process'; then
	echo "❌ Rust formatting did not execute: $output" >&2
	exit 1
fi
printf '%s\n' "$output" | grep -qi 'need formatting' || {
	echo "❌ expected Rust format drift: $output" >&2
	exit 1
}

echo '▶ assessment runs Rust formatting and clippy on clean fixture'
run 'goneat assess --check --categories format,lint /fixture/good'

echo '▶ clippy compiler error fails the lint category'
if output=$(run 'goneat assess --check --categories lint /fixture/bad-clippy' 2>&1); then
	echo '❌ expected clippy compiler error to fail assessment' >&2
	exit 1
fi
if ! printf '%s\n' "$output" | grep -qi 'cargo-clippy failed: cargo clippy'; then
	echo "❌ lint failed without clippy/Cargo error evidence: $output" >&2
	exit 1
fi

echo "✅ ${TAG} Rust format/clippy parity OK"
