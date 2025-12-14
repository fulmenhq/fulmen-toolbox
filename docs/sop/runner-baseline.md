# SOP: Runner Baseline Packages (Alpine)

Purpose: define the baseline packages we add to turn a minimal Alpine image into a general-purpose CI runner.

These packages are frequently assumed by CI tooling and composite actions.

## Notes

- Many “runner baseline” tools are GNU utilities and therefore copyleft (GPLv2/GPLv3). See `docs/adr/ADR-0004-copyleft-and-runner-images.md`.
- Our images run as **non-root** by default. If downstream workflows require package installation at runtime, they need a root-capable variant (or a derived image) rather than relying on `sudo`.

## Baseline package set

The SSOT for the runner baseline is `manifests/profiles.json` (`profiles.runner_baseline.packages`).

Recommended baseline packages (Alpine `apk` names):

| Package | Why it’s needed | Typical license family | Copyleft? |
|--------:|------------------|------------------------|----------:|
| `bash` | Common CI shell; `set -euo pipefail` scripts | GPL-3.0 | Yes |
| `git` | Repo operations in CI | GPL-2.0 | Yes |
| `make` | Build orchestration, Makefile-based tooling | GPL-3.0 | Yes |
| `curl` | Fetch release artifacts/installers | MIT-like | No |
| `ca-certificates` | TLS trust store for HTTPS downloads | Mozilla/varies | No |
| `tar` | Extract `.tar.*` assets | GPL-3.0 (GNU tar) | Yes |
| `gzip` | Extract `.tar.gz` assets | GPL-3.0 | Yes |
| `xz` | Extract `.tar.xz` assets | GPL-2.0+ (xz-utils CLI) | Yes |
| `unzip` | Extract `.zip` assets | Info-ZIP (permissive) | No |
| `coreutils` | Full-featured GNU userland (`sha256sum`, `date`, etc.) | GPL-3.0 | Yes |
| `findutils` | `find`, `xargs` expectations in scripts | GPL-3.0 | Yes |
| `diffutils` | `diff` behavior expected by many tools | GPL-3.0 | Yes |
| `openssh-client` | Fetch private deps over SSH | BSD-style | No |

Optional additions (only if needed):

(None currently.)

## How we document and ship licenses

- Alpine-provided license files (when available) are copied from `/usr/share/licenses` into `/licenses/alpine/`.
- Curated upstream license texts for other sources (Go modules, GitHub binaries, npm globals) are stored under `/licenses/github/*` and `/licenses/npm/*`.
- NOTICE/attribution files (when present) are stored under `/notices/*`.

See `docs/sop/licenses-and-notices.md` and ADR-0003.
