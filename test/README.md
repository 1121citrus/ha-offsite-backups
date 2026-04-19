# test — ha-offsite-backups test suite

Tests for `ha-offsite-backups`.  Bats-based tests run inside the official
`bats/bats:latest` Docker container with the project source bind-mounted.
No application image is required for the automated tests.

## Running

```sh
# Via the build script (recommended — also lints, builds, and scans):
./build

# Tests only (no image needed):
test/run-all
```

`test/run-all` starts a bats container with the source tree mounted and runs
all `.bats` files under `test/`.

## Automated test files

| File | What it tests |
| --- | --- |
| `00-noop.bats` | Sanity check — always passes; validates the bats harness itself |
| `01-dockerfile.bats` | `Dockerfile` structure: labels, `ENTRYPOINT`, `HEALTHCHECK`, and build args |
| `02-ha-offsite-backups.bats` | Core script logic: filename transformation, argument parsing, S3 sync pipeline |
| `03-build.bats` | `build` script option parsing, advisory flags, cache control, and stage control |
| `04-image-metadata.bats` | Image metadata: version label, entrypoint form, and installed file paths |
| `05-common-functions.bats` | Shared library (`include/common-functions`): logging, guards, and helpers |
| `06-healthcheck.bats` | `healthcheck` script: crontab presence, `supercronic` process, and marker file age |
| `07-ha-offsite-backups-coverage.bats` | Coverage-specific edge cases exercised by kcov instrumentation |

## Design notes

- The automated tests do **not** require the application image.  They bind-mount
  the project source into the bats container and test the shell logic directly.
- CI also runs one image-level smoke test after `build` in
  `.github/workflows/ci.yml`.  That smoke test executes the built image
  artifact to catch packaging/runtime regressions that source-mounted tests
  cannot detect.
- `02-ha-offsite-backups.bats` includes purely functional filename-transform
  tests: known HA backup name inputs are asserted to produce the expected
  ISO datetime canonical output.
- CI runs `docker run -i` (without `-t`) because a TTY is not available in
  GitHub Actions.  The local `test/run-all` uses `-it` for a nicer terminal
  experience.  See `.github/CI-WORKFLOWS.md` for details.

## test/staging

`test/staging` is the final integration test command for a production-equivalent
staging environment. It runs the built image end-to-end against real runtime
inputs and optionally against real AWS infrastructure.

The command is intentionally separate from `test/run-all` and CI bats tests.
It is meant for pre-release validation and staging sign-off.

### Usage

```sh
# Image and packaging validation only (no AWS bucket required):
test/staging 1121citrus/ha-offsite-backups:dev-<sha>

# Skip Trivy scan and advisory scans for fast local iteration:
test/staging --no-scan 1121citrus/ha-offsite-backups:dev-<sha>

# Production-equivalent staging run (safe default DRYRUN=true):
test/staging --bucket test.staging.ha-offsite-backups \
    --aws-config ~/.secrets/aws-config \
    --aws-credentials ~/.secrets/aws-credentials \
    1121citrus/ha-offsite-backups:dev-<sha>

# Run Grype advisory scan after skipping the Trivy gate:
test/staging --no-scan --advise grype \
    1121citrus/ha-offsite-backups:dev-<sha>

# Run kcov coverage analysis only:
test/staging --no-scan --advise coverage \
    1121citrus/ha-offsite-backups:dev-<sha>

# Reset scanner DB caches before running advisory scans:
test/staging --cache 'reset=all' --advise grype \
    1121citrus/ha-offsite-backups:dev-<sha>

# Skip Grype DB network update (use cached DB as-is):
test/staging --cache 'skip-update=grype' --advise grype \
    1121citrus/ha-offsite-backups:dev-<sha>

# Run one specific staging test:
test/staging --test test_staging_cron_fires \
    --bucket test.staging.ha-offsite-backups \
    1121citrus/ha-offsite-backups:dev-<sha>
```

### What it validates

- Required runtime binaries and scripts exist in the built image.
- Filename canonicalization works with known Home Assistant backup input.
- One-shot sync path succeeds and logs canonicalized object names.
- Scheduler mode (`crond`) fires and completes a full sync cycle.
- Image security checks: Trivy HIGH/CRITICAL gating scan plus optional
  advisory scans (Grype, Docker Scout, Dive, and kcov coverage).

### Advisory scans

Advisory scans (`--advise`) are off by default.  They never fail the test run:

| Flag | What it runs |
| --- | --- |
| `--advise coverage` | kcov bash line-coverage report (via `1121citrus/bats-kcov`) |
| `--advise grype` | Grype full-severity CVE scan |
| `--advise scout` | Docker Scout CVE scan |
| `--advise dive` | Dive image layer analysis |
| `--advise all` | All four of the above |
| `--no-coverage` | Suppress the coverage advisement only |
| `--no-advise` | Suppress all advisory scans |
| `--cache CACHE_RULES` | One-run cache controls for scanner DBs (e.g. `reset=all`, `skip-update=grype`) |

### Safety behavior

- AWS-dependent tests are skipped when bucket/credentials are missing.
- For bucket names not starting with `test.` or `staging.`, DRYRUN is forced
  to `true` unless explicitly overridden with `--no-dryrun`.
- A confirmation prompt appears before running AWS-touching tests unless
  `--yes` is provided.
- AWS credentials are copied to world-readable temp files for the duration of
  the run so the non-root container user (UID 10001) can read them; the copies
  are deleted on exit.
