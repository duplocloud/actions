# Build and push Docker image GitHub Action

This GitHub Action builds a Docker image and pushes it to a registry. It also sets up the base image, tags the image with various references, and uses Buildx to build multi-arch images if enabled.

## Inputs

| Name         | Description                                                      | Required | Default Value |
| ------------ | ---------------------------------------------------------------- | -------- | ------------- |
| `repo`       | Repository name. Defaults to git repository name.                | No       |               |
| `registry`   | Registry name.                                                   | No       |               |
| `platforms`  | Build multi-arch image.                                          | No       |               |
| `build-args` | Extra arguments to pass to Docker.                                | No       |               |
| `context`    | Build context.                                                   | No       | `.`           |
| `dockerfile` | Dockerfile path.                                                 | No       | `Dockerfile`  |
| `push`       | Push image to registry.                                           | No       | `true`        |
| `cache`      | Cache image layers if buildx enabled.                             | No       | `true`        |

## Outputs

| Name     | Description      | Example                                    |
| -------- | ---------------- | ------------------------------------------ |
| `image`  | Docker image     | `docker.pkg.github.com/repo/image:123abc`  |
| `repo`   | Repository name  | `repo`                                     |
| `branch` | Branch name      | `main`                                     |

## Usage

```yaml
name: CI/CD Pipeline

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest

    steps:

    - name: Checkout code
      uses: actions/checkout@v3

    - name: Duplo Setup
      uses: duplocloud/actions/setup@main

    - name: Build and Push Docker Image
      uses: duplocloud/actions/build-image@main
      with:
        repo: my-repo
        registry: my-registry
        platforms: linux/amd64,linux/arm64
        build-args: >
          --build-arg MY_VAR=value
        context: ./app
        dockerfile: Dockerfile.dev
        push: true
        cache: true
```

## References 

 - [Docker Official GHA](https://docs.docker.com/build/cache/backends/gha/)
 - Third Party Actions:
   - [crazy-max/ghaction-github-runtime@v3](https://github.com/crazy-max/ghaction-github-runtime)
   - [docker/setup-qemu-action@v2]()
   - [docker/setup-buildx-action@v2]()