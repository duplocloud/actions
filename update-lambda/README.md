# Update Lambda Github Action

This GitHub Action updates a lambda function using Duploctl. It allows you to specify the lambda name, and an image name or S3 path as inputs.

## Inputs

The following input variables can be configured:

| Name      | Description                | Required | Default Value |
|-----------|----------------------------|----------|---------------|
| lambda    | Lambda name                | Yes      |               |
| image     | Image name                 | No       |               |
| s3_path   | Path to source archive     | No       |               |

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

    - name: Update Service
      uses: duplocloud/actions/update-service@v1
      with:
        lambda: my-lambda
        image: my-image:latest

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

    - name: Update Service
      uses: duplocloud/actions/update-service@v1
      with:
        lambda: my-lambda
        s3_path: mybucket/myarchivepath/mysource.zip

    # Add more steps for your deployment process...
```
