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
  integrated portal base URL. HTTPS is required.
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
| `duplo_token_expires_in` | API token lifetime in seconds from issuance |

The credential is exported as `DUPLO_TOKEN` for the current job, rather than
as an action or job output. Each job that needs access should log in itself.

## Referencing and releasing

After this change is merged, users can immediately reference
`duplocloud/actions/login@main`. A versioned reference must point to a release
that includes the `login` directory. The existing `v1.0.0` release predates this
new action.

The repository releases all its actions together. After merging, maintainers
can use the existing **Publish Version** workflow on `main`, choosing `minor`
and setting `push` to `true` (the default is a dry run). A minor release is
appropriate for adding this action; if the current release remains `v1.0.0`,
that produces `v1.1.0`. The workflow creates the release tag and updates the
floating `v1` tag. No separate login-action package or build step is needed.

After publishing a release containing login, users can choose:

```yaml
# Follows released, compatible 1.x updates:
- uses: duplocloud/actions/login@v1
  with:
    trust_name: github-deploy
```

For a fixed release, replace `@v1` with its exact published tag, or pin the full
commit SHA for an immutable reference. `@main` follows development commits.
A separate Marketplace listing is not required to use the subdirectory action.

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

## Manual integration test

The `Test OIDC login against HelpDesk` workflow is manually triggered and targets
`https://helpdesk-dev01.test21-apps.duplocloud.net`. It runs the actual `login`
action from the selected checkout, so a feature branch can be tested before release.

```bash
gh workflow run test-login-live.yml \
  --repo duplocloud/actions \
  --ref feature/DUPLO-45122-oidc-login \
  -f trust_name=github
# Add -f audience=<exact-trust-audience> if it differs from the HelpDesk URL.
```

The trust must allow `duplocloud/actions` and the selected branch/ref. The workflow
checks that an anonymous `GET /v3/user/settings` is rejected, logs in using GitHub
OIDC, then calls that API from a separate step using the exported `DUPLO_TOKEN`.
It requires HTTP 200 and a JSON object. Tokens and response contents are not printed.
The workflow summary records which checks passed and the returned token lifetime.
