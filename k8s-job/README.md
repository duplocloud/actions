# Kubernetes Job Runner  

> ⚠️ **DEPRECATED**: This action is deprecated and will be removed in a future release. Please use [duplocloud/actions/run-job](../run-job) instead, which offers improved integration with DuploCloud through the `duploctl` CLI.

An action to run an arbitrary Kubernetes job and watch it until it completes or fails. This action reports back the final status as well as the logs from the job. It also provides an optional delay before the job is cleaned up, useful for debugging.

## Inputs

### `file`

- **Description**: The file with a Kubernetes job to run.
- **Default**: `job.yaml`

### `timeout`

- **Description**: The timeout for the job.
- **Default**: `300s`

### `cleanup_delay`

- **Description**: Wait time in seconds before cleaning up the job. Useful for debugging purposes.
- **Default**: `0` (no delay)
- **Type**: Integer

## Usage

```yaml
name: K8s Job
on:
- push
jobs:
  run-k8s-job:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout Repository
      uses: actions/checkout@v3
    - name: Build Job
      shell: bash
      run: |
        cat <<EOF > job.yaml
        apiVersion: batch/v1
        kind: Job
        metadata:
          name: my-job
          namespace: duploservices-mytenant
        spec:
          backoffLimit: 4
          parallelism: 1
          template:
            spec:
              restartPolicy: Never
              nodeSelector:
                tenantname: duploservices-mytenant
              containers:
              - name: app
                image: alpine:latest
                command:
                - /bin/sh
                - -c
                args:
                - |
                  # Jobs that exit immediately may fail the wait conditions above or be missing logs.
                  # Most jobs take at least a few seconds to complete, so this isn't an issue. If your
                  # job exits too quickly, inject some seconds of sleep. Upcoming Kubernetes features
                  # may simplify this.
                  sleep 10
                  echo "Hello World, I'm in Kubernetes!"
        EOF

    - name: Apply and Watch
      uses: duplocloud/actions/k8s-job@main
      with:
        file: job.yaml
        timeout: 300s
        cleanup_delay: 3600  # Optional delay for debugging purposes
```

## Migration to run-job

To migrate to the new `run-job` action, update your workflow as follows:

```yaml
name: DuploCloud Job
on:
- push
jobs:
  run-duplo-job:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout Repository
      uses: actions/checkout@v4
    
    # Setup DuploCloud authentication
    - name: DuploCloud Setup
      uses: duplocloud/actions@main
      
    # Run the job using the new action
    - name: Run Job
      uses: duplocloud/actions/run-job@main
      with:
        file: job.yaml
        wait: true
        loglevel: INFO
```

The `run-job` action uses `duploctl` directly, providing better integration with DuploCloud. Note that the job format for `duploctl` is slightly different - see the [run-job documentation](../run-job) for examples.
