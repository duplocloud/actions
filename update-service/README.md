# Update Service Github Action

This GitHub Action builds and updates a service using Duploctl. It allows you to specify the service name and image name as inputs.

## Inputs

The following input variables can be configured:

| Name      | Description     | Required | Default Value |
|-----------|-----------------|----------|---------------|
| service   | Service name    | Yes      |               |
| image     | Image name      | Yes      |               |

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

    - name: Update Service
      uses: duplocloud/actions/update-service@v1
      with:
        service: my-service
        image: my-image:latest

    # Add more steps for your deployment process...
```
