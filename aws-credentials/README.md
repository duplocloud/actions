# AI HelpDesk AWS Credentials Action

Mints just-in-time AWS credentials from an AI HelpDesk workspace via
`duploctl aws_credentials` — the HelpDesk counterpart to the portal AWS
JIT the setup action performs. By default the credentials are exported as
`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` /
`AWS_REGION` (masked in logs) for the rest of the job, so the AWS CLI and
SDKs pick them up directly.

Two target kinds:

- **Cloud scope** (`scope`/`scope_id`) — an AWS scope of the workspace.
  When the workspace has exactly one AWS scope, no selector is needed;
  otherwise the error lists the available scope names.
- **Resource group** (`resource_group`/`resource_group_id`) — the IAM
  role attached to the resource group.

Works against both deployment modes — an integrated portal or a standalone
AI HelpDesk (`DUPLO_HOST` set to the helpdesk URL, `DUPLO_TOKEN` a `dahp_`
API token). Only `DUPLO_HOST` and `DUPLO_TOKEN` are needed; `DUPLO_TENANT`
is not used.

> **Note:** the `aws_credentials` duploctl command is newer than the 0.4.5
> release (duplocloud/duploctl#291). Until the next duploctl release,
> install from source in the setup action:
> `with: { version: main, from-source: true }`.

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `scope` | Cloud scope name to mint credentials for. Optional when the workspace has exactly one AWS scope and no resource group is given. | No | `""` |
| `scope_id` | Cloud scope id. Skips the scope name lookup. | No | `""` |
| `resource_group` | Mint for the IAM role attached to this resource group (by name) instead of a scope. | No | `""` |
| `resource_group_id` | Resource group id. Skips the name lookup. | No | `""` |
| `workspace` | AI HelpDesk workspace name. Falls back to `DUPLO_WORKSPACE`. | No | `""` |
| `workspace_id` | AI HelpDesk workspace id. Skips the workspace name lookup when provided. Falls back to `DUPLO_WORKSPACE_ID`. | No | `""` |
| `export_env` | Export the `AWS_*` variables for the rest of the job. Set to false to only expose the non-secret outputs. | No | `true` |

One of `workspace` or `workspace_id` is required (via input or environment).

## Outputs

| Name | Description |
|------|-------------|
| `region` | AWS region the credentials were minted for. |
| `console_url` | Federated AWS Console sign-in URL (masked in logs — it embeds a sign-in token). |
| `expiration` | UTC expiration timestamp of the temporary credentials. |

The credentials themselves are exported as environment variables, not
outputs, and are masked in logs. They expire (typically within an hour) —
mint them close to where they are used.

## Example Usage

```yaml
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

    - name: AWS Credentials
      uses: duplocloud/actions/aws-credentials@main
      with:
        scope: my-aws-scope

    - name: Push to ECR
      run: aws sts get-caller-identity   # AWS_* env is already exported
```
