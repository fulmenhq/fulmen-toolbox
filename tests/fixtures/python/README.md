# Python fixtures — runner ruff / `goneat format` e2e

Used by `make test-goneat-tools-runner-python` (and its `-glibc` twin) to prove
Python lint/format parity in the `goneat-tools-runner-*` images.

| Path    | Expectation for `goneat format --check <dir>`                                               |
| ------- | ------------------------------------------------------------------------------------------- |
| `good/` | Exit 0 — already ruff-formatted.                                                            |
| `bad/`  | Non-zero, reporting **format drift** (`files need formatting`) — never `tool-unavailable=`. |

The `bad/` distinction is the point of the fixture. goneat `>= v0.5.15` fails
closed when a selected external formatter is missing, so an image without `ruff`
also fails `--check` — but with `tool-unavailable=`. Asserting on the failure
_reason_ is what separates "ruff is installed and working" from "ruff is
missing".

`bad/` is listed in the repository's `.goneatignore` so our own formatting runs
leave it unformatted.
