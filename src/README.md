# src — ha-offsite-backups source

Scripts and libraries installed into the container image.

## File inventory

| Path | Installed to | Role |
| --- | --- | --- |
| `ha-offsite-backups` | `/usr/local/bin/ha-offsite-backups` | Primary sync script — renames HA backups to ISO datetime form and syncs to S3 |
| `startup` | `/usr/local/bin/startup` | Compatibility shim — execs `ha-offsite-backups --cron` for legacy deployments |
| `healthcheck` | `/usr/local/bin/healthcheck` | Docker `HEALTHCHECK` — verifies `crond` is running and the crontab is configured |
| `include/common-functions` | `/usr/local/include/common-functions` | Shared utility functions sourced by all scripts |

## `ha-offsite-backups`

Scans the Home Assistant backup directory for files matching
`Automatic_backup_<release>_YYYY-MM-DD_HH.MM_NN.tar`, transforms
each filename to compact ISO datetime form
(`YYYYMMDDTHHMMSS-home-assistant-automatic-backup-<release>.tar`), and syncs
the renamed files to an S3 bucket.

### Key environment variables

| Variable | Purpose |
| --- | --- |
| `BACKUP_DIR` | Path to the HA backup directory (default: `/backups`) |
| `AWS_CONFIG_FILE` | AWS config file path (default: `/run/secrets/aws-config`) |
| `AWS_SHARED_CREDENTIALS_FILE` | AWS credentials file path (optional; supplements `AWS_CONFIG_FILE`) |
| `AWS_S3_BUCKET_NAME` | Destination S3 bucket (also accepts `HA_OFFSITE_BACKUPS_AWS_S3_BUCKET_NAME`) |
| `CRON_EXPRESSION` | Schedule for scheduler mode (default: `@daily`) |
| `DRYRUN` | Dry-run mode — no uploads (default: `true`) |
| `DEBUG` | Enable `set -x` trace logging (default: `false`) |

### Filename transformation

HA names backup files with a date-only prefix (`YYYY_MM_DD`) that makes
lexicographic sorting ambiguous when multiple backups exist for the same day.
The script transforms these to an ISO 8601 datetime filename using the file's
modification timestamp, so backups sort chronologically and unambiguously.

The transformation logic is tested in `test/02-ha-offsite-backups.bats`.

### AWS credentials

Credentials are supplied via one or both of two file paths:

- `AWS_CONFIG_FILE` — typically a Docker secret (`/run/secrets/aws-config`);
  contains the `[default]` profile with region, output format, and optionally
  inline credentials.
- `AWS_SHARED_CREDENTIALS_FILE` — optional separate credentials file
  (`/run/secrets/aws-credentials`); takes precedence over inline credentials in
  the config file when present.

Using files rather than environment variables avoids exposing credentials to all
processes in the container.  The AWS CLI automatically retries transient S3
failures with `AWS_RETRY_MODE=standard` and `AWS_MAX_ATTEMPTS=5`.

## `startup`

Compatibility shim retained for deployments that set
`entrypoint: /usr/local/bin/startup`.  Execs
`ha-offsite-backups --cron "$@"` and inherits its exit status.  New
deployments should invoke `ha-offsite-backups --cron` directly.

## `healthcheck`

Checks three conditions:

1. The crontab at `/var/spool/cron/crontabs/ha-offsite-backups` contains an
   `ha-offsite-backups` entry
2. `supercronic` is running (`pgrep -x supercronic`)
3. The success marker file (`/tmp/.ha-offsite-backups-success`) was updated
   within the last hour, confirming that the most recent cron job completed

## `include/common-functions`

Shared library sourced by the above scripts.  Provides `is-true`, `is-false`,
`log`, and other small helpers.  Installed to a non-`bin` path so it is not
accidentally invoked directly.
