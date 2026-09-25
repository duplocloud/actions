# AI HelpDesk Ticket Action

Creates AI HelpDesk tickets when GitHub Actions workflows fail, providing comprehensive context for automated analysis and troubleshooting.

Works against both deployment modes:

- **Integrated** — the AI HelpDesk running inside a DuploCloud portal (`DUPLO_HOST` is the portal URL, `DUPLO_TOKEN` a portal token).
- **Standalone** — a standalone AI HelpDesk (`DUPLO_HOST` is the helpdesk URL, `DUPLO_TOKEN` a `dahp_` API token minted from the helpdesk).

Tickets are workspace-scoped, so a workspace selector is required in both modes; `DUPLO_TENANT` is not used.

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `agent_name` | Name of the AI agent to handle the ticket. One of `agent_name` or `agent_id` is required. | No | `""` |
| `agent_id` | Id of the AI agent. Skips the agent name lookup when provided. | No | `""` |
| `workspace` | AI HelpDesk workspace name to create the ticket in. Falls back to the `DUPLO_WORKSPACE` environment variable. One of `workspace` or `workspace_id` is required (via input or environment). | No | `""` |
| `workspace_id` | AI HelpDesk workspace id. Skips the workspace name lookup when provided. Falls back to `DUPLO_WORKSPACE_ID`. | No | `""` |
| `title` | Ticket title. Defaults to "Workflow Failure: {workflow_name}" if not provided | No | `""` |
| `context` | Contextual header section. Defaults to auto-generated workflow details if not provided | No | `""` |
| `content` | Additional content appended after the context section | No | `""` |
| `include_sensitive_data` | Whether to include sensitive data (repository, actor, branch, commit) in ticket context | No | `true` |
| `hide_response` | Set to true to hide the agent response in the summary. The response is shown by default. | No | `false` |

## Usage

### Integrated portal

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
    steps:
      - name: Duplo Setup
        uses: duplocloud/actions@main
      - name: Create AI HelpDesk Ticket
        uses: duplocloud/actions/ai-helpdesk@main
        with:
          agent_name: ${{ vars.AGENT_NAME }}
          workspace: ${{ vars.DUPLO_WORKSPACE }}
          content: |
            Additional troubleshooting information:
            - Check logs in CloudWatch
            - Verify database connectivity
            - Review recent configuration changes
```

### Standalone AI HelpDesk

Point `DUPLO_HOST` at the standalone helpdesk and use a `dahp_` API token as
`DUPLO_TOKEN`. The setup action detects the token prefix and skips the
portal-only steps automatically.

```yaml
    env:
      DUPLO_HOST: ${{ vars.DUPLO_HOST }}        # https://my-helpdesk.example.com
      DUPLO_TOKEN: ${{ secrets.DUPLO_TOKEN }}   # dahp_...
      DUPLO_WORKSPACE: ${{ vars.DUPLO_WORKSPACE }}
    steps:
      - name: Duplo Setup
        uses: duplocloud/actions@main
      - name: Create AI HelpDesk Ticket
        uses: duplocloud/actions/ai-helpdesk@main
        with:
          agent_name: ${{ vars.AGENT_NAME }}
```

## Prerequisites

This action requires the `duplocloud/actions@main` setup action to be run first to install duploctl and configure environment variables. It needs duploctl >= 0.4.5 (the default installed by the setup action), which provides the `duploctl ticket create_ticket` command.
