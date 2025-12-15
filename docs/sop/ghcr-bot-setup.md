# SOP: GHCR Bot Setup (Org-wide)

This SOP defines the fallback, org-wide approach for authenticating to GitHub Container Registry (GHCR) using a classic Personal Access Token (PAT) with packages-only scope.

Preferred approach: use `GITHUB_TOKEN` from GitHub Actions with workflow `permissions: packages: write` (short-lived; no long-lived secrets).

Use this SOP only when org policy or constraints prevent `GITHUB_TOKEN` from performing required GHCR operations, and you need a controlled, non-human identity for GHCR access.

## Summary

- Default (preferred): use `GITHUB_TOKEN` from GitHub Actions with workflow `permissions: packages: write`.
- Fallback (this SOP): create a dedicated machine user `fulmenhq-ghcr-bot` and a classic PAT with only:
  - `read:packages` and `write:packages`
  - (optional) `delete:packages` only if you need cleanup automation
- Store the PAT as an org secret (example name): `FULMENHQ_GHCR_TOKEN`.
- Store the bot username as an org variable (example name): `FULMENHQ_GHCR_USER=fulmenhq-ghcr-bot`.
- For PAT-based `docker login`, the username must match the PAT owner.

## When to use this

Use this pattern when one or more of the following is true:

- GHCR push/tag/inspect operations fail in CI under `GITHUB_TOKEN` due to org policy.
- You need consistent GHCR access across multiple repos.
- You want to avoid tying CI to a human maintainer identity.

If `GITHUB_TOKEN` works for your workflows, prefer it; it is short-lived and reduces secret management.

## Naming and separation-of-duties

Recommended: **use a GHCR-only bot account** (`fulmenhq-ghcr-bot`) rather than a general-purpose automation bot.

Rationale:

- Limits blast radius if the PAT leaks.
- Makes audits clearer: this identity exists specifically for container registry operations.
- Avoids coupling GHCR privileges to unrelated automation.

If you already have a general bot (e.g. `fulmenhq-bot`) and you intentionally want one identity, you can use it instead, but keep scopes tight.

## Step-by-step setup

### 1) Create the machine user

1. Create a new GitHub user: `fulmenhq-ghcr-bot`.
2. Enable strong auth:
   - Use a shared team-managed password vault entry.
   - Enable 2FA for the account.
3. Add the user to the `fulmenhq` GitHub org.
4. Grant the bot only the org membership/role it needs.
   - Prefer the lowest role possible.
   - For most GHCR publishing, membership plus package permissions is sufficient.

### 2) Ensure GHCR package permissions align

GHCR access is enforced at the package/org level.

Confirm:

- The `fulmenhq-ghcr-bot` user has permission to publish/update container packages under `ghcr.io/fulmenhq/*`.
- Any org policies that restrict packages publishing allow this user.

Notes:

- For private packages, the bot must be granted access.
- For public packages, org policy can still restrict write operations.

### 3) Create a classic PAT with packages-only scopes

Create a **classic** PAT on the bot account.

Scopes:

- Required: `read:packages`, `write:packages`
- Optional: `delete:packages` (only if you automate deletion)
- Avoid: `repo` (do not grant it for GHCR-only usage)

Important GitHub UI behavior: the normal token page can preselect `repo`.

Use these prefilled-scope URLs to keep `repo` unchecked/editable:

- Write packages only:
  - https://github.com/settings/tokens/new?scopes=write:packages
- Read + write packages:
  - https://github.com/settings/tokens/new?scopes=write:packages,read:packages
- Read + write + delete packages:
  - https://github.com/settings/tokens/new?scopes=write:packages,read:packages,delete:packages

Token hygiene:

- Set an expiration date.
- Record the expiration/rotation schedule in your ops tracker.
- Treat the PAT like any other long-lived secret.

### 4) Store org-wide secret and variable

In the `fulmenhq` org settings:

- Create an **org secret** named `FULMENHQ_GHCR_TOKEN` containing the bot’s PAT.
- Create an **org variable** named `FULMENHQ_GHCR_USER` set to `fulmenhq-ghcr-bot`.

Scope the secret/variable to only the repos that need it.

### 5) Consume in repos/workflows

In GitHub Actions workflows, the recommended pattern is:

- Prefer `GITHUB_TOKEN` when it works.
- If the PAT is present, use it **and** use the bot username.

Example pattern:

```yaml
env:
  REGISTRY: ghcr.io

jobs:
  release:
    runs-on: ubuntu-latest
    env:
      GHCR_TOKEN: ${{ secrets.FULMENHQ_GHCR_TOKEN }}
      GHCR_USER: ${{ vars.FULMENHQ_GHCR_USER }}

    steps:
      - name: Log in to GHCR (PAT)
        if: ${{ env.GHCR_TOKEN != '' }}
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ env.GHCR_USER }}
          password: ${{ env.GHCR_TOKEN }}

      - name: Log in to GHCR (GITHUB_TOKEN fallback)
        if: ${{ env.GHCR_TOKEN == '' }}
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ github.token }}
```

Why this matters: when using a classic PAT, GHCR expects the **username to match the PAT owner**; using `${{ github.actor }}` is brittle when multiple maintainers trigger workflows.

## Validation and troubleshooting

### Quick local auth test

```bash
export FULMEN_TOOLBOX_GHCR_TOKEN=ghp_...
# Username must match the PAT owner
echo "$FULMEN_TOOLBOX_GHCR_TOKEN" | docker login ghcr.io -u fulmenhq-ghcr-bot --password-stdin

docker manifest inspect ghcr.io/fulmenhq/goneat-tools-runner:latest >/dev/null
```

### Confirm token scopes (API header)

```bash
curl -sS -D - -o /dev/null \
  -H "Authorization: token $FULMEN_TOOLBOX_GHCR_TOKEN" \
  https://api.github.com/user \
  | rg -i '^x-oauth-scopes:'
```

Expected to include `read:packages` and/or `write:packages`.

## Rotation

- Rotate `FULMENHQ_GHCR_TOKEN` before expiration.
- After rotation, re-run at least one GHCR-pushing workflow (or a manual GHCR login test).
- If multiple repos consume the org secret, rotation is centralized and does not require per-repo changes.
