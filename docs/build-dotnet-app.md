# build-dotnet-app

Builds and pushes a Docker image for a .NET backend application, publishes a Helm chart, and creates a release tag. For `back-app-*` repositories.

App name and Helm chart name are derived from the repository name automatically (`back-app-platform` → `platform`).
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

| Branch | Docker tag | Helm tags |
|--------|-----------|-----------|
| Feature branch | `{version}-snapshot` | `{version}-snapshot` + `:snapshot` |
| `main` | `{version}` | `{version}` |

All images and charts go to the same registry path. On feature branches, after pushing the versioned chart tag, it is copied to the mutable `:snapshot` tag via `skopeo copy`. The dev cluster always pulls from `:snapshot` — no ImagePolicy involved.

A git tag `v<version>` is created in the app repo on each `main` push.

## Dockerfile

Multi-stage build on UBI10-minimal:

1. **dotnet** — installs `dotnet-sdk-{DOTNET_VERSION}` from default UBI10 repos
2. **builder** — `dotnet restore` + `dotnet publish` (self-contained, architecture-aware via `TARGETARCH`)
3. **runtime** — clean UBI10-minimal + `libicu`, compiled binary at `/dist/app`

The Dockerfile and `.dockerignore` are fetched from `nix-github-workflows/resources/` via sparse checkout — no need to commit them to the app repo. The `CSPROJ_PATH` build arg tells the builder which project to publish.

## Flux

The workflow triggers Flux reconciliation after each push:

| Branch | Reconcile |
|--------|-----------|
| Feature branch | `flux reconcile helmrelease {app} --with-source` — forces Flux to re-fetch the `:snapshot` OCI tag by digest |
| `main` | Full chain: ImageRepository → ImagePolicy → ImageUpdateAutomation (commits new tag to gitops) → kustomization → helmrelease |

Required Flux resources in the gitops repo (per app):
- `ImageRepository {app}-chart` — watches `helm/apps/back/{app}`
- `ImagePolicy {app}-chart-release` — references `{app}-chart`, semver range without pre-release (e.g. `>=0.0.1000 <1.0.0000`)
- OCIRepository in dev overlay patched to `ref.tag: snapshot` (no ImagePolicy marker)

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `csproj_path` | yes | — | Path to the main `.csproj` file |
| `platforms` | no | `linux/amd64` | Target platforms |
| `dotnet_major_version` | no | `9` | .NET major version |
| `dotnet_version` | no | `9.0` | .NET SDK version (e.g. `9.0`, `10.0`) |
| `helm_template_branch` | no | `main` | Branch of `helm-dotnet-template` to use |
| `flux_helm_release_namespace` | no | `backend` | Namespace of the HelmRelease in the dev cluster |
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
    uses: nix-fit-org/nix-github-workflows/.github/workflows/build-dotnet-app.yml@main
    permissions:
      contents: write
    with:
      csproj_path: 'src/MobileBff/MobileBff.csproj'
      dotnet_major_version: '9'
      dotnet_version: '9.0'
    secrets: inherit
```
