# Install TF Dependencies Github Action

This GitHub Action installs the necessary dependencies for working with Terraform. It supports caching of Terraform and TFLint plugins to improve performance.

## Inputs

The following input variables can be configured:

| Name               | Description                       | Required | Default Value         |
|--------------------|-----------------------------------|----------|-----------------------|
| tf_cache_dir       | Terraform cache directory          | No       | ~/.terraform.d/plugin-cache |
| tflint_cache_dir   | TFLint cache directory             | No       | ~/.tflint.d/plugins  |
| tflint_version     | TFLint version                     | No       | v0.44.1              |
| terraform_version  | Terraform version                  | No       | 1.6.1                 |

## Example Usage

```yaml
name: CI

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout repository
      uses: actions/checkout@v2

    - name: Install TF Dependencies
      uses: example/install-tf-dependencies-action@v1
      with:
        tf_cache_dir: ~/.terraform.d/plugin-cache
        tflint_cache_dir: ~/.tflint.d/plugins
        tflint_version: v0.44.1
        terraform_version: 1.6.1

    # Add more steps for your CI process...
```

Please note that you need to replace `example/install-tf-dependencies-action@v1` with the actual reference to this action in your repository.