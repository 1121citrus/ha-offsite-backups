# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.7] - 2026-04-27

### Changed

- Migrate base image from Alpine to Amazon Linux 2023 (AL2023); replace
  Alpine package manager (`apk`) with `dnf`; switch runtime packages to
  AL2023 equivalents (`awscli-2`, `gnupg2`, `shadow-utils`, etc.)
- Pin `shared-github-workflows` CI ref from `@main` to `@v1`
- Bump pip minimum constraints: `cryptography>=47.0.0`,
  `jaraco-context>=6.1.2`, `wheel>=0.47.0`, `zipp>=3.23.1`
- Switch Dependabot schedule from weekly to daily so updates appear before
  a release rather than forcing a patch bump on top of a freshly tagged main

## [1.0.0] - 2026-03-23

### Added
- Initial release

[Unreleased]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.0.7...HEAD
[1.0.7]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.0.6...v1.0.7
[1.0.0]: https://github.com/1121citrus/ha-offsite-backups/releases/tag/1.0.0
