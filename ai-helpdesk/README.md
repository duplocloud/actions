# AI HelpDesk Ticket Action

Creates AI HelpDesk tickets when GitHub Actions workflows fail, providing comprehensive context for automated analysis and troubleshooting.

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `title` | Ticket title. Defaults to "Workflow Failure: {workflow_name}" if not provided | No | `""` |
| `context` | Contextual header section. Defaults to auto-generated workflow details if not provided | No | `""` |
| `content` | Additional content appended after the context section | No | `""` |
| `include_sensitive_data` | Whether to include sensitive data (repository, actor, branch, commit) in ticket context | No | `true` |

## Usage

```yaml
name: Create HelpDesk Ticket

on:
  workflow_run:
    workflows: ["CI"]
    types:
      - completed

jobs:
  create-helpdesk-ticket:
    if: ${{ github.event.workflow_run.conclusion == 'failure' }}
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
          content: |
            Additional troubleshooting information:
            - Check logs in CloudWatch
            - Verify database connectivity
            - Review recent configuration changes
```

## Prerequisites

This action requires the `duplocloud/actions@main` setup action to be run first to install duploctl and configure environment variables.
