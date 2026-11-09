# Release extension

Takes a repository's built DuploCloud extensions through signing, a GitHub release, console registration, upload and
optional publishing. The repository's own build runs first, through `build-command`, and this action owns everything
after it. It serves both a DuploCloud repository, which signs and obfuscates, and a customer pipeline that holds only
a console key.

## Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `console-api-key` | yes | | Secret. The console API key that registers versions and artifacts. |
| `console-url` | no | `https://console.duplocloud.com` | The console base URL. |
| `console-team` | no | | The console team whose agents routes to use. Empty uses the staff routes, which need `view_agents`. |
| `build-command` | no | `./scripts/build-all.sh` | The repository's build, run before anything is signed or released. |
| `sdk-versions` | no | | Newline-separated SDK versions the build produced a bundle for. Empty means one default bundle. |
| `name` | no | | Agent display name for a single-extension repository. Defaults to the manifest's `name`, then its `id`. |
| `description` | no | | Agent description for a single-extension repository. Defaults to the manifest's `description`. |
| `changelog` | no | | Changelog text for the version, for a single-extension repository. |
| `publish` | no | `false` | Publish a version when this run registered its first build. One already published is left alone. |
| `signing-key` | no | | Secret. The publisher's private key PEM. Required in DuploCloud's organizations. |
| `signing-cert` | no | | The publisher's certificate. Required in DuploCloud's organizations. |
| `armdot-license` | no | | Secret. Base64 of the ArmDot license file. Required in DuploCloud's organizations, ignored elsewhere. |
| `armdot-config-token` | no | | Secret. A GitHub token that can read `duplocloud-internal/.github`, where the ArmDot build files live; the release bot token. Required in DuploCloud's organizations, ignored elsewhere. |
| `bundle-bucket` | no | `duplo-helpdesk-channels` | The S3 bucket the AWS backend uploads bundles to. |

## What the caller provides

The caller checks out with `fetch-depth: 0`, so the action can read the repository's tags and their history, and grants
`contents: write` to create releases. A DuploCloud repository that uploads through the AWS backend also assumes its
publisher role and grants `id-token: write`. The action does not assume the role itself.

The build the action runs is the repository's own. Devkit's `scripts/build-all.sh` takes the SDK from the host named by
`DUPLO_HOST` and `DUPLO_TOKEN`, so the job carries both in its `env`. Without them the build falls back to devkit's
local target, a stack on the runner that does not exist, and fails before anything is signed.

## The two credential shapes

A DuploCloud repository, which signs, obfuscates and uploads with the assumed role. On a push `publish` is false, so
the version registers unpublished and a platform owner publishes it in the console once the build is verified. A
hand-run with its `publish` input checked publishes only the versions that run registers a first build for, so a
version a push to `main` already released is published in the console.

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      publish:
        description: Publish each version this run registers a first build for
        type: boolean
        default: false

jobs:
  release:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: write
      id-token: write
    env:
      DUPLO_HOST: ${{ secrets.DUPLO_HOST }}
      DUPLO_TOKEN: ${{ secrets.DUPLO_TOKEN }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.EXTENSION_PUBLISHER_ROLE_ARN }}
          aws-region: us-west-2
      - uses: duplocloud/actions/release-extension@v1
        with:
          console-api-key: ${{ secrets.CONSOLE_API_KEY }}
          signing-key: ${{ secrets.CONSOLE_SIGNING_KEY }}
          signing-cert: ${{ vars.CONSOLE_SIGNING_CERT }}
          armdot-license: ${{ secrets.ARMDOT_LICENSE_KEY }}
          armdot-config-token: ${{ secrets.RELEASE_BOT_GITHUB_TOKEN }}
          publish: ${{ inputs.publish || false }}
```

A customer repository, which holds only a console key and uploads through a console-issued URL:

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    env:
      DUPLO_HOST: ${{ secrets.DUPLO_HOST }}
      DUPLO_TOKEN: ${{ secrets.DUPLO_TOKEN }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: duplocloud/actions/release-extension@v1
        with:
          console-api-key: ${{ secrets.CONSOLE_API_KEY }}
          console-team: my-team
```

## Where the console values come from

A platform owner sets each of these up once in the console, and they then serve every release.

- `console-api-key`: in the platform-owner team, create a custom role holding View agent versions, Manage agent
  versions and `view_agents`, create a service account with that role, and store its API key as a secret. The action
  looks the extension up by manifest id on the staff routes, which `view_agents` covers, then reads and creates
  versions and artifacts, and publishes when asked. A customer pipeline uses a key from its own team instead and
  passes that team as `console-team`, which needs no staff capability.
- `signing-key` and `signing-cert`: the publishing team needs a namespace covering its manifest ids, and a signing key
  created under that team. The console returns the key's private PEM once, at creation, and that is the secret. The
  key's certificate is the variable. The certificate names the namespaces it signs for, so an id outside them is
  refused at signing.
- The extension's record: an agent under the same team whose manifest id equals the `id` in the extension's
  `manifest.json`. The action finds the record by that id and fails when none exists.
- `armdot-config-token`, in DuploCloud's organizations: the ArmDot build files (the props, targets, assembly attributes
  and the targets template devkit drops beside a csproj) live under `armdot/` in the private `duplocloud-internal/.github`,
  not in the public devkit. The action fetches them with this token into `$RUNNER_TEMP/armdot` before the build and
  hands devkit's build the path in `DUPLO_ARMDOT_DIR`. The organization secret `RELEASE_BOT_GITHUB_TOKEN` reads that
  repository. Outside DuploCloud's organizations nothing is fetched.

The console's platform-owner guide has the service-account setup in `docs/platform_owner/agent-versions.md` and the
signing-key screens in `docs/platform_owner/agent-publishers.md`, both in the console repository.

## What fails, and why

- In `duplocloud` and `duplocloud-internal`, a missing `signing-key`, `signing-cert`, `armdot-license` or
  `armdot-config-token` fails the job before the build, and so does a fetch of the ArmDot build files that the token
  cannot make. DuploCloud releases are always signed and obfuscated. Elsewhere signing runs only when both a key and a
  certificate are supplied, and the two ArmDot inputs are ignored.
- A `name`, `description` or `changelog` set in a repository with more than one extension fails before the build, since
  one value cannot label several agents. Set those in each `manifest.json` instead.
- A build whose bundle carries no `armdot` obfuscation stamp fails in a DuploCloud organization. Set `armdot-license`,
  or upgrade the devkit.
- When `sdk-versions` lists versions the build produced no bundle for, the job fails naming the devkit upgrade, before
  anything is signed.
- When no agent in the console has the extension's manifest id, the job fails and asks for the agent to be created
  first. On the staff routes a 403 means the console key's role is missing `view_agents`.

## Re-runs

Every write is create-only, so a re-run of a finished release changes nothing. A run that stopped after registering an
artifact but before the upload retries the upload on the next run and ends clean, since registration happens first. A
release at an existing tag is never rebuilt or re-signed. Its assets are read back instead, so a run that stopped
between releasing and registering still finishes. A version a platform owner unpublished stays unpublished, since
`publish` only publishes a version's first build.
