# Update Image Action

Updates any kind of container service with a new image. For Kubernetes services
(`type: service`), this action also supports updating sidecar (additional) and
init container images in the same call.

## Inputs

The following input variables can be configured:

| Name                    | Description                                                                                                  | Required | Default Value |
|-------------------------|--------------------------------------------------------------------------------------------------------------|----------|---------------|
| name                    | Service name                                                                                                 | Yes      |               |
| image                   | Image name for the main container. Optional when only updating sidecar or init container images.             | No       |               |
| type                    | Options: `service`, `lambda`, `ecs`, `cronjob`                                                               | No       | `service`     |
| container_images        | JSON array of sidecar container name/image pairs. Format: `[{"name": "sidecar1", "image": "image1:tag"}]`. Only supported when `type=service`. | No       |               |
| init_container_images   | JSON array of init container name/image pairs. Format: `[{"name": "init1", "image": "image1:tag"}]`. Only supported when `type=service`.       | No       |               |
| wait                    | Wait for deployment                                                                                          | No       | `false`       |

At least one of `image`, `container_images`, or `init_container_images` must be
provided.

## Example Usage

### Update the main container

```yaml
name: Deploy Service

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - name: Duplo Setup
      uses: duplocloud/actions@main

    - name: Update Image
      uses: duplocloud/actions/update-image@v1
      with:
        type: service
        name: my-service
        image: my-image:latest
```

### Update main, sidecar, and init container images together

```yaml
    - name: Update Image
      uses: duplocloud/actions/update-image@v1
      with:
        type: service
        name: my-service
        image: myregistry/main:v1.2.3
        container_images: |
          [
            {"name": "logger", "image": "myregistry/logger:v1.2.3"},
            {"name": "proxy",  "image": "myregistry/proxy:v1.2.3"}
          ]
        init_container_images: |
          [
            {"name": "init-db", "image": "myregistry/init-db:v1.2.3"}
          ]
        wait: "true"
```

### Update only sidecar containers (leave main image unchanged)

```yaml
    - name: Update Sidecars
      uses: duplocloud/actions/update-image@v1
      with:
        type: service
        name: my-service
        container_images: |
          [{"name": "logger", "image": "myregistry/logger:v1.3.0"}]
```
