# Update Lambda Github Action

This GitHub Action updates a lambda function using Duploctl. It allows you to specify the lambda name and a URI, which can either be an s3://bucket/path uri or a docker image uri.

## Inputs

The following input variables can be configured:

| Name      | Description                | Required | Default Value |
|-----------|----------------------------|----------|---------------|
| lambda    | Lambda name                | Yes      |               |
| uri       | update location uri        | Yes      |               |


## Example Usage

```yaml
name: Update Lambda Docker Image

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - name: Duplo Setup
      uses: duplocloud/actions@main

    - name: Update lambda
      uses: duplocloud/actions/update-lambda@v1
      with:
        lambda: my-lambda
        uri: my-image:latest

    # Add more steps for your deployment process...
```
```yaml
name: Update Lambda from S3 Source

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - name: Duplo Setup
      uses: duplocloud/actions@main

    - name: Update Lambda
      uses: duplocloud/actions/update-lambda@v1
      with:
        lambda: my-lambda
        uri: s3://mybucket/mypath/mysource.zip

    # Add more steps for your deployment process...
```
