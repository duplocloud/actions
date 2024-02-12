Apologies for the misunderstanding. If the GitHub Action does not have any inputs, the table for inputs in the README can be omitted. Here's an updated version of the README without the inputs table:

# Duplo AWS Setup Action

This GitHub Action sets up Duplo and AWS tools and performs a login. It provides the following features:

- Setting up Python.
- Installing `duploctl`.
- Installing AWS CLI.
- Running Duplo JIT (Just-In-Time) for AWS.
- Configuring AWS IAM Credentials.

## Usage

```yaml
name: My Workflow

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout Repository
      uses: actions/checkout@v2

    - name: Duplo Setup
      uses: duplocloud/actions/setup@main

    # Add more steps to your workflow...
```

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE).

## References 

 - Third Party Actions: 
   - [aws-actions/configure-aws-credentials@v3](https://github.com/aws-actions/configure-aws-credentials)
   - [unfor19/install-aws-cli-action@v1](https://github.com/unfor19/install-aws-cli-action)
   - [actions/setup-python@v5](https://github.com/actions/setup-python)
   - [google-github-actions/setup-gcloud](https://github.com/google-github-actions/setup-gcloud)
   - [google-github-actions/auth](https://github.com/google-github-actions/auth)
   - [azure/login](https://github.com/marketplace/actions/azure-login)
   - [azure/CLI](https://github.com/marketplace/actions/azure-cli-action)
