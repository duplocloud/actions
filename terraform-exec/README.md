# Execute Terraform GitHub Action

This action facilitates the execution of various Terraform commands within a GitHub Actions workflow. It is designed to work with modules, workspaces, and custom configs, allowing for a flexible setup for Terraform operations like apply, destroy, and plan.

## Inputs

The following table outlines the inputs that you can provide to this action:

| Input         | Description                                                          | Required | Default    |
|---------------|----------------------------------------------------------------------|----------|------------|
| `module`      | Working directory where Terraform commands will be run.              | yes      | -          |
| `workspace`   | The Terraform workspace to use.                                      | no       | `default`  |
| `command`     | The Terraform command to execute (`apply`, `destroy`, or `plan`).    | yes      | `plan`     |
| `parallelism` | The number of parallel operations as Terraform performs its actions. | no       | -          |
| `config`      | Relative path to the Terraform configurations.                       | no       | `./config` |

## Examples

### Basic Usage

To run a Terraform plan:

```yaml
jobs:
  terraform_plan:
    runs-on: ubuntu-latest
    name: Run Terraform Plan
    steps:
      - uses: actions/checkout@v4

      - uses: duplocloud/actions@main
        with:
          admin: true

      - uses: duplocloud/actions/terraform-module@feature/terraform_actions_updates

      - name: Terraform Plan
        uses: duplocloud/actions/terraform-exec@v1
        with:
          module: terraform/module/path
          command: plan
```

### Workspace and Parallelism

Running a Terraform apply with a specific workspace and setting parallelism:

```yaml
jobs:
  terraform_apply:
    runs-on: ubuntu-latest
    name: Apply Terraform Configuration
    steps:
      - uses: actions/checkout@v3
      - name: Terraform Apply
        uses: duplocloud/actions/terraform-exec@v1
        with:
          module: terraform/module/path
          workspace: production
          command: apply
          parallelism: 5
```

### Destroy Operation

To destroy resources managed by Terraform:

```yaml
jobs:
  terraform_destroy:
    runs-on: ubuntu-latest
    name: Destroy Terraform Resources
    steps:
      - uses: actions/checkout@v3
      - name: Terraform Destroy
        uses: duplocloud/actions/terraform-exec@v1
        with:
          module: terraform/module/path
          command: destroy
```

Utilize this GitHub Action in your CI/CD pipeline to streamline your Terraform workflows across different environments and configurations. Make sure your runner has the correct permissions and access to the necessary cloud provider credentials.
