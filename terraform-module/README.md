# Validate Module Action

This GitHub Action allows you to test a single Terraform module. It provides options for linting, validating, formatting, planning, and testing the module. The action uses Terraform commands and TFLint to perform these tasks.

## Inputs

The following table describes the inputs for this action:

| Name | Description | Required | Default Value |
| ---- | ----------- | -------- | ------------- |
| module | Working directory | Yes | N/A |
| lint | Lint the module | No | "true" |
| validate | Validate the module | No | "true" |
| fmt | Format the module | No | "true" |
| test | Test the module | No | "true" |
| test_dir | Test directory, defaults to 'tests' | No | tests |
| review | Do review checks on module. If false only init runs. | No | true |
| prefix | tfstate s3 bucket prefix | No | duplo-tfstate |

## Example Usage

```yaml
- name: Validate My Terraform Module
  uses: duplocloud/actions/setup-terraform@main
  with:
    module: ./path/to/module
    lint: true
    validate: true
    fmt: true
    test: true
    test_dir: tests
    review: false
    prefix: duplo-tfstate
```

In the above example, the action is being used to validate a Terraform module located in the `./path/to/module` directory. All of the available options (lint, validate, fmt, plan, and test) are set to their default values of "true", which means all tasks will be performed.

## Azure Notes  

When using Azure, you will need to set this environment variable in your workflow file: `RESOURCE_GROUP`. This will allow the azure cli to retrieve the `ARM_ACCESS_KEY` value and set the variable in the environment. This is needed by Azure TF provider to authenticate to Azure to use the storage bucket backend. The variable may be set at any level as long as it is available to the action. 
