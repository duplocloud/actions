# Import Terraform GitHub Action

Pass in a list of imports IDs and this action will import them into the specified modules state. This is useful when you have existing resources that you want to manage with Terraform and you want them imnported before running the apply. 

## Inputs

The following table outlines the inputs that you can provide to this action:

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `module` | Working directory where Terraform commands will be run. | yes | - |
| `workspace` | The Terraform workspace to use. | no | `default` |
| `resources` | List of resources and their ids as a key=value list. | no | `./config` |

## Examples

### Basic Usage

To import a bucket and an ASG profile. Make sure to replace `*TENANT_ID*`, `*SHORTNAME*`, etc with the appropriate values. 

```yaml
jobs:
  terraform_plan:
    runs-on: ubuntu-latest
    name: Run Terraform Plan
    steps:
      - uses: actions/checkout@v4
      - name: Terraform Plan
        uses: duplocloud/actions/terraform-import@main
        with:
          module: terraform/module/path
          resources: |
            duplocloud_s3_bucket.mybucket=*TENANT_ID*/*SHORTNAME*
            duplocloud_asg_profile.myAsgProfile=*TENANT_ID*/*FRIENDLY_NAME*
```
