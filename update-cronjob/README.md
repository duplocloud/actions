# Update CronJob Github Action

This GitHub Action updates a CronJob using Duploctl. It allows you to specify the CronJob name and image name as inputs.

## Inputs

The following input variables can be configured:

| Name      | Description     | Required | Default Value |
|-----------|-----------------|----------|---------------|
| cronjob   | CronJob name    | Yes      |               |
| image     | Image name      | Yes      |               |

## Example Usage

```yaml
name: Update CronJob

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

    - name: Update CronJob
      uses: duplocloud/actions/update-service@v1
      with:
        cronjob: my-cronjob
        image: my-image:latest

    # Add more steps for your deployment process...
```
