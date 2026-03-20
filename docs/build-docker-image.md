# build-docker-image

Builds and pushes a Docker image to the OCI registry. For `docker-*` repositories.

Image name is derived from the repository name automatically (`docker-nodejs-build` → `nodejs-build`).
Version is read from the `version` file in the repository root.

## Versioning

Tags are built from the version file by appending a zero-padded sequential counter:

```
version file: 1.2.3
              └─ 1.2.3000 (first push)
                 1.2.3001
                 1.2.3002 ...

version file: 1.2.3-beta
              └─ 1.2.3000-beta (first push)
                 1.2.3001-beta
                 1.2.3002-beta ...
```

| Branch | Tag example | Cache |
|--------|-------------|-------|
| Feature branch | `1.2.3000-snapshot` | registry cache used |
| `main` or numeric (`9`, `22`) | `1.2.3001` | no cache |

On release branches the registry is queried for the latest matching tag and the counter is incremented by 1. On the first push the base version (`1.2.3000`) is used.

Supports both `X.Y.Z` and `X.Y` version formats.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `image_sub_path` | yes | — | Path within registry (e.g. `ci/build`, `base/redhat`) |
| `platforms` | no | `linux/amd64,linux/arm64` | Target platforms |
| `version_file` | no | `version` | Path to file containing the image version |
| `test_release` | no | `false` | Force release versioning on non-release branch |

## Secrets

`REGISTRY_USERNAME`, `REGISTRY_PASSWORD`

## Usage

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: ['**']

jobs:
  build:
    uses: nix-fit-org/nix-github-workflows/.github/workflows/build-docker-image.yml@main
    with:
      image_sub_path: ci/build
    secrets: inherit
```
