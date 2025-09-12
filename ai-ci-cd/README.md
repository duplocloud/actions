# AI HelpDesk Ticket Action

An action that automatically creates a HelpDesk ticket when a workflow fails.

**Default Behavior**: Creates tickets with comprehensive workflow context for AI analysis.

**Additional Content**: Supports optional `additional_content` input to append custom context to the default content.

**Custom Override**: Supports optional `override_title` and `override_content` inputs to override the default content with custom context for specific use cases.


## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `agent_name` | Agent Name | true | - |
| `agent_instance` | Agent Instance ID | true | - |
| `duplo_host` | DuploCloud Host URL | true | - |
| `duplo_tenant` | DuploCloud Tenant | true | - |
| `duplo_token` | DuploCloud Token | true | - |
| `additional_content` | Additional content to append to default (optional) | false | - |
| `override_title` | Override ticket title (optional) | false | `CI/CD Failure: {repository}` |
| `override_content` | Override ticket content (optional) | false | [Default Content](#default-content) |

### Default Content

```yaml
Workflow Details:
- Repository: ${{ github.repository }}
- Workflow: ${{ github.workflow }}
- Run ID: ${{ github.run_id }}
- Commit: ${{ github.sha }}
- Actor: ${{ github.actor }}
- Branch: ${{ github.ref_name }}
- Event: ${{ github.event_name }}
- Run URL: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

## Usage

### Basic Usage

```yaml
- name: Create AI HelpDesk Ticket
  uses: duplocloud/actions/ai-ci-cd@main
  with:
    agent_name: ${{ vars.AGENT_NAME }}
    agent_instance: ${{ vars.AGENT_INSTANCE }}
    duplo_host: ${{ vars.DUPLO_HOST }}
    duplo_tenant: ${{ vars.DUPLO_TENANT }}
    duplo_token: ${{ vars.DUPLO_TOKEN }}
```

### Additional Content

```yaml
- name: Create AI HelpDesk Ticket
  uses: duplocloud/actions/ai-ci-cd@main
  with:
    agent_name: ${{ vars.AGENT_NAME }}
    agent_instance: ${{ vars.AGENT_INSTANCE }}
    duplo_host: ${{ vars.DUPLO_HOST }}
    duplo_tenant: ${{ vars.DUPLO_TENANT }}
    duplo_token: ${{ vars.DUPLO_TOKEN }}
    additional_content: |

      Additional Context:
      - This is a critical deployment failure
      - Environment: production
      - Impact: service unavailable
```

### Overrides

```yaml
- name: Create AI HelpDesk Ticket
  uses: duplocloud/actions/ai-ci-cd@main
  with:
    agent_name: ${{ vars.AGENT_NAME }}
    agent_instance: ${{ vars.AGENT_INSTANCE }}
    duplo_host: ${{ vars.DUPLO_HOST }}
    duplo_tenant: ${{ vars.DUPLO_TENANT }}
    duplo_token: ${{ vars.DUPLO_TOKEN }}
    override_title: "Override Ticket Title: ${{ github.workflow }}"
    override_content: |
      Override ticket content for use-case context:
      - Repository: ${{ github.repository }}
      - Workflow: ${{ github.workflow }}
      - Run ID: ${{ github.run_id }}
      - Additional context
```

## Example

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Build
        run: |
          echo "Building..."
          exit 1

  create-helpdesk-ticket:
    needs: [build] # List all jobs to be monitored for failures
    if: failure() # Only run when the specified jobs fail
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Create DuploCloud AI HelpDesk Ticket
        uses: duplocloud/actions/ai-ci-cd@main
        with:
          agent_name: ${{ vars.AGENT_NAME }}
          agent_instance: ${{ vars.AGENT_INSTANCE }}
          duplo_host: ${{ vars.DUPLO_HOST }}
          duplo_tenant: ${{ vars.DUPLO_TENANT }}
          duplo_token: ${{ vars.DUPLO_TOKEN }}
```
