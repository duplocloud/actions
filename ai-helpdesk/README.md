# AI HelpDesk Ticket Action

An action that automatically creates a HelpDesk ticket when a workflow fails.

**Default Behavior**: Creates tickets with comprehensive workflow context for AI analysis.

**Flexible Content**: Supports custom title, context, and content inputs for maximum flexibility.

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `agent_name` | Agent Name | true | - |
| `agent_instance` | Agent Instance ID | true | - |
| `title` | Ticket title (optional) | false | `Workflow Failure: {workflow}` |
| `context` | Contextual header content (optional) | false | [Default Context](#default-context) |
| `content` | Main ticket content (optional) | false | - |
| `include_sensitive_data` | Include sensitive data like repository name, actor, branch in ticket (optional) | false | `true` |

### Default Context

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
- name: Duplo Setup
  uses: duplocloud/actions@main

- name: Create AI HelpDesk Ticket
  uses: duplocloud/actions/ai-ticket@v1
  with:
    agent_name: ${{ vars.AGENT_NAME }}
    agent_instance: ${{ vars.AGENT_INSTANCE }}
```

### Custom Content

```yaml
- name: Duplo Setup
  uses: duplocloud/actions@main

- name: Create AI HelpDesk Ticket
  uses: duplocloud/actions/ai-ticket@v1
  with:
    agent_name: ${{ vars.AGENT_NAME }}
    agent_instance: ${{ vars.AGENT_INSTANCE }}
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
- name: Duplo Setup
  uses: duplocloud/actions@main

- name: Create AI HelpDesk Ticket
  uses: duplocloud/actions/ai-ticket@v1
  with:
    agent_name: ${{ vars.AGENT_NAME }}
    agent_instance: ${{ vars.AGENT_INSTANCE }}
    include_sensitive_data: false
    content: |
      Workflow failed but sensitive details are excluded.
      Please check the workflow logs for more information.
```

## Security Considerations

### Sensitive Data Control

By default, the action includes sensitive information in tickets (repository name, actor, branch, commit SHA, run URL). For private repositories or sensitive environments, you can disable this:

```yaml
- name: Create AI HelpDesk Ticket
  uses: duplocloud/actions/ai-ticket@v1
  with:
    # ... other inputs ...
    include_sensitive_data: false
```

When `include_sensitive_data: false`, only workflow name, run ID, and event type are included.

### Environment Variables

The action uses standard GitHub environment variables and assumes `duploctl` is available in the environment (installed by the main setup action).

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
      - name: Duplo Setup
        uses: duplocloud/actions@main
      - name: Create AI HelpDesk Ticket
        uses: duplocloud/actions/ai-ticket@v1
        with:
          agent_name: ${{ vars.AGENT_NAME }}
          agent_instance: ${{ vars.AGENT_INSTANCE }}
```
