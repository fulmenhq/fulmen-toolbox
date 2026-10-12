# Fulmen Toolbox - AI Agent Guide

**Project**: fulmen-toolbox  
**Purpose**: Monorepo for FulmenHQ Docker tool images  
**Governance Model**: 3leaps Initiative

## 🚨 CRITICAL: NEVER DO THESE THINGS

### ❌ NEVER COMMIT PLANS TO GIT

**.plans/ is GITIGNORED – LOCAL ONLY**

```bash
# ❌ WRONG
git add .plans/
git commit .plans/

# ✅ CORRECT – Plans stay local
```

### ❌ NEVER PUSH WITHOUT APPROVAL

Require per-incident human approval (see Git Safety below).

## Read First

1. Read `MAINTAINERS.md`
2. Read `AGENTS.md`
3. Follow the safety checklists

## Operating Model

| Aspect         | Setting                                  |
| -------------- | ---------------------------------------- |
| Mode           | Supervised (human reviews before commit) |
| Classification | code-substantive                         |
| Role Required  | Yes                                      |
| Default Role   | `devlead`                                |
| Identity       | Per session (no persistent memory)       |

See the [agent identity standard](https://crucible.3leaps.dev/repository/agent-identity) for modes and attribution.

## Role Catalog (Crucible v0.3.0)

This repo adopts Crucible’s agentic interface. We are **not** synced to Crucible yet, so role YAML files are not present here.
Use the role IDs below and keep attribution aligned with the Crucible standard until we sync.

| Role ID    | Intended Use                                                      |
| ---------- | ----------------------------------------------------------------- |
| `devlead`  | Dockerfiles, manifests, Makefile, CI workflows, release tooling   |
| `releng`   | Complex release, publication, signing, and provenance engineering |
| `secrev`   | Security review: signing, SBOM, SLSA, policy                      |
| `infoarch` | Documentation, runbooks, standards                                |

Pick the role that matches the task (most changes in this repo use `devlead`).

## Operational Guidelines (Container Repo Focus)

**DO** (Dockerfile/CI-centric):

- Optimize Dockerfiles (multi-stage, pins)
- Enhance Makefile (build/test/sbom targets)
- Update workflows (path-triggers, attestations)
- Curate tools/inventory/manifests

**DO NOT**:

- Add unrelated app code (tools-only images)
- Manual `docker build` (use make)
- Commit generated SBOMs (CI artifacts)
- Push without approval

### Build Ops

**DO**:

```bash
make build-goneat-tools  # ✅ Proper
```

**DO NOT**:

```bash
docker build .  # ❌ Use make
```

### Git Safety (MANDATORY Checklist)

- [ ] Local-only or remote?
- [ ] Explicit human approval?
- [ ] `git status` clean?

**Level 1 (NEVER w/o approval)**: push, force-push, tags

### Post-Mutation Tree Check (MANDATORY after mutating targets)

Several `make` targets in this repo **mutate** the working tree as a side
effect — most notably `make pr-final` (runs `goneat format` first) and
parts of `make prepush`. After invoking any such target, **always run `git
status` and inspect the diff** before claiming success or moving on. New
formatter drift discovered this way must either be (a) committed in the
same branch as a small `style:`-prefixed follow-up, or (b) explicitly
discussed with the human reviewer if the diff exceeds the agent's brief.

Failure mode: agent runs `make pr-final`, sees `✅ pr-final clean`, commits
their intended changes, pushes — and silently leaves a dirty tree of
formatter-touched files for the next agent or PR. The CI gate may not
catch it (path-filtered workflows skip docs-only drift), so the discovery
loop is only the next maintainer. Cheap to prevent; expensive to clean
up retroactively.

Targets known to mutate:

- `make pr-final` — runs `goneat format` (touches md/json/yaml repo-wide)
- `make fmt-sh` — runs shfmt with `-w` (touches scripts/\*.sh)
- Any future `make fmt-*` or `goneat format`-wrapping target

## Release Operations

Any tag-cutting work — pushing `vX.Y.Z`, recovering from a partial release, changing the release workflow itself — must follow `RELEASE_CHECKLIST.md`. **Read it in full before starting**; it is non-trivial and has been hardened by real incidents (v0.4.1 SIGILL partial-release, scheduled-workflow drift). Skim-reading misses critical gates.

Two gate categories the checklist enforces that an agent might otherwise miss:

- **Pre-PR**: working-tree cleanliness, pin validation, doc updates, local checks (`make pr-final`, `make validate-licenses`).
- **Pre-release-push**: full main CI green across **all** workflows, not just PR status. Scheduled workflows (`cve-scan`) and path-filtered ones (`validate-manifest`) can be silently broken on main while PRs pass. The checklist has a concrete `gh run list` command for this; run it immediately before tagging.

If superseding a previous partial release (e.g. v0.4.1 → v0.4.2): delete the prior GitHub release page **immediately before** tagging the new release. Minimizes the consumer-confusion window where the old page is gone but the new release isn't yet published. The git tag of the partial release stays in history for traceability.

Release planning artifacts live in `.plans/active/v<x.y.z>/brief.md` (gitignored — local-only per-version context for fresh-conversation agents). Predecessor briefs are kept under the same path for cross-release diagnosis traceability.

## Commit Attribution Standard

Follow the [3leaps commit style](https://crucible.3leaps.dev/repository/commit-style). Every AI-assisted commit message **and** every PR body ends with this three-line footer, after one blank line:

```
Role: <role>
Co-authored-by: <Model> <noreply@3leaps.net>
Committer-of-Record: @3leapsdave
```

**Required elements:**

1. Conventional commit subject (`<type>(<scope>): <subject>`) and a body describing the change
2. `Role:` — the bare role slug from the Role Catalog (e.g. `devlead`); never a bot username or team-prefixed label
3. `Co-authored-by:` — the actual model name, email `<noreply@3leaps.net>`
4. `Committer-of-Record:` — exactly `@3leapsdave` (last line)

A `Changes:` list and a `Generated by …` line are optional body text, not part of the footer. Squash merges use the PR body as the commit message, so the PR body must end with the same footer.

**Example:**

```
feat: optimize goneat-tools multi-stage build

Reduce image size by consolidating RUN layers and removing
intermediate build artifacts.

Changes:
- Merge RUN commands to reduce layer count
- Add explicit cleanup of apk cache
- Pin base image to alpine:3.21

Role: devlead
Co-authored-by: Claude Sonnet 4.6 <noreply@3leaps.net>
Committer-of-Record: @3leapsdave
```

## Coordination

- **Mattermost**: Human-monitored FulmenHQ channels for async collab
- **Human Lead**: @3leapsdave

**Last Updated**: 2026-10-12
