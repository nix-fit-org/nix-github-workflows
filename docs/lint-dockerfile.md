# lint-dockerfile

Lints a Dockerfile with [hadolint](https://github.com/hadolint/hadolint). For template repositories where the Dockerfile cannot be built standalone.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `dockerfile` | no | `Dockerfile` | Path to Dockerfile |

## Usage

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: ['**']

jobs:
  lint:
    uses: nix-fit-org/nix-github-workflows/.github/workflows/lint-dockerfile.yml@main
```
