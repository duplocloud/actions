# Update Lambda Github Action

This GitHub Action updates a lambda function using Duploctl. It allows you to specify the lambda name, and an image name or S3 path as inputs.

## Inputs

The following input variables can be configured:

| Name      | Description                | Required | Default Value |
|-----------|----------------------------|----------|---------------|
| lambda    | Lambda name                | Yes      |               |
| uri       | update location uri        | Yes      |               |


## Example Usage

```yaml
name: Update Lambda

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - name: Duplo Setup
      uses: duplocloud/actions/setup@main

    - name: Update lambda
      uses: duplocloud/actions/update-lambda@v1
      with:
        lambda: my-lambda
        uri: my-image:latest

    # Add more steps for your deployment process...
```
```yaml
name: Update Lambda

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - name: Duplo Setup
      uses: duplocloud/actions/setup@main

    - name: Update Lambda
      uses: duplocloud/actions/update-lambda@v1
      with:
        lambda: my-lambda
        uri: s3://mybucket/mypath/mysource.zip

    # Add more steps for your deployment process...
```
