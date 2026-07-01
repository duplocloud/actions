# Update Image (HelpDesk V2) Action

Updates a container image for an AI HelpDesk V2 (HDV2) workload within a
workspace. Supports EKS AppServices (`type: service`) and AWS Lambdas
(`type: lambda`).

> **Note:** ECS is not yet supported — the HelpDesk V2 backend has no ECS
> update-image endpoint (tracked in DUPLO-43548). For Core Platform (non-HDV2)
> services, ECS, and cronjobs, use the [`update-image`](../update-image) action.

## Inputs

The following input variables can be configured:

| Name         | Description                                                                 | Required | Default Value |
|--------------|-----------------------------------------------------------------------------|----------|---------------|
| name         | Workload name as shown in the HelpDesk workspace                            | Yes      |               |
| image        | New container image URI (e.g. an ECR image reference)                       | Yes      |               |
| type         | Workload type. Options: `service` (alias `eks`), `lambda`                   | No       | `service`     |
| workspace    | AI HelpDesk workspace name the workload belongs to                          | No       | `""`          |
| workspace_id | AI HelpDesk workspace id. Skips the workspace name lookup when provided.    | No       | `""`          |

One of `workspace` or `workspace_id` is required.

## Example Usage

### Update an EKS AppService image

```yaml
name: Deploy Service (HDV2)

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
      uses: duplocloud/actions/update-image-hdv2@v1
      with:
        type: service
        name: my-appservice
        image: my-image:latest
        workspace: my-workspace
```

### Update an AWS Lambda image

```yaml
    - name: Update Lambda Image
      uses: duplocloud/actions/update-image-hdv2@v1
      with:
        type: lambda
        name: my-function
        image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-fn:v1.2.3
        workspace: my-workspace
```
