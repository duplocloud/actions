# Run Job (HelpDesk V2) Action

Runs a Kubernetes job in an AI HelpDesk workspace via `duploctl hd_job` —
the HelpDesk counterpart to [`run-job`](../run-job). With `wait: true`
(the default) the action waits for the job to actually run to completion:
duploctl gates on the Job's `Complete` condition and fails terminally on a
`Failed` condition (backoff limit exhausted, deadline exceeded) with its
message.

Works against both deployment modes — an integrated portal or a standalone
AI HelpDesk (`DUPLO_HOST` set to the helpdesk URL, `DUPLO_TOKEN` a `dahp_`
API token). Only `DUPLO_HOST` and `DUPLO_TOKEN` are needed; `DUPLO_TENANT`
is not used.

> **Note:** requires a duploctl with the `hd_job` completion waiter
> (duplocloud/duploctl#289, newer than the 0.4.5 release). Until the next
> duploctl release, install from source in the setup action:
> `with: { version: main, from-source: true }`.

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `file` | The file with the job definition to run. | No | `job.yaml` |
| `wait` | Wait for the job to run to completion. | No | `true` |
| `replace` | Delete an existing job with the same name before creating this one. HelpDesk jobs are immutable, so a re-run with an unchanged name fails without this. | No | `false` |
| `name` | The job name, only needed with `replace: true`. Defaults to the top-level `name` key of the job definition file. | No | `""` |
| `workspace` | AI HelpDesk workspace name to run the job in. Falls back to `DUPLO_WORKSPACE`. | No | `""` |
| `workspace_id` | AI HelpDesk workspace id. Skips the workspace name lookup when provided. Falls back to `DUPLO_WORKSPACE_ID`. | No | `""` |
| `loglevel` | Log level for duploctl (INFO, WARN, ERROR, DEBUG). | No | `INFO` |

One of `workspace` or `workspace_id` is required (via input or environment).

## Job definition

The file is a HelpDesk job body: a `name` plus a `spec` carrying the
workspace placement ids and the raw Kubernetes Job manifest under
`spec.k8sResource`. The backend stamps a `resourcegroup` node selector on
the pod; set `spec.isAnyHostAllowed: true` to schedule on any node when the
cluster has no node group for the resource group.

```yaml
name: ci-migrate
spec:
  environmentId: <environment id>
  resourceGroupId: <resource group id>
  namespaceName: my-namespace
  k8sResource:
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: ci-migrate
    spec:
      backoffLimit: 0
      ttlSecondsAfterFinished: 3600
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: main
            image: my-image:latest
            command: ["sh", "-c", "./migrate.sh"]
```

## Example Usage

```yaml
jobs:
  migrate:
    runs-on: ubuntu-latest
    env:
      DUPLO_HOST: ${{ vars.DUPLO_HOST }}        # portal or standalone helpdesk URL
      DUPLO_TOKEN: ${{ secrets.DUPLO_TOKEN }}   # portal token or dahp_ API token
      DUPLO_WORKSPACE: ${{ vars.DUPLO_WORKSPACE }}

    steps:
    - uses: actions/checkout@v6

    - name: Duplo Setup
      uses: duplocloud/actions@main
      with:
        version: main
        from-source: true

    - name: Run Migration Job
      uses: duplocloud/actions/run-job-hdv2@main
      with:
        file: ./jobs/migrate.yaml
        replace: true
```
