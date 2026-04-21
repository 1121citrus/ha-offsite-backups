# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0](https://github.com/1121citrus/ha-offsite-backups/compare/v1.0.0...v2.0.0) (2026-04-21)


### ⚠ BREAKING CHANGES

* retention/rotation-oriented behavior and related interfaces were replaced by sync-oriented behavior (rename + upload), with updated defaults and environment variable expectations

### Features

* **build:** replace manual build with generated script ([83878f2](https://github.com/1121citrus/ha-offsite-backups/commit/83878f2d4a990c91af9806dda801cc8e7cc4dab0))
* **build:** standardize advisory stages and staging harness with sibling S3 projects ([3e7bbde](https://github.com/1121citrus/ha-offsite-backups/commit/3e7bbde2cf7077df57769b1d4e77d567eb31d93d))
* major ha-offsite-backups upgrade to improve implentation, build, test, CI abd Documentation ([08d2cba](https://github.com/1121citrus/ha-offsite-backups/commit/08d2cba7b340b9f50e0565d84a0637c445ce97de))
* **test/staging:** add --cache option for one-run DB cache control ([0a26340](https://github.com/1121citrus/ha-offsite-backups/commit/0a263407ebbbb4366605133f292635bd8624a3a5))
* **test:** add staging integration command and smoke bucket control ([985cb35](https://github.com/1121citrus/ha-offsite-backups/commit/985cb358119a4ac77e1153611d0200fa84981e97))


### Bug Fixes

* **build:** add _require_value guard (generated script update) ([4ed888f](https://github.com/1121citrus/ha-offsite-backups/commit/4ed888f18cb5ce17d281d12b30427aa8e128ddb9))
* **security:** remediate grype CRITICAL/HIGH CVEs; document accepted findings ([2d1dad3](https://github.com/1121citrus/ha-offsite-backups/commit/2d1dad378ddb3acd81661141edf77445a12078dc))

## [Unreleased]

### Added
- Initial release of ha-offsite-backups
- Support for scheduling Home Assistant backups to S3 via cron
- Dry-run mode enabled by default for safety
- DRYRUN=false required for live backup operations
- Health-check endpoint to verify cron job execution
- Configurable S3 bucket, backup directory, and cron schedule
- SLSA Level 3 provenance attestations
- SBOM (Software Bill of Materials) generation

### Security
- Non-root execution (UID 10001)
- Minimal Alpine base image
- Docker secret support for AWS configuration
- Read-only filesystem support
- No outbound network access outside cron job

---

## [1.0.0] - 2026-03-23

### Added
- Initial release

[Unreleased]: https://github.com/1121citrus/ha-offsite-backups/compare/1.0.0...HEAD
[1.0.0]: https://github.com/1121citrus/ha-offsite-backups/releases/tag/1.0.0
