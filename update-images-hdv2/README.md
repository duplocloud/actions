# Update Images (HelpDesk V2) Action

Bulk-updates container images for multiple HelpDesk V2 workloads in an AI
HelpDesk workspace — the HDV2 counterpart to [`update-images`](../update-images).
Entries are validated up front, then updated sequentially with fail-fast:
the backend has no bulk endpoint, so per-entry calls are not atomic and
progress is reported in the log.

Workload types map to duploctl commands: `service` (alias `eks`) →
`appservice update_image`, `lambda` → `hd_lambda update_image`, `cronjob` →
`hd_cronjob update_image`. ECS is not yet supported (no HDV2 backend
endpoint; tracked in DUPLO-43548).

Works against both deployment modes — an integrated portal or a standalone
AI HelpDesk (`DUPLO_HOST` set to the helpdesk URL, `DUPLO_TOKEN` a `dahp_`
API token). Only `DUPLO_HOST` and `DUPLO_TOKEN` are needed; `DUPLO_TENANT`
is not used.

> **Note:** the `appservice`/`hd_lambda`/`hd_cronjob` duploctl commands are
> newer than the 0.4.5 release. Until the next duploctl release, install
> from source in the setup action: `with: { version: main, from-source: true }`.

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `workloads` | JSON array of `{name, image, type?}` entries. `type` defaults to the action's `type` input. | Yes | - |
| `type` | Default workload type for entries without their own: `service` (alias `eks`), `lambda`, or `cronjob`. | No | `service` |
| `workspace` | AI HelpDesk workspace name the workloads belong to. Falls back to `DUPLO_WORKSPACE`. | No | `""` |
| `workspace_id` | AI HelpDesk workspace id. Skips the workspace name lookup when provided. Falls back to `DUPLO_WORKSPACE_ID`. | No | `""` |
| `loglevel` | Log level for duploctl (INFO, WARN, ERROR, DEBUG). | No | `INFO` |

One of `workspace` or `workspace_id` is required (via input or environment).

## Example Usage

```yaml
    - name: Duplo Setup
      uses: duplocloud/actions@main
      with:
        version: main
        from-source: true

    - name: Update Images
      uses: duplocloud/actions/update-images-hdv2@main
      with:
        workspace: my-workspace
        workloads: |
          [
            {"name": "web",     "image": "myrepo/web:${{ github.sha }}"},
            {"name": "worker",  "image": "myrepo/worker:${{ github.sha }}"},
            {"name": "reports", "image": "myrepo/reports:${{ github.sha }}", "type": "cronjob"}
          ]
```
