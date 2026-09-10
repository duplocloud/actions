# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Setup action: new `mode` input (`auto`/`portal`/`helpdesk`). In `helpdesk` mode the action targets a standalone AI HelpDesk (`DUPLO_HOST` = helpdesk URL, `DUPLO_TOKEN` = `dahp_` API token) and skips the portal discovery, cloud JIT, and cloud CLI steps. The default `auto` detects the mode from the `dahp_` token prefix; the resolved mode is exported as `DUPLO_MODE`.
- `ai-helpdesk` action: new `agent_id`, `workspace`, and `workspace_id` inputs. Workspace selectors fall back to `DUPLO_WORKSPACE` / `DUPLO_WORKSPACE_ID` environment variables.
- `update-image` action now supports updating sidecar (additional) and init container images for Kubernetes services via new `container_images` and `init_container_images` JSON inputs. Main `image` is now optional when one of these is provided. Only applicable when `type=service`.

### Changed

- **Breaking:** `ai-helpdesk` action migrated from the removed `duploctl ai create_ticket` command to `duploctl ticket create_ticket` (duploctl >= 0.4.5). Tickets are workspace-scoped: a workspace selector replaces the `DUPLO_TENANT` requirement, `agent_name` is now one-of with the new `agent_id`, and the `agent_instance` input is removed (the instance concept no longer exists in the ticket API). Works against both integrated portals and standalone AI HelpDesks.
- `ai-helpdesk` action parses the duploctl JSON result with `jq` instead of grep, keeping duploctl log output (stderr) out of the parsed file.
- Bumped the default duploctl version from 0.4.3 to 0.4.5, which includes the fix for the `'ReplicasActive'` KeyError during service wait polling

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
