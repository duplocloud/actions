# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- New `update-image-hdv2` action — the AI HelpDesk V2 (HDV2) counterpart to `update-image`. Updates a container image for an HDV2 workload within a workspace via duploctl: `type=service` (alias `eks`) targets `appservice`, `type=lambda` targets `hd_lambda`, and `type=cronjob` targets `hd_cronjob update_image`. Takes `name`, `image`, and one of `workspace`/`workspace_id` (falling back to `DUPLO_WORKSPACE`/`DUPLO_WORKSPACE_ID`); requires only `DUPLO_HOST`/`DUPLO_TOKEN`, so it works against integrated portals and standalone AI HelpDesks alike. ECS is not yet supported (no HDV2 backend endpoint; tracked in DUPLO-43548).
- New `k8s-credentials` action — fetches just-in-time Kubernetes credentials for an AI HelpDesk cluster (`duploctl k8s_credentials`) and writes a kubeconfig, exporting `KUBECONFIG` for later kubectl/helm steps. Selects the cluster by name or id (defaulting to the workspace's only cluster), falls back to the cluster record's certificate authority when jitAccess returns none (current AWS gap), rejects incomplete CAs with a clear error (opt-out via `insecure_skip_tls_verify`), and works against integrated portals and standalone AI HelpDesks.
- New `update-images-hdv2` action — the HDV2 counterpart to `update-images`. Bulk-updates images for multiple workloads from a `workloads` JSON array (`{name, image, type?}`; types `service`/`lambda`/`cronjob`), validating every entry before touching anything and then updating sequentially with fail-fast. Workspace selector falls back to `DUPLO_WORKSPACE`/`DUPLO_WORKSPACE_ID`; requires only `DUPLO_HOST`/`DUPLO_TOKEN`.
- New `aws-credentials` action — mints just-in-time AWS credentials from an AI HelpDesk workspace (`duploctl aws_credentials`) for a cloud scope (by name/id, defaulting to the workspace's only AWS scope) or the IAM role attached to a resource group, exporting masked `AWS_*` environment variables for later steps plus `region`/`console_url`/`expiration` outputs. Works against integrated portals and standalone AI HelpDesks.
- `update-image` action now supports updating sidecar (additional) and init container images for Kubernetes services via new `container_images` and `init_container_images` JSON inputs. Main `image` is now optional when one of these is provided. Only applicable when `type=service`.

## [0.1.0] - 2026-05-13

### Fixed

- Restored `mask-account-id` default to `false`, matching the historical effective behavior where the previous default of `'yes'` was silently evaluated as `false` by `aws-actions/configure-aws-credentials@v4`

### Added

- Added support for --wait-timeout for bulk and standard image updates

## [0.0.14] - 2026-03-19

### Added

- Added logging support to bulk-image-update
- New run-job action for running Kubernetes jobs via duploctl which deprecates the k8s-job action
- Added var-files for terraform-exec action, to allow custom tfvars.json files to be used

### Changed
- Updated ai-helpdesk action to display the first agent response in the summary by default with optional `hide_response` parameter

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
