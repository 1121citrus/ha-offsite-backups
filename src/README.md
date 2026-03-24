# src — ha-offsite-backups source

Scripts and libraries installed into the container image.

## File inventory

| Path | Installed to | Role |
| --- | --- | --- |
| `ha-offsite-backups` | `/usr/local/bin/ha-offsite-backups` | Primary sync script — renames HA backups to ISO datetime form and syncs to S3 |
| `startup` | `/usr/local/bin/startup` | Container entrypoint — writes `.env`, installs crontab, execs `crond` |
| `healthcheck` | `/usr/local/bin/healthcheck` | Docker `HEALTHCHECK` — verifies `crond` is running and the crontab is configured |
| `include/common-functions` | `/usr/local/include/common-functions` | Shared utility functions sourced by all scripts |

## `ha-offsite-backups`

Watches the Home Assistant backup directory, transforms filenames from HA's
default naming scheme (`YYYY_MM_DD.tar`) to ISO datetime form
(`YYYY-MM-DDTHH-MM-SS.tar`), then syncs the renamed files to an S3 bucket.

### Key environment variables

| Variable | Purpose |
| --- | --- |
| `HA_BACKUP_DIR` | Path to the HA backup directory (bind-mounted from the host) |
| `AWS_CONFIG_FILE` | AWS credentials file (typically a Docker secret at `/run/secrets/aws-config`) |
| `AWS_S3_BUCKET` | Destination S3 bucket |
| `SYNC_DELETE` | If `true`, delete S3 objects that no longer exist locally |
| `DEBUG` | Enable `set -x` trace logging |

### Filename transformation

HA names backup files with a date-only prefix (`YYYY_MM_DD`) that makes
lexicographic sorting ambiguous when multiple backups exist for the same day.
The script transforms these to an ISO 8601 datetime filename using the file's
modification timestamp, so backups sort chronologically and unambiguously.

The transformation logic is tested independently in `test/test_xform.bats`.

### AWS credentials

Credentials are read from a file path given by `AWS_CONFIG_FILE`, which is
typically a Docker secret (`/run/secrets/aws-config`).  This avoids placing
credentials in environment variables, which are visible to all processes in the
container.

## `startup`

Container entrypoint.  Writes runtime configuration to `~/.env`, installs the
crontab, and execs `crond -l 2 -f` in the foreground.  The `.env` pattern
ensures `crond`-launched jobs inherit the full runtime configuration without
relying on `crond`'s own environment variable handling.

## `healthcheck`

Checks two conditions:

1. `crond` is running (`pidof` / `pgrep` with portability fallback)
2. The crontab contains an `ha-offsite-backups` entry

## `include/common-functions`

Shared library sourced by the above scripts.  Provides `is-true`, `is-false`,
`log`, and other small helpers.  Installed to a non-`bin` path so it is not
accidentally invoked directly.
