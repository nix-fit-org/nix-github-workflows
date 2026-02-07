# nix-github-workflows

Reusable GitHub Actions workflows for the nix-fit-org organization.

## Workflows

### helm-publish.yml

Builds and pushes Helm charts to an OCI registry with automatic versioning.

**Versioning scheme:**

| Event | Version | Example |
|-------|---------|---------|
| Push to feature branch | `<version>-dev.<branch-name>` | `1.2.1-dev.feat-new-feature` |
| Push to main | `<version>-snapshot` + auto-tag | `1.2.1-snapshot` |
| Push tag `v*` | `<version>` (release) | `1.2.1` |

**Steps:** login → dependency update → lint → template → package → push → auto-tag (on main)

**Usage:**

```yaml
name: Helm Publish

on:
  push:
    tags: ['v*']
    branches: ['**']
  workflow_dispatch:

permissions:
  contents: write

jobs:
  helm-publish:
    uses: nix-fit-org/nix-github-workflows/.github/workflows/helm-publish.yml@main
    secrets: inherit
```

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

### helm-validate.yml

Validates Helm charts in pull requests. Ensures the chart version is bumped compared to main and checks that `README.md` is up to date with `helm-docs`.

**Usage:**

```yaml
name: Helm Validate

on:
  pull_request:
    branches: [main]

jobs:
  helm-validate:
    uses: nix-fit-org/nix-github-workflows/.github/workflows/helm-validate.yml@main
```

**Inputs:**

| Input | Default | Description |
|-------|---------|-------------|
| `chart_path` | `.` | Path to chart directory |
| `helm_docs_version` | `v1.14.2` | helm-docs version |

### ci.yml

Lints all workflow files in this repository using [actionlint](https://github.com/rhysd/actionlint).

## Setup

### Organization secrets

Configure once in GitHub > `nix-fit-org` > Settings > Secrets and variables > Actions:

- `REGISTRY_USERNAME` - OCI registry login
- `REGISTRY_PASSWORD` - OCI registry password

Set access policy to "All repositories" or select specific repos.

### Branch protection (recommended)

For each Helm chart repository, configure branch protection for `main`:

- Require status checks: `Helm Validate`
- Require pull request reviews (optional)
