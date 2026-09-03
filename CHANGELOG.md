# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.7] - 2026-09-03

### Changed

- Updated `cryptography` to `>=50.0.1` and `wheel` to `>=0.48.0`.

### Fixed

- Resynchronized `.trivyignore` with the refreshed `aws-backup-base`
  1.2.1 image, removing resolved AL2023 findings and retaining only
  `CVE-2026-14456`, which has no available AL2023 package fix.
- Verified the image build and gating Trivy scan pass against
  `aws-backup-base:1.2.1`.

## [1.1.6] - 2026-07-24

### Fixed

- Actually release the `CRON_EXPRESSION` environment-variable scheduler-mode
  fallback that has been present and tested in `src/ha-offsite-backups`
  (`_cron_expression_from_env`, `test/02-ha-offsite-backups.bats`: "CRON_EXPRESSION
  env var implies scheduler mode") since a prior scaffold-generated commit,
  but was never actually shipped: the `1121citrus/ha-offsite-backups:1.1.5`
  image published to the registry was built from a commit that predates
  this fix and no longer exists anywhere in this repository's history (its
  baked-in `GIT_COMMIT` does not resolve even after a full fetch) -- the
  `v1.1.5` git tag was evidently moved forward at some point after that
  image was built and published, without a corresponding rebuild/republish.
  `Dockerfile`'s `ENTRYPOINT` calls `ha-offsite-backups` directly (not
  `src/startup`, which always forces `--cron` and would break the
  documented one-shot CLI-mode usage), so a container relying solely on
  `CRON_EXPRESSION` in its environment -- as every compose caller in the
  1121-citrus fleet does, none of them pass `--cron` explicitly -- fell
  back to CLI mode with no fallback in the actually-published image:
  it ran one sync and exited immediately.  Combined with `restart:
  unless-stopped`, this manifested as a continuous restart loop rather
  than a resident scheduler -- confirmed live on citrus-2's
  `home-assistant-backup` service today: each cycle's sync succeeded
  (real data reached S3), but the container never settled into a
  steady running state and racked up dozens of restarts within minutes.
  No source change was needed -- `version.txt` bump and this entry are
  the actual fix, so the next image build carries the code that was
  already sitting untested-in-production on `dev`/`staging`.

## [1.1.5] - 2026-07-21

### Fixed

- `src/healthcheck`: replaced the hardcoded one-hour success-marker
  freshness window with a configurable `HEALTHCHECK_MAX_AGE_SECONDS`
  (default 48 hours), and added a short startup-grace check
  (`HEALTHCHECK_STARTUP_FILE`/`HEALTHCHECK_STARTUP_GRACE_SECONDS`,
  default 900s) for the gap before the first real run completes.
  Previously any schedule coarser than hourly (this image's actual
  production default is every 15 minutes, but `rotate-backups`'
  every-8-hours and `docs-rotate`'s daily schedule in the same fleet
  hit the identical bug) made the container flip `unhealthy` between
  successful runs — confirmed live on citrus-2, where three sibling
  backup/rotate containers across two apps sat unhealthy for 9+ hours
  despite working correctly.
- `src/ha-offsite-backups`'s `run_scheduler()`: touches the startup
  marker immediately on entering scheduler mode, and runs one real
  sync immediately after installing the crontab but before handing off
  to `supercronic`, so a freshly deployed container gets a genuine
  success marker within minutes instead of waiting for the first
  scheduled run — which could be hours away. A failed immediate run is
  logged but does not block the scheduler hand-off.
- `test/06-healthcheck.bats`: fixed tests referencing a stale
  `CRONJOB_RUN_MARKER` env var that the script has never actually read
  (it reads `HEALTHCHECK_SUCCESS_FILE`); the "healthy path" test was
  silently failing on `dev` before this fix.

## [1.1.4] - 2026-07-12

### Fixed

- Grant `permissions.contents: write` in `.github/workflows/ci.yml` so
  `shared-github-workflows/.github/workflows/pipeline.yml@v1` validates
  successfully; this resolves GitHub Actions `startup_failure` caused by
  insufficient caller permissions for the reusable workflow's `promote`
  job declaration.

## [1.1.3] - 2026-07-12

### Changed

- Regenerate `test/run-all` under generator control and update CI caller
  workflow wiring to the shared `pipeline.yml@v1` template.
- Canonicalize shared shell helpers under `include/common-functions` and
  keep `src/include/common-functions` as a compatibility shim.
- Update container packaging to copy `include/common-functions` into
  `/usr/local/include/common-functions`.

### Security

- Bump `cryptography` floor in `requirements.txt` from `>=48.0.1` to
  `>=49.0.0`.
- Bump `actions/checkout` in gitleaks CI workflow from `v6.0.3` to
  `v7.0.0`.

## [1.1.2] - 2026-06-10

### Security

- Suppress gnutls CVE-2026-33845 and libsolv CVE-2026-48863,
  CVE-2026-48864, CVE-2026-9149, CVE-2026-9150 in `.trivyignore` — fix
  packages exist in Trivy DB but are not yet published to AL2023 DNF
  repositories; gnutls and libsolv added to Dockerfile `dnf install` step
  to auto-apply the fix once the repo publishes them
- Bump cryptography floor from `>=48.0.0` to `>=48.0.1` in
  `requirements.txt` (Dependabot PR #11)
- Apply actions/checkout 6.0.2→6.0.3 in CI workflows (Dependabot PR #10)

## [1.1.1] - 2026-05-23

### Security

- Clear `.trivyignore` — all previously accepted HIGH CVEs are now resolved
  by aws-backup-base v1.1.3: the AL2023 digest refresh landed package fixes
  for glibc (CVE-2026-4046), python3.12 (CVE-2026-3644, CVE-2026-4224,
  CVE-2026-4786, CVE-2026-6100), and python3.12-pip (CVE-2026-3219,
  CVE-2026-6357); supercronic is now compiled from source with
  `golang:1.26.3-alpine`, resolving CVE-2026-33811, CVE-2026-33814,
  CVE-2026-39820, CVE-2026-39836, and CVE-2026-42499
- Update `SECURITY.md` to reflect zero open HIGH/CRITICAL CVEs and move all
  previously accepted CVEs to the remediated table

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

[Unreleased]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.1.4...HEAD
[1.1.4]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.0.9...v1.1.0
[1.0.9]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.0.8...v1.0.9
[1.0.8]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/1121citrus/ha-offsite-backups/compare/v1.0.6...v1.0.7
[1.0.0]: https://github.com/1121citrus/ha-offsite-backups/releases/tag/1.0.0
