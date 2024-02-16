 # Duplo AWS Setup Action

An Action to set up duplocloud cli and the underlying cloud. During this process, duplo discovers the underlying cloud which is either aws, gcp, or azure. Once the cloud is known, the corresponding cli is installed. Finally the action will authenticate with the cloud provider.
It provides the following features:

- Setting up Python.
- Installing `duploctl`.
- when AWS
  - Installing AWS CLI.
  - Running Duplo JIT (Just-In-Time) for AWS.
  - Configuring AWS IAM Credentials.
- when GCP
  - Installing GCP CLI.
  - Configuring GCP SA Credentials.
- when Azure
  - Installing Azure CLI.
  - Configuring Azure SCP Credentials.

## Inputs

The following input variables can be configured:

| Name              | Description                                                                 | Required | Default Value |
|-------------------|-----------------------------------------------------------------------------|----------|---------------|
| `mask-account-id` | Mask AWS Account ID in logs                                                 | `false`  | `yes`         |
| `region`          | Overide the cloud region from the default. For gcp this is required.        | `false`  |               |
| `account-id`      | Overide the cloud account id from the default. Required when on gcp/azure where this would be the project name or directory name. | `false`  |               |
| `credentials`     | Cloud credentials for Azure or GCP.                                         | `false`  |               |



## Usage

**AWS Example:**  
```yaml
name: Simple AWS Setup
on: 
- push
jobs:
  build:
    runs-on: ubuntu-latest
    env:
      DUPLO_TOKEN: ${{ secrets.DUPLO_TOKEN }}
      DUPLO_HOST: ${{ vars.DUPLO_HOST  }}
      DUPLO_TENANT: ${{ vars.DUPLO_TENANT }}
    steps:
    - name: Duplo Setup
      uses: duplocloud/actions/setup@main
```

**GCP or Azure Example:**  
The only difference is there is no JIT for GCP or Azure. This means the job needs to have some pre-configured credentials to use for authentication. The name of the account is required for GCP and Azure as well. 
```yaml
steps:
- name: Duplo Setup
  uses: duplocloud/actions/setup@main
  with:
    account-id: ${{ vars.CLOUD_ACCOUNT }}
    credentials: ${{ secrets.CLOUD_CREDENTIALS }}
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
