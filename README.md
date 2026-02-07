# nix-github-workflows

Reusable GitHub Actions workflows for the nix-fit-org organization.

## Workflows

### helm-publish.yml

Builds and pushes Helm charts to an OCI registry with automatic versioning.

**Versioning scheme:**

| Event | Version | Example |
|-------|---------|---------|
| Push to feature branch | `<version>-dev.<short-sha>` | `1.2.1-dev.a3f2b1c` |
| Push to main | `<version>-snapshot` + auto-tag | `1.2.1-snapshot` |
| Push tag `v*` | `<version>` (release) | `1.2.1` |

**Usage:**

```yaml
name: Helm Publish

on:
  push:
    tags: ['v*']
    branches: ['**']
  workflow_dispatch:

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
| `helm_version` | `v4.1.0` | Helm CLI version |

**Secrets (via organization secrets):**

- `REGISTRY_USERNAME`
- `REGISTRY_PASSWORD`

### helm-lint.yml

Validates Helm charts in pull requests. Ensures the chart version is bumped compared to main, runs `helm lint` and `helm template`.

**Usage:**

```yaml
name: Helm Lint

on:
  pull_request:
    branches: [main]

jobs:
  helm-lint:
    uses: nix-fit-org/nix-github-workflows/.github/workflows/helm-lint.yml@main
```

**Inputs:**

| Input | Default | Description |
|-------|---------|-------------|
| `chart_path` | `.` | Path to chart directory |
| `helm_version` | `v4.1.0` | Helm CLI version |

## Setup

### Organization secrets

Configure once in GitHub > `nix-fit-org` > Settings > Secrets and variables > Actions:

- `REGISTRY_USERNAME` - OCI registry login
- `REGISTRY_PASSWORD` - OCI registry password

Set access policy to "All repositories" or select specific repos.
