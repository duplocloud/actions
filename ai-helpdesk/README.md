# AI HelpDesk Ticket Action

Creates AI HelpDesk tickets when GitHub Actions workflows fail, providing comprehensive context for automated analysis and troubleshooting.

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `title` | Custom ticket title. If not provided, defaults to "Workflow Failure: {workflow_name}" | No | `""` |
| `context` | Custom contextual header content. If not provided, auto-generates workflow context | No | `""` |
| `content` | Main ticket content/body. Appended to context if provided | No | `""` |
| `include_sensitive_data` | Whether to include sensitive data (repository, actor, branch, commit) in ticket context | No | `true` |

## Outputs

| Name | Description |
|------|-------------|
| `ticket_id` | The created ticket ID |
| `ticket_url` | The URL to the created ticket |

## Prerequisites

- DuploCloud account with AI HelpDesk enabled
- duploctl version 0.3.5+ installed (handled by Duplo Setup action)
- Required environment variables (set by Duplo Setup action):
  - `DUPLO_HOST` - DuploCloud host URL
  - `DUPLO_TOKEN` - DuploCloud authentication token
  - `DUPLO_TENANT` - DuploCloud tenant name
  - `AGENT_NAME` - AI agent name for ticket routing
  - `AGENT_INSTANCE` - AI agent instance identifier

**Important**: This action requires the `duplocloud/actions@main` setup action to be run first.

## Usage

### Basic Usage

```yaml
jobs:
  create-helpdesk-ticket:
    runs-on: ubuntu-latest
    env:
      DUPLO_TOKEN: ${{ secrets.DUPLO_TOKEN }}
      DUPLO_HOST: ${{ vars.DUPLO_HOST }}
      DUPLO_TENANT: ${{ vars.DUPLO_TENANT }}
      AGENT_NAME: ${{ vars.AGENT_NAME }}
      AGENT_INSTANCE: ${{ vars.AGENT_INSTANCE }}
    steps:
      - name: Duplo Setup
        uses: duplocloud/actions@main
      - name: Create AI HelpDesk Ticket
        uses: duplocloud/actions/ai-helpdesk@v1
```

### Custom Content

```yaml
jobs:
  create-helpdesk-ticket:
    runs-on: ubuntu-latest
    env:
      DUPLO_TOKEN: ${{ secrets.DUPLO_TOKEN }}
      DUPLO_HOST: ${{ vars.DUPLO_HOST }}
      DUPLO_TENANT: ${{ vars.DUPLO_TENANT }}
      AGENT_NAME: ${{ vars.AGENT_NAME }}
      AGENT_INSTANCE: ${{ vars.AGENT_INSTANCE }}
    steps:
      - name: Duplo Setup
        uses: duplocloud/actions@main
      - name: Create AI HelpDesk Ticket
        uses: duplocloud/actions/ai-helpdesk@v1
        with:
          title: "Critical Deployment Failure"
          content: |
            Additional troubleshooting information:
            - Check logs in CloudWatch
            - Verify database connectivity
```

### Workflow Failure Example

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Build
        run: exit 1

  create-helpdesk-ticket:
    needs: [build]
    if: failure()
    runs-on: ubuntu-latest
    env:
      DUPLO_TOKEN: ${{ secrets.DUPLO_TOKEN }}
      DUPLO_HOST: ${{ vars.DUPLO_HOST }}
      DUPLO_TENANT: ${{ vars.DUPLO_TENANT }}
      AGENT_NAME: ${{ vars.AGENT_NAME }}
      AGENT_INSTANCE: ${{ vars.AGENT_INSTANCE }}
    steps:
      - name: Duplo Setup
        uses: duplocloud/actions@main
      - name: Create AI HelpDesk Ticket
        uses: duplocloud/actions/ai-helpdesk@v1
```

## Security Note

By default, this action includes sensitive information (repository name, actor, branch, commit SHA) in tickets. For private repositories, set `include_sensitive_data: false`.
