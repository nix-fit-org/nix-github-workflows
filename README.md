# nix-github-workflows

Reusable GitHub Actions workflows and composite actions for the nix-fit-org organization.

## Structure

```
.github/
  actions/
    docker-build/          # Composite action: versioning + build + push
    helm-from-template/    # Composite action: clone helm template + patch + push OCI
  workflows/
    build-docker-image.yml # docker-* repositories
    lint-dockerfile.yml    # docker template repositories (lint only)
    helm-validate.yml      # helm-* repositories (validate)
    helm-publish.yml       # helm-* repositories (publish)
    ci.yml                 # this repo: actionlint
```

## Docs

- [build-docker-image](docs/build-docker-image.md)
- [lint-dockerfile](docs/lint-dockerfile.md)
- [helm-validate + helm-publish](docs/helm.md)

## Organization secrets

Configure once in GitHub → `nix-fit-org` → Settings → Secrets and variables → Actions.

| Secret | Used by | Description |
|--------|---------|-------------|
| `REGISTRY_USERNAME` | all | OCI registry login |
| `REGISTRY_PASSWORD` | all | OCI registry password |
| `GH_PAT` | helm workflows | GitHub PAT (`repo` + `read:packages` scopes) |
