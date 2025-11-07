# Update Image Action

Updates any kind of container service with a new image.

## Inputs

The following input variables can be configured:

| Name  | Description                              | Required | Default Value |
|-------|------------------------------------------|----------|---------------|
| name  | Service name                             | Yes      |               |
| image | Image name                               | Yes      |               |
| type  | Options: `service`, `lambda`, `ecs`, `cronjob` | No       | `service`      |
| wait  | Wait for deployment                      | No       | `false`        |

## Example Usage

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

    # Add more steps for your deployment process...
```
