# helm-validate + helm-publish

Workflows for Helm chart repositories (`helm-*`).

## helm-validate.yml

Validates a Helm chart before publication.

**Checks:**

| Check | Runs on | Description |
|-------|---------|-------------|
| Version bump | Feature branches | Chart version must be greater than in `main` |
| Docs freshness | All branches | `README.md` must be up to date with `helm-docs` |

**Inputs:**

| Input | Default | Description |
|-------|---------|-------------|
| `chart_path` | `.` | Path to chart directory |
| `helm_docs_version` | `v1.14.2` | helm-docs version |

---

## helm-publish.yml

Builds and pushes a Helm chart to the OCI registry with automatic versioning.

**Versioning:**

| Event | Tag | Example |
|-------|-----|---------|
| Push to feature branch | `<version>-dev` | `1.2.1-dev` |
| Push to `main` | `<version>-rc` + auto-tag `v<version>` | `1.2.1-rc` |
| Push tag `v*` | `<version>` | `1.2.1` |

**Steps:** login → dependency update → lint → template → package → push → auto-tag (on `main`)

**Inputs:**

| Input | Default | Description |
|-------|---------|-------------|
| `registry` | `nix-docker.registry.twcstorage.ru` | OCI registry URL |
| `chart_path` | `.` | Path to chart directory |
| `registry_path` | `helm/charts` | Path in the registry (e.g. `helm/libs`, `helm/templates`) |
| `push` | `true` | Whether to push the chart to the registry |
| `helm_version` | `v4.1.0` | Helm CLI version |

**Secrets:** `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `GH_PAT`

---

## Usage

```yaml
# .github/workflows/ci.yml
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
    uses: nix-fit-org/nix-github-workflows/.github/workflows/helm-publish.yml@main
    with:
      registry_path: helm/templates
    secrets: inherit
```
