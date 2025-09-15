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
  - `AGENT_NAME` - AI HelpDesk agent name (e.g., `github-actions-dev`)
  - `AGENT_INSTANCE` - AI HelpDesk agent instance ID (e.g., `github-actions-dev-v1`)

**Important**: This action requires the `duplocloud/actions@main` setup action to be run first to install duploctl and configure environment variables.

## Default Context

When `context` is not provided, the action generates contextual information:

**With sensitive data (default):**
```yaml
Workflow Details:
- Repository: $GITHUB_REPOSITORY
- Workflow: $GITHUB_WORKFLOW
- Run ID: $GITHUB_RUN_ID
- Commit: $GITHUB_SHA
- Actor: $GITHUB_ACTOR
- Branch: $GITHUB_REF_NAME
- Event: $GITHUB_EVENT_NAME
- Run URL: https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID
```

**Without sensitive data:**
```yaml
Workflow Details:
- Workflow: $GITHUB_WORKFLOW
- Run ID: $GITHUB_RUN_ID
- Event: $GITHUB_EVENT_NAME
```

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
        id: create-ticket
        uses: duplocloud/actions/ai-helpdesk@v1
      - name: Display Ticket Info
        run: |
          echo "Ticket ID: ${{ steps.create-ticket.outputs.ticket_id }}"
          echo "Ticket URL: ${{ steps.create-ticket.outputs.ticket_url }}"
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
        id: create-ticket
        uses: duplocloud/actions/ai-helpdesk@v1
        with:
          title: "Critical Deployment Failure"
          context: |
            Deployment failed in production environment

            Environment Details:
            - Environment: production
            - Region: us-east-1
            - Impact: service unavailable
          content: |
            Additional troubleshooting information:
            - Check logs in CloudWatch
            - Verify database connectivity
            - Review recent configuration changes
```

### Security Mode

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
        id: create-ticket
        uses: duplocloud/actions/ai-helpdesk@v1
        with:
          include_sensitive_data: false
          content: |
            Workflow failed but sensitive details are excluded.
            Please check the workflow logs for more information.
```

## Security Considerations

### Sensitive Data Control

**Important Security Note**: By default, the action includes sensitive information in tickets (repository name, actor, branch, commit SHA, run URL). This information may be visible to the AI HelpDesk system and could potentially expose private repository details.

For private repositories or sensitive environments, you should disable this:

```yaml
- name: Create AI HelpDesk Ticket
  uses: duplocloud/actions/ai-helpdesk@v1
  with:
    # ... other inputs ...
    include_sensitive_data: false
```

When `include_sensitive_data: false`, only workflow name, run ID, and event type are included.

### Data Privacy

- **Repository Information**: Repository name and URL are included by default
- **User Information**: GitHub actor (username) is included by default
- **Code Information**: Branch name and commit SHA are included by default
- **Workflow Information**: Run ID and workflow name are always included

Consider your organization's data privacy policies when using this action with private repositories.

### Command Structure

The action uses the following `duploctl` command structure:

```bash
duploctl ai create_ticket \
  --title "$TICKET_TITLE" \
  --agent_name "$AGENT_NAME" \
  --instance_id "$AGENT_INSTANCE" \
  --message "$TICKET_MESSAGE"
```

**Note**: This command requires duploctl version 0.3.5 or later, which includes the AI HelpDesk functionality.

### Environment Variables

The action requires the following environment variables to be set:

- `DUPLO_HOST` - Duplo host URL
- `DUPLO_TENANT` - Duplo tenant name
- `DUPLO_TOKEN` - Duplo authentication token
- `AGENT_NAME` - AI HelpDesk agent name
- `AGENT_INSTANCE` - AI HelpDesk agent instance ID

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
    env:
      DUPLO_TOKEN: ${{ secrets.DUPLO_TOKEN }}
      DUPLO_HOST: ${{ vars.DUPLO_HOST }}
      DUPLO_TENANT: ${{ vars.DUPLO_TENANT }}
      AGENT_NAME: ${{ vars.AGENT_NAME }}
      AGENT_INSTANCE: ${{ vars.AGENT_INSTANCE }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Duplo Setup
        uses: duplocloud/actions@main
      - name: Create AI HelpDesk Ticket
        id: create-ticket
        uses: duplocloud/actions/ai-helpdesk@v1
```
