# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added 

- New run-job action for running Kubernetes jobs via duploctl which deprecates the k8s-job action
- Added var-files for terraform-exec action, to allow custom tfvars.json files to be used
- security-scan: dependency-CVE scanning (`trivy fs`), the one category nothing covered — no SCA existed anywhere, not even disabled
- security-scan: `mode` input (`all`/`source`/`image`, with `both`/`iac` accepted as aliases of the sibling wiz-scan vocabulary) so a post-build step can scan the image without repeating the source scans
- security-scan: `tool-errors` output — the number of scanners that failed to run
- security-scan: a `TOOL-ERROR` state distinct from findings, so a scanner that could not run is never reported as one that found something
- security-scan: trufflehog now also scans **git history**; callers already checked out with `fetch-depth: 0` for it, but only gitleaks ever read it
- security-scan: `semgrep-first-party-owners` input — semgrep's action-pinning rule cannot distinguish action owners and flagged GitHub's own `actions/*` as loudly as a stranger's repo (~70% of all semgrep findings across the org). It is now replaced with a rule that fires only on owners outside the allowlist
- security-scan: `Brookai` added to the default `semgrep-first-party-owners`, so in-org refs are exempt from the action-pinning check everywhere without each repo setting the input. The SHA-pinning convention for `Brookai/*` is now held by review rather than by the scan
- security-scan: the action now uploads the scan reports as a workflow artifact itself, named per invocation. They were previously written, copied into the workspace and discarded unless the caller happened to add its own upload step
- security-scan: the job summary now **itemises the findings** — severity, rule and `file:line` per scanner, rolled up by rule past 25 — instead of only saying that a scanner found something. Rule and location only; matched values are never printed
- security-scan: source SBOM and Dockerfile lint now run on every scan — both sat behind `scan-image`, which no caller sets, so neither had ever run

### Fixed
- security-scan: the image scanners now receive registry credentials via `DOCKER_CONFIG` pointed at a mounted config directory, instead of a file mounted at `/root/.docker/config.json`. The old form assumed every scanner image runs as root with `HOME=/root` — true for trivy, false for syft, whose image has no `/etc/passwd` and no `/root`, so docker set `HOME=/` and syft read `/.docker/config.json`. It silently authenticated as nobody and every private-registry pull came back `401`. On the first real ECR builds across the fleet (2026-08-28) `trivy-image` scanned normally while `syft-sbom-image` returned `TOOL-ERROR` in every repo. The self-test had missed it because it scans a public image, which needs no credentials

- security-scan: image scanning requested with an empty `image-ref` reported `SKIP` and `pass`, having scanned nothing — with `mode: image` that meant the entire run was a no-op reporting green. Now a `TOOL-ERROR`, and `mode: image` implies `scan-image` so the two inputs cannot disagree
- security-scan: the git-history secret scan ran against repos with a `.git` directory but no commits, where trufflehog fails on the missing index — now an honest `SKIP`
- security-scan: the job summary counted and displayed findings the scanner itself had **suppressed** (SARIF `suppressions[]`, from `# nosemgrep` / `checkov:skip=` annotations). The status row and the findings list contradicted each other — checkov reporting `Failed checks: 0` while the summary showed "checkov — 2 findings"

- security-scan: `trivy config` and `semgrep` could never fail a build. Neither exits non-zero on findings without `--exit-code`/`--error`, so both logged `PASS` while printing HIGH/CRITICAL findings — only checkov, gitleaks and trufflehog were ever real gates, and `enforce: true` would not have changed that
- security-scan: a scanner that failed to start was recorded as one that found things. With the secret category bypassing `enforce`, a denied image pull surfaced to the author as "you committed a secret". Every scanner now declares its findings exit code, and trivy/gitleaks were moved off the ambiguous `1` onto `--exit-code 7`
- security-scan: checkov only ran `--framework terraform`, so in a repo with no Terraform it examined nothing and still logged `PASS`, while the kubernetes, dockerfile and github_actions files it could have checked went unscanned
- security-scan: reports were written inside the tree being scanned, so each scanner walked the earlier ones' SARIF and a secret quoted in a finding snippet became a fresh finding. Scanning now happens outside the tree; reports are copied in at the end
- security-scan: hadolint only checked `./Dockerfile`, missing repos that keep theirs at `docker/Dockerfile`, and matched `Dockerfile.*` widely enough to lint `.j2`/`.template`/`.bak` files that are not valid Dockerfile syntax
- security-scan: scanner images were pinned by mutable tag; they are now pinned by digest
- security-scan: a docker config using a credential helper was mounted into the scanner containers, where the helper binary does not exist — trivy died with a FATAL init error before looking at the image. Only inline `auths` entries are mounted now
- security-scan: `AWS_*` credentials were forwarded to syft, which does not consume them for ECR, and forwarded even when the registry-scoped docker config was already mounted
- security-scan: `trivy image` had no `--image-src remote` and probed absent docker/containerd/podman sockets first
- security-scan: `trivy fs` and `syft` walked `.git` (full history), `node_modules` and `vendor`
- security-scan: no shared trivy cache — `config`, `fs` and `image` each re-downloaded the vulnerability DB
- security-scan: an invalid `mode` exited before writing the `result` output, so callers gating on `result != 'pass'` took the wrong branch

### Changed
- Updated ai-helpdesk action to display the first agent response in the summary by default with optional `hide_response` parameter
- security-scan: `enforce: "true"` now also fails on scanner failures, not just findings
- security-scan: the trivy scans emit JSON reports rather than console-only output, so their findings can be itemised and baselined
- The default duploctl version is now `0.4.5` (was `0.3.7`). With 0.3.7, `update_image --wait` on a service fails with `KeyError: 'Name'` whenever the tenant has a pod Duplo didn't create, such as one started with `kubectl run`. Since 2026-10-29 that failed every ai-platform deploy to dev01

## [0.0.13] - 2025-09-23

### Added

- an override for the bucket name on the terrafom-module action
- Validation to prevent redundant duploctl install in setup
- Added condition to skip setting python and pip upgrade when python-version is 'none'
- Added build-image support to build and push docker image to Azure Container Registry
- Added target input to terraform-exec action
- Added `ai-helpdesk` action for creating HelpDesk tickets from workflows
- Added `update-images` action for bulk updating multiple service images

### Changed

- Removed the step that checks if the plan artifact exists in Terraform workflow

## [0.0.12] - 2025-04-15

## [0.0.11] - 2025-03-05

- new action that takes a running services image and tags it with a new tag
