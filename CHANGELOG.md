# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.1] - 2026-05-23

### Changed

- Raise the minimum `zipp` requirement from `>=3.23.1` to `>=4.1.0` in
  `requirements.txt` to address the Dependabot update
- Update `SECURITY.md` remediation history to reflect the `zipp>=4.1.0`
  floor and refresh the last-updated date

## [1.1.0] - 2026-05-23

### Added

- Add advisory stages for metrics, security posture, and code churn in
  `build` (stages 5f, 5g, 5h)

### Changed

- Raise dependency floors to `cryptography>=48.0.0` and `urllib3>=2.7.0`
- Refresh `SECURITY.md` with current open/remediated vulnerability status

### Fixed

- Add newly reported HIGH CVEs to `.trivyignore` until upstream packages
  publish fixes

## [1.0.9] - 2026-05-03

### Added

- Add Gitleaks secret-scanning CI workflow (`.github/workflows/gitleaks-ci.yml`)
- Add `--advise gitleaks` option to `build` for local Gitleaks advisory scans

### Changed

- Bump tool image pins: Grype `v0.87.0` → `v0.112.0`, Hadolint `v2.12.0` →
  `v2.14.0`, Shellcheck `v0.10.0` → `v0.11.0`, Trivy `0.62.1` → `0.70.0`
- Filter Dive inefficient-file entries smaller than 1 MB from advisory output;
  threshold is configurable via `DIVE_MIN_WASTED_BYTES` (default `1000000`)

## [1.0.8] - 2026-05-01

### Fixed

- Mount `.trivyignore` into the Trivy container (`build` and
  `test/staging`) so unfixed AL2023 CVEs are suppressed correctly;
  without the mount the ignore file was silently skipped and the
  gating scan failed
- Add `.trivyignore` entries for CVE-2026-4046 (glibc) and
  CVE-2026-3644, CVE-2026-4224, CVE-2026-4786, CVE-2026-6100
  (python3/cpython) — fix versions identified by Trivy but not yet
  available in the AL2023 package repositories
- Fix SC2140 (unescaped quotes in echo) in `test/staging`
- Convert hard `s3:CreateBucket` failure in `test_staging_sync_e2e`
  to a skip when the permission is unavailable

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

[Unreleased]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.0.9...v1.1.0
[1.0.9]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.0.8...v1.0.9
[1.0.8]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.0.6...v1.0.7
[1.0.0]: https://github.com/1121citrus/ha-offsite-backups/releases/tag/1.0.0
