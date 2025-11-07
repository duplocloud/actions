# Update Images Action

Bulk update images for multiple services using duploctl.

## Prerequisites

- DuploCloud account with appropriate permissions
- duploctl version 0.3.5+ installed (handled by Duplo Setup action)
- Required environment variables (set by Duplo Setup action):
  - `DUPLO_HOST` - DuploCloud host URL
  - `DUPLO_TOKEN` - DuploCloud authentication token
  - `DUPLO_TENANT` - DuploCloud tenant name

**Important**: This action requires the `duplocloud/actions@main` setup action to be run first to install duploctl and configure environment variables.

## Inputs

The following input variables can be configured:

| Name      | Description                                                                                    | Required | Default Value |
|-----------|------------------------------------------------------------------------------------------------|----------|---------------|
| services  | JSON array of service-image pairs. Format: `[{"service": "service1", "image": "image1:tag"}]` | Yes      |               |
| wait      | Wait for all deployments to complete                                                          | No       | `false`       |
| loglevel  | Log level for duploctl output                                                                 | No       | `INFO`        |

## Outputs

| Name             | Description                          |
|------------------|--------------------------------------|
| `result`         | The result of the bulk update operation (`success` or `failed`) |
| `services_updated` | Number of services that were updated |

## Service Input Format

The `services` input expects a JSON array where each object contains:
- `service`: The name of the service to update
- `image`: The new image URI (including tag)

### Example Services Input

```json
[
  {
    "service": "frontend",
    "image": "myregistry/frontend:v1.2.3"
  },
  {
    "service": "backend",
    "image": "myregistry/backend:latest"
  },
  {
    "service": "worker",
    "image": "myregistry/worker:sha-abc123"
  }
]
```

## Example Usage

### Basic Usage

```yaml
name: Deploy Multiple Services

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

    - name: Update Multiple Images
      uses: duplocloud/actions/update-images@v1
      with:
        services: |
          [
            {
              "service": "frontend",
              "image": "myregistry/frontend:v1.2.3"
            },
            {
              "service": "backend",
              "image": "myregistry/backend:latest"
            }
          ]
```

### Using Variables

```yaml
    - name: Update Multiple Images
      uses: duplocloud/actions/update-images@v1
      with:
        services: ${{ vars.SERVICES_TO_UPDATE }}
```

Where `SERVICES_TO_UPDATE` is a repository variable containing:
```json
[
  {
    "service": "frontend",
    "image": "myregistry/frontend:${{ github.sha }}"
  },
  {
    "service": "backend",
    "image": "myregistry/backend:${{ github.sha }}"
  }
]
```
