# nix-github-workflows

Reusable GitHub Actions workflows and composite actions for the nix-fit-org organization.

## Structure

```
.github/
  actions/
    docker-build/          # Composite action: versioning + build + push
    helm-from-template/    # Composite action: clone helm template + patch + push OCI
    flux-reconcile-app/    # Composite action: trigger Flux image reconcile + helmrelease deploy
  workflows/
    build-docker-image.yml # docker-* repositories
    build-nodejs-app.yml   # front-app-* repositories (Node.js)
    build-dotnet-app.yml   # back-app-* repositories (.NET)
    lint-dockerfile.yml    # docker template repositories (lint only)
    helm-validate.yml      # helm-* repositories (validate)
    helm-publish.yml       # helm-* repositories (publish)
    ci.yml                 # this repo: actionlint + dockerfile lint
resources/
  GitVersion.yml           # Shared GitVersion config (conventional commits)
  nodejs.Dockerfile        # Node.js multi-stage Dockerfile
  nodejs.dockerignore      # .dockerignore for Node.js apps
  dotnet.Dockerfile        # .NET multi-stage Dockerfile
  dotnet.dockerignore      # .dockerignore for .NET apps
```

## Docs

- [build-docker-image](docs/build-docker-image.md)
- [build-nodejs-app](docs/build-nodejs-app.md)
- [build-dotnet-app](docs/build-dotnet-app.md)
- [lint-dockerfile](docs/lint-dockerfile.md)
- [helm-validate + helm-publish](docs/helm.md)

## Organization secrets

Configure once in GitHub → `nix-fit-org` → Settings → Secrets and variables → Actions.

| Secret | Used by | Description |
|--------|---------|-------------|
| `REGISTRY_USERNAME` | all | OCI registry login |
| `REGISTRY_PASSWORD` | all | OCI registry password |
| `GH_PAT` | helm workflows, nodejs/dotnet app workflows | GitHub PAT (`repo` + `read:packages` scopes) |
| `FLUX_KUBECONFIG_DEV` | nodejs/dotnet app workflows | Kubeconfig for the dev cluster (Flux reconciliation) |

> **GitHub Free plan:** org-level secrets доступны только публичным репозиториям. Для приватных реп необходимо продублировать нужные секреты в настройках каждой репы: Settings → Secrets and variables → Actions.
