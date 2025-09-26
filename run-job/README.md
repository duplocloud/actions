# Run DuploCloud Job Action

This action runs a Kubernetes job using the DuploCloud CLI (`duploctl`) and optionally waits for its completion. It simplifies the process of executing jobs within your DuploCloud environment as part of your CI/CD pipeline. 

A major benefit of this action is that it enables you to execute jobs on your own private infrastructure even while your GitHub Actions workflow runs in the public cloud. This provides secure access to private resources, databases, and services within your VPC without exposing them publicly. It's ideal for sensitive operations like database migrations, batch processing jobs, or any task that needs to run in your secured environment while still integrating with your GitHub CI/CD pipeline.

When using the `wait` flag with `loglevel: INFO`, job logs are automatically streamed directly into your GitHub Actions workflow output, making it incredibly easy to monitor job progress and troubleshoot issues in real-time without leaving your CI/CD pipeline.

## Inputs

| Name      | Description                                         | Required | Default   |
|-----------|-----------------------------------------------------|----------|-----------|
| file      | The file with the job definition to run             | No       | job.yaml  |
| wait      | Wait for the job to complete before continuing      | No       | true      |
| loglevel  | Log level for duploctl (INFO, WARN, ERROR, DEBUG)   | No       | INFO      |

## Usage

### Basic Example

```yaml
name: Run Job Workflow
on:
  push:
    branches:
      - main

jobs:
  run-duplo-job:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout Repository
      uses: actions/checkout@v4
      
    - name: DuploCloud Setup
      uses: duplocloud/actions@main
      
    - name: Run Job
      uses: duplocloud/actions/run-job@main
      with:
        file: jobs/my-job.yaml
        wait: true
        loglevel: INFO
```

### Custom Job Definition Example

```yaml
name: Run Custom Job
on:
  workflow_dispatch:

jobs:
  run-duplo-job:
    runs-on: ubuntu-latest
    steps:
    - name: Create Job Definition
      shell: bash
      run: |
        cat <<EOF > job.yaml
        metadata:
          name: data-processor
        spec:
          ttlSecondsAfterFinished: 86400
          parallelism: 1
          completions: 1
          template:
            spec:
              restartPolicy: Never
              containers:
              - name: processor
                image: ubuntu:latest
                command:
                - /bin/sh
                - -c
                args:
                - |
                  echo 'Processing data'
                  sleep 10
                  echo 'Done!'
              initContainers: []
        EOF

    - name: DuploCloud Setup
      uses: duplocloud/actions@main
      
    - name: Run Job Without Waiting
      uses: duplocloud/actions/run-job@main
      with:
        file: job.yaml
        wait: false
```

## Notes

- This action requires that the DuploCloud CLI (`duploctl`) is already set up and authenticated. Use the `duplocloud/actions/setup` action before this one.
- When `wait` is set to `true`, the workflow will pause until the job completes or fails, which can be useful for sequential operations.
- Job definition files should follow the Kubernetes job specification format.

## References

- [DuploCloud CLI Job Commands](https://cli.duplocloud.com/Job/) - Documentation for DuploCloud CLI job-related commands
- [DuploCloud Kubernetes Jobs](https://docs.duplocloud.com/docs/kubernetes-overview/jobs) - Guide to working with Jobs in DuploCloud
- [Kubernetes Jobs Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/job/) - Official Kubernetes documentation on Jobs