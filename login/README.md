# DuploCloud Login

Authenticate a GitHub Actions job to standalone AI HelpDesk or integrated
DuploCloud using OIDC, without storing
a long-lived `DUPLO_TOKEN` secret. Run this action **before** the DuploCloud
setup action and any steps that need HelpDesk access.

The action requests a signed JWT from GitHub with the selected audience and
exchanges it at `POST /v3/auth/oidc/{trust_name}/token`. It masks the
JWT and returned API token, then writes the raw API token to `DUPLO_TOKEN`
through `GITHUB_ENV`. All subsequent steps in the same job receive it. No
`Bearer ` prefix is included in the variable; clients add that themselves.

## Prerequisites

- An enabled GitHub OIDC trust in the deployment's auth service, bound to the intended user and
  repository/workflow conditions. Its name is the `trust_name` input.
- `DUPLO_HOST` set at job or workflow scope to the standalone HelpDesk or
  integrated portal base URL. HTTPS is required. Standalone installations
  must include the shared `/v3/auth/oidc` route; older HelpDesk versions
  exposing only `/v1/aiservicedesk/oidc` need a backend upgrade.
- Job permission `id-token: write`. This allows requesting an OIDC JWT;
  the configured trust determines what that identity can access.
- The `audience` must exactly match the trust, including any trailing slash.
  The default is `DUPLO_HOST` with trailing slashes removed. Override it when
  the trust uses a custom audience.
- A runner supporting Node.js 24 JavaScript actions. No checkout, duploctl,
  Python, curl, jq, or dependency installation is needed for login itself.

## Inputs and outputs

| Input | Required | Default |
|---|---|---|
| `trust_name` | Yes | Configured OIDC trust name; required by the backend exchange URL |
| `audience` | No | `DUPLO_HOST` without trailing slashes |

| Output | Description |
|---|---|
| `expires_in` | API token lifetime in seconds from issuance |

The credential is exported as `DUPLO_TOKEN` for the current job, rather than
as an action or job output. Each job that needs access should log in itself.

## Usage and migration

Remove `DUPLO_TOKEN: ${{ secrets.DUPLO_TOKEN }}` from workflow, job, and step
environments. A step-level token override would hide the newly exported token.
Keep `DUPLO_HOST` and workspace configuration as before; existing HelpDesk
actions continue to read `DUPLO_TOKEN` without changes.

```yaml
permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      DUPLO_HOST: ${{ vars.DUPLO_HOST }}
      DUPLO_WORKSPACE: ${{ vars.DUPLO_WORKSPACE }}
    steps:
      - name: Log in to HelpDesk
        id: login
        uses: duplocloud/actions/login@main
        with:
          trust_name: github-deploy
          # audience: api://my-custom-audience

      - name: Install DuploCloud tools
        uses: duplocloud/actions@main

      - name: Obtain AWS credentials through HelpDesk
        uses: duplocloud/actions/aws-credentials@main
```

Both deployment modes use the same exchange URL and JSON contract:

| Deployment | Token issuer | Setup auto-detection |
|---|---|---|
| Standalone | HelpDesk auth service | `dahp_` token selects HelpDesk mode |
| Integrated | duplo-core OAuthService | Core bearer token selects portal mode |

The login action treats `access_token` as opaque and exports it unchanged.
It requires no deployment-mode input. The issuer and configured trust control
the token's permissions. Integrated ingress must route `/v3/auth/oidc` to
duplo-core auth; standalone ingress must route it to HelpDesk auth.

## Long-running pipelines

The trust controls the API token lifetime (currently 5–60 minutes). There is
no refresh token. Run `login` again immediately before a later phase that
needs access, using the same trust and audience. Every invocation requests
a JWT from GitHub and performs a new exchange; it never reuses `DUPLO_TOKEN`
to log in. Subsequent steps receive the replacement credential.

```yaml
# Earlier steps: login, setup, build, tests, approvals, ...
- name: Log in again before deployment
  uses: duplocloud/actions/login@main
  with:
    trust_name: github-deploy

- name: Deploy
  run: ./deploy.sh
```

Log in separately in each job. Re-running login updates future steps; it
cannot replace a token already held by a running process. For a single step
that needs API access beyond the configured lifetime, split it into phases
or use a client that can request fresh GitHub OIDC JWTs and exchange them
during execution. This action does not start a background refresh process.

## Verification

Run `node --test login/tests/login.test.cjs`. Tests simulate only HTTP
transport and verify requests, error handling, masking, environment exports,
and repeated login. CI runs the tests on Linux, Windows, and macOS with Node 24.
