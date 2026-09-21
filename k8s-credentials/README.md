# AI HelpDesk K8s Credentials Action

Fetches just-in-time Kubernetes credentials for a cluster in an AI HelpDesk
workspace and writes a kubeconfig, ready for `kubectl`, `helm`, or any other
Kubernetes tooling in later steps. One endpoint serves every cloud the
platform provisions: EKS, AKS, and registered K8S_ONLY clusters.

By default the kubeconfig path is exported as `KUBECONFIG` for the rest of
the job. The bearer token is minted per call and expires within minutes, so
fetch credentials right before using them and re-run the action to refresh.

Works against both deployment modes — an integrated portal or a standalone
AI HelpDesk (`DUPLO_HOST` set to the helpdesk URL, `DUPLO_TOKEN` a `dahp_`
API token). Only `DUPLO_HOST` and `DUPLO_TOKEN` are needed; `DUPLO_TENANT`
is not used.

> **Note:** the `k8s_credentials` duploctl command is newer than the 0.4.5
> release. Until the next duploctl release, install from source in the setup
> action: `with: { version: main, from-source: true }`.

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `cluster` | Cluster name as shown in the HelpDesk workspace. Optional when the workspace has exactly one cluster. | No | `""` |
| `cluster_id` | Cluster id. Skips the cluster name lookup when provided. | No | `""` |
| `workspace` | AI HelpDesk workspace name the cluster belongs to. Falls back to `DUPLO_WORKSPACE`. | No | `""` |
| `workspace_id` | AI HelpDesk workspace id. Skips the workspace name lookup when provided. Falls back to `DUPLO_WORKSPACE_ID`. | No | `""` |
| `kubeconfig_path` | Where to write the kubeconfig. | No | a file under `RUNNER_TEMP` |
| `context_name` | Kubeconfig context name. | No | the cluster name |
| `export_kubeconfig` | Export `KUBECONFIG` pointing at the written file for the rest of the job. | No | `true` |

One of `workspace` or `workspace_id` is required (via input or environment).

## Outputs

| Name | Description |
|------|-------------|
| `kubeconfig` | Path of the written kubeconfig file. |
| `endpoint` | Kubernetes API server URL. |
| `namespace` | Default namespace of the credentials. |
| `context` | Name of the kubeconfig context. |

## Example Usage

```yaml
name: Deploy to HelpDesk Cluster

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      DUPLO_HOST: ${{ vars.DUPLO_HOST }}        # portal or standalone helpdesk URL
      DUPLO_TOKEN: ${{ secrets.DUPLO_TOKEN }}   # portal token or dahp_ API token
      DUPLO_WORKSPACE: ${{ vars.DUPLO_WORKSPACE }}

    steps:
    - name: Duplo Setup
      uses: duplocloud/actions@main
      with:
        version: main
        from-source: true

    - name: K8s Credentials
      uses: duplocloud/actions/k8s-credentials@main
      with:
        cluster: my-eks-cluster

    - name: Deploy
      run: kubectl get pods   # KUBECONFIG is already exported
```
