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
| `bundle-bucket` | no | `duplo-helpdesk-channels` | The S3 bucket the AWS backend uploads bundles to. |

## What the caller provides

The caller checks out with `fetch-depth: 0`, so the action can read the repository's tags and their history, and grants
`contents: write` to create releases. A DuploCloud repository that uploads through the AWS backend also assumes its
publisher role and grants `id-token: write`. The action does not assume the role itself.

## The two credential shapes

A DuploCloud repository, which signs, obfuscates and uploads with the assumed role:

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      id-token: write
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
          publish: true
```

A customer repository, which holds only a console key and uploads through a console-issued URL:

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: duplocloud/actions/release-extension@v1
        with:
          console-api-key: ${{ secrets.CONSOLE_API_KEY }}
          console-team: my-team
```

## What fails, and why

- In `duplocloud` and `duplocloud-internal`, a missing `signing-key`, `signing-cert` or `armdot-license` fails the job
  before the build. DuploCloud releases are always signed and obfuscated. Elsewhere signing runs only when both a key
  and a certificate are supplied, and `armdot-license` is ignored.
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
