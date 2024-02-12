# Kubernetes Job Runner  

An action to run an arbitrary kubernetes job and watch it until it completes or fails. This will report back the end status as well as the logs from the job.

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
                    echo "Hello World, I'm in Kubernetes!"
          EOF

      - name: Apply and Watch
        uses: duplocloud/actions/k8s-job@main
```
