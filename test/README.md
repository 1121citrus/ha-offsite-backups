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
| `01-build.bats` | `build` script option parsing and stage control flags |
| `02-xform.bats` | Filename transformation: converts HA backup names to ISO-datetime canonical form |
| `03-sync-mocked.bats` | Sync logic with a mocked `aws` CLI and stub filesystem |

## Design notes

- The automated tests do **not** require the application image.  They bind-mount
  the project source into the bats container and test the shell logic directly.
- CI also runs one image-level smoke test after `build` in
  `.github/workflows/ci.yml`.  That smoke test executes the built image
  artifact to catch packaging/runtime regressions that source-mounted tests
  cannot detect.
- `02-xform.bats` is purely functional: it calls the filename-transform
  function with known inputs and asserts the expected ISO datetime output.
- `03-sync-mocked.bats` stubs the `aws` CLI to verify that the correct S3
  operations are invoked without network access or real credentials.
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

# Production-equivalent staging run (safe default DRYRUN=true):
test/staging --bucket test.staging.ha-offsite-backups \
    --aws-config ~/.secrets/aws-config \
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
- Optional image security checks (Trivy gating plus advisory scans).

### Safety behavior

- AWS-dependent tests are skipped when bucket/credentials are missing.
- For bucket names not starting with `test.` or `staging.`, DRYRUN is forced
  to `true` unless explicitly overridden with `--no-dryrun`.
- A confirmation prompt appears before running AWS-touching tests unless
  `--yes` is provided.
