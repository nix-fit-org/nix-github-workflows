# build-nodejs-app

Builds and pushes a Docker image for a Node.js frontend application, publishes a Helm chart, and creates a release tag. For `front-app-*` repositories.

App name and Helm chart name are derived from the repository name automatically (`front-app-nix` → `nix`).
Version is determined by [GitVersion](https://gitversion.net/) using the `TrunkBased/preview1` strategy with conventional commits.

## Versioning

Commit message prefixes control version bumps:

| Prefix | Bump |
|--------|------|
| `feat:` / `feat(scope):` / `feature:` | minor |
| `fix:` / `fix(scope):` / `perf:` | patch |
| `feat!:` / `fix!:` / `feat(scope)!:` | major (breaking change) |
| `BREAKING CHANGE:` в футере коммита | major (breaking change) |
| anything else | no bump |

Examples:

```
feat: Add login page             → 0.2.0  minor
feat(auth): Add OAuth            → 0.3.0  minor (scope не влияет)
feature: Add dashboard           → 0.4.0  minor (feature = feat)
fix: Fix null pointer            → 0.4.1  patch
fix(api): Handle timeout         → 0.4.2  patch
perf: Optimize queries           → 0.4.3  patch
refactor: Clean up code          → 0.4.3  no bump
chore: Update deps               → 0.4.3  no bump
feat!: Drop v1 API               → 1.0.0  major (breaking)
fix(auth)!: Change token format  → 2.0.0  major (breaking, scoped)
feat: Add new endpoint           → 2.1.0  minor
```

Breaking change через футер (пустая строка обязательна):

```
feat: Add new auth method

BREAKING CHANGE: old tokens no longer valid
```

| Branch | Docker tag | Helm tags |
|--------|-----------|-----------|
| Feature branch | `{version}-snapshot` | `{version}-snapshot` + `:snapshot` |
| `main` | `{version}` | `{version}` |

All images and charts go to the same registry path. On feature branches, after pushing the versioned chart tag, it is copied to the mutable `:snapshot` tag via `skopeo copy`. The dev cluster always pulls from `:snapshot` — no ImagePolicy involved.

A git tag `v<version>` is created in the app repo on each `main` push.

## Flux

The workflow triggers Flux reconciliation after each push:

| Branch | Reconcile |
|--------|-----------|
| Feature branch | `flux reconcile helmrelease {app} --with-source` — forces Flux to re-fetch the `:snapshot` OCI tag by digest |
| `main` | Full chain: ImageRepository → ImagePolicy → ImageUpdateAutomation (commits new tag to gitops) → kustomization → helmrelease |

Required Flux resources in the gitops repo (per app):
- `ImageRepository {app}-chart` — watches `helm/apps/front/{app}`
- `ImagePolicy {app}-chart-release` — references `{app}-chart`, semver range without pre-release (e.g. `>=0.0.1000 <1.0.0000`)
- OCIRepository in dev overlay patched to `ref.tag: snapshot` (no ImagePolicy marker)

## Dockerfile

The Dockerfile and `.dockerignore` are fetched from `nix-github-workflows/resources/` via sparse checkout — no need to commit them to the app repo. The Node.js version is controlled via workflow inputs.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `platforms` | no | `linux/amd64` | Target platforms |
| `nodejs_major_version` | no | `22` | Node.js major version (e.g. `22`, `24`) |
| `nodejs_version` | no | `22.20.0` | Node.js full version (e.g. `22.20.0`) |
| `helm_template_branch` | no | `main` | Branch of `helm-nodejs-template` to use |
| `flux_helm_release_namespace` | no | `frontend` | Namespace of the HelmRelease in the dev cluster |
| `test_release` | no | `false` | Force release versioning on non-release branch |

## Secrets

| Secret | Description |
|--------|-------------|
| `REGISTRY_USERNAME` | OCI registry login |
| `REGISTRY_PASSWORD` | OCI registry password |
| `GH_PAT` | GitHub PAT (`repo` + `read:packages` scopes) — for sparse checkout and git tag push |
| `FLUX_KUBECONFIG_DEV` | Kubeconfig for the dev cluster (used to trigger Flux reconciliation) |

## Usage

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: ['**']

jobs:
  build:
    uses: nix-fit-org/nix-github-workflows/.github/workflows/build-nodejs-app.yml@main
    permissions:
      contents: write
    with:
      nodejs_major_version: '22'
      nodejs_version: '22.20.0'
    secrets: inherit
```
