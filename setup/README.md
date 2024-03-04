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
| `version`        | Duplo version to install.                                                    | `false`  | `latest`      |



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

## Authentication  

Each underlying cloud has their own unique way of authenticating. 

### AWS  

Using the JIT functionality built into the portal, the action uses retreives an sts session from the duplo portal and uses these credentials to authenticate with the AWS CLI. Magical. 

### Azure  

The action uses the `azure/login` action to authenticate with Azure. To keep things consistent this action will use the `CLOUD_CREDENTIALS` secret to authenticate which expects the following format:  
```json
{
  "clientId": "<client-id>",
  "clientSecret": "<client-secret>",
  "subscriptionId": "<subscription-id>",
  "tenantId": "<tenant-id>"
}
```

### GCP

The action uses the `google-github-actions/setup-gcloud` action to authenticate with GCP. To keep things consistent this action will use the `CLOUD_CREDENTIALS` secret to authenticate which expects the following format:  
```json
{
  "type": "service_account",
  "project_id": "<project-id>",
  "private_key_id": "<private-key-id>",
  "private_key": "<private-key>",
  "client_email": "<client-email>",
  "client_id": "<client-id>",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://accounts.google.com/o/oauth2/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "<client-x509-cert-url>"
}
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
