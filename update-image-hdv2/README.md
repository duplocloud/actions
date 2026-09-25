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
| type         | Workload type. Options: `service` (alias `eks`), `lambda`, `cronjob`        | No       | `service`     |
| workspace    | AI HelpDesk workspace name the workload belongs to. Falls back to `DUPLO_WORKSPACE`. | No       | `""`          |
| workspace_id | AI HelpDesk workspace id. Skips the workspace name lookup when provided. Falls back to `DUPLO_WORKSPACE_ID`. | No       | `""`          |

One of `workspace` or `workspace_id` is required (via input or environment).

### Update a CronJob image

```yaml
    - name: Update CronJob Image
      uses: duplocloud/actions/update-image-hdv2@v1
      with:
        type: cronjob
        name: nightly-report
        image: my-image:latest
        workspace: my-workspace
```

`type: cronjob` updates the first container of the cronjob's job template
via `duploctl hd_cronjob update_image` (requires duplocloud/duploctl#290).

## Deployment modes

Only `DUPLO_HOST` and `DUPLO_TOKEN` are needed — HDV2 workloads are
workspace-scoped, so `DUPLO_TENANT` is not used. The action works against
both an integrated portal and a standalone AI HelpDesk (`DUPLO_HOST` set to
the helpdesk URL, `DUPLO_TOKEN` a `dahp_` API token).

> **Note:** the `appservice` and `hd_lambda` duploctl commands are newer than
> the 0.4.5 release. Until the next duploctl release, install from source in
> the setup action: `with: { version: main, from-source: true }`.

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
