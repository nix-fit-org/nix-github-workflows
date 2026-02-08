# nix-github-workflows

Reusable GitHub Actions workflows for the nix-fit-org organization.

## Workflows

### helm-validate.yml

Validates Helm charts. Designed to run before `helm-publish` on every push.

**Checks:**

| Check | Runs on | Description |
|-------|---------|-------------|
| Version bump | Feature branches only | Ensures chart version is greater than in main |
| Docs freshness | All branches | Verifies `README.md` is up to date with `helm-docs` |

Version bump check is automatically skipped on `main` and tags `v*`.

**Inputs:**

| Input | Default | Description |
|-------|---------|-------------|
| `chart_path` | `.` | Path to chart directory |
| `helm_docs_version` | `v1.14.2` | helm-docs version |

### helm-publish.yml

Builds and pushes Helm charts to an OCI registry with automatic versioning.

**Versioning scheme:**

| Event | Version | Example |
|-------|---------|---------|
| Push to feature branch | `<version>-dev` | `1.2.1-dev` |
| Push to main | `<version>-rc` + auto-tag | `1.2.1-rc` |
| Push tag `v*` | `<version>` (release) | `1.2.1` |

**Steps:** login → dependency update → lint → template → package → push → auto-tag (on main)

**Inputs:**

| Input | Default | Description |
|-------|---------|-------------|
| `registry` | `nix-docker.registry.twcstorage.ru` | OCI registry URL |
| `chart_path` | `.` | Path to chart directory |
| `registry_path` | `helm/charts` | Path in the registry (e.g. `helm/charts`, `helm/libs`) |
| `helm_version` | `v4.1.0` | Helm CLI version |

**Secrets (via organization secrets):**

- `REGISTRY_USERNAME`
- `REGISTRY_PASSWORD`
- `GH_PAT`

### ci.yml

Lints all workflow files in this repository using [actionlint](https://github.com/rhysd/actionlint).

## Usage

Combine both workflows in a single `ci.yml` in your Helm chart repository:

```yaml
name: CI

on:
  push:
    tags: ['v*']
    branches: ['**']
  workflow_dispatch:

permissions:
  contents: write

jobs:
  validate:
    uses: nix-fit-org/nix-github-workflows/.github/workflows/helm-validate.yml@main

  publish:
    needs: validate
    if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
    uses: nix-fit-org/nix-github-workflows/.github/workflows/helm-publish.yml@main
    with:
      registry_path: helm/templates  # default: helm/charts
    secrets: inherit
```

## Setup

### Organization secrets

Configure once in GitHub > `nix-fit-org` > Settings > Secrets and variables > Actions:

- `REGISTRY_USERNAME` - OCI registry login
- `REGISTRY_PASSWORD` - OCI registry password
- `GH_PAT` - GitHub PAT for auto-tagging

Set access policy to "All repositories" or select specific repos.
