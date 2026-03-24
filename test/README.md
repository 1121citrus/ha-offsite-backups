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
| `test_build.bats` | `build` script option parsing and stage control flags |
| `test_sync_mocked.bats` | Sync logic with a mocked `aws` CLI and stub filesystem |
| `test_xform.bats` | Filename transformation: converts HA backup names to ISO-datetime canonical form |

## Manual staging tests

`test/staging` exercises the full image against a real Docker daemon with
optional advisory scans:

```sh
# Image smoke checks only:
test/staging --no-scan --yes 1121citrus/ha-offsite-backups:dev-abc1234

# With Trivy scan and advisory scans:
test/staging 1121citrus/ha-offsite-backups:dev-abc1234

# Specific advisements:
test/staging --advise grype,scout 1121citrus/ha-offsite-backups:dev-abc1234
```

Run `test/staging --help` for the full option list.

## Design notes

- The automated tests do **not** require the application image.  They bind-mount
  the project source into the bats container and test the shell logic directly.
- `test_xform.bats` is purely functional: it calls the filename-transform
  function with known inputs and asserts the expected ISO datetime output.
- `test_sync_mocked.bats` stubs the `aws` CLI to verify that the correct S3
  operations are invoked without network access or real credentials.
- CI runs `docker run -i` (without `-t`) because a TTY is not available in
  GitHub Actions.  The local `test/run-all` uses `-it` for a nicer terminal
  experience.  See `.github/CI-WORKFLOWS.md` for details.
