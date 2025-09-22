# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
