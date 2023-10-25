# Validate Module Action

This GitHub Action allows you to test a single Terraform module. It provides options for linting, validating, formatting, planning, and testing the module. The action uses Terraform commands and TFLint to perform these tasks.

## Inputs

The following table describes the inputs for this action:

| Name | Description | Required | Default Value |
| ---- | ----------- | -------- | ------------- |
| wkdir | Working directory | Yes | N/A |
| lint | Lint the module | No | "true" |
| validate | Validate the module | No | "true" |
| fmt | Format the module | No | "true" |
| plan | Plan the module | No | "true" |
| test | Test the module | No | "true" |

## Example Usage

```yaml
- name: Validate My Terraform Module
  uses: duplocloud/actions/setup-terraform@main
  with:
    wkdir: ./path/to/module
    lint: true
    validate: true
    fmt: true
    plan: true
    test: true
```

In the above example, the action is being used to validate a Terraform module located in the `./path/to/module` directory. All of the available options (lint, validate, fmt, plan, and test) are set to their default values of "true", which means all tasks will be performed.

