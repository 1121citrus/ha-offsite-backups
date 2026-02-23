# 1121citrus/ha-offsite-backups

An application specific service to rename Home Assistant backups and copy them off site.

## Contents

- [Contents](#contents)
- [Synopsis](#synopsis)
- [Overview](#overview)
- [Example](#example)
- [Configuration](#configuration)
- [Testing](#testing)
- [Building](#building)

## Synopsis
* Periodically sync Home Assistant's automated backups to off site storage (S3).
* Backup files are renamed so they sort by date.
* Credentials are supplied by a compose [secret](https://docs.docker.com/compose/how-tos/use-secrets/).

## Overview
This service will periodically scan a directory for backups created by Home Assistant's (newer) integrated automated backup and ensures that its contents are replicated to an S3 bucket. The source backup files are assumed to have names of the form used by HA: `Automatic_backup_«release»_«year»-«month»-«day»_«hour».«minute»_«nanosecond»`, i.e. `Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar`. The filenames on S3 are canonicalized: `«minimal [ISO datetime](https://www.iso.org/iso-8601-date-and-time-format.html)»-home-assistant-automatic-backup-«release»`, i.e. `20250706T053500-home-assistant-automatic-backup-2025.6.3.tar`, so that they sort by date.

## Example

```yml
services: 
  ha-offsite-backups:
    container_name: ha-offsite-backups
    image: 1121citrus/ha-offsite-backups:latest
    build:
      context: .
    restart: always
    environment:
      - AWS_S3_BUCKET_NAME=${AWS_S3_BUCKET_NAME:-backup-bucket}
      - BACKUP_DIR=${BACKUP_DIR:-/backups}
      - CRON_EXPRESSION=${CRON_EXPRESSION:-15 3 * * *}
      - TZ=${TZ:-America/New_York}
    volumes:
      - home_assistant_backups:/backups:ro
      - /etc/localtime:/etc/localtime:ro
    secrets:
      - aws-config

secrets:
  aws-config:
    file: ./aws-config
```

This service will sync HA automatic backup files from the `home_assistant_backups` volume mounted to the `/backups` directory to the
`backup-bucket` on S3.

Typical log output:

```
20250712T125716 startup [INFO] create env file /root/.env
20250712T125716 startup [INFO] mode of '/root/.env' changed to 0600 (rw-------)
20250712T125716 startup [INFO] export AWS_CONFIG_FILE='/run/secrets/aws-config'
20250712T125716 startup [INFO] export AWS_S3_BUCKET_NAME='backup-bucket'
20250712T125716 startup [INFO] export BACKUP_DIR='/backups'
20250712T125716 startup [INFO] export CRON_EXPRESSION='*/1 * * * *'
20250712T125716 startup [INFO] export DEBUG='false'
20250712T125716 startup [INFO] export DRYRUN='false'
20250712T125716 startup [INFO] installing cron.d entry: /usr/local/bin/ha-offsite-backups
20250712T125717 startup [INFO] mode of '/var/spool/cron/crontabs/root' changed to 0644 (rw-r--r--)
20250712T125717 startup [INFO] crontab: */1 * * * * /usr/local/bin/ha-offsite-backups 2>&1
20250712T125717 startup [INFO] handing the reins over to cron daemon
    .
    .
    .
20250716T041505 ha-offsite-backups [INFO] begin sync '/backups' to S3 bucket 'backup-bucket'
20250716T041505 ha-offsite-backups [INFO] sync '/backups/Automatic_backup_2025.6.3_2025-07-16_05.34_36783615.tar' with 's3://backup-bucket/20250716T053436-home-assistant-automatic-backup-2025.6.3.tar'
20250716T041505 ha-offsite-backups [INFO] sync '/backups/Automatic_backup_2025.6.3_2025-07-15_09.10_35433883.tar' with 's3://backup-bucket/20250715T091035-home-assistant-automatic-backup-2025.6.3.tar'
20250716T041505 ha-offsite-backups [INFO] sync '/backups/Automatic_backup_2025.6.3_2025-07-15_05.30_43004208.tar' with 's3://backup-bucket/20250715T053043-home-assistant-automatic-backup-2025.6.3.tar'
20250716T041505 ha-offsite-backups [INFO] running aws s3 sync --no-progress '/tmp/tmp.1234567890' s3://backup-bucket
20250716T041511 ha-offsite-backups [INFO] upload: ./20250715T053043-home-assistant-automatic-backup-2025.6.3.tar to s3://backup-bucket/20250715T053043-home-assistant-automatic-backup-2025.6.3.tar
20250716T041511 ha-offsite-backups [INFO] upload: ./20250716T053436-home-assistant-automatic-backup-2025.6.3.tar to s3://backup-bucket/20250716T053436-home-assistant-automatic-backup-2025.6.3.tar
20250716T041514 ha-offsite-backups [INFO] upload: ./20250715T091035-home-assistant-automatic-backup-2025.6.3.tar to s3://backup-bucket/20250715T091035-home-assistant-automatic-backup-2025.6.3.tar
20250716T041515 ha-offsite-backups [INFO] completed aws s3 sync --no-progress '/tmp/tmp.1234567890' s3://backup-bucket
20250716T041515 ha-offsite-backups [INFO] finish sync '/backups' to S3 bucket 'backup-bucket'
```

## Configuration

Variable | Default | Notes
--- | --- | ---
`AWS_CONFIG_FILE` | `/run/secrets/aws-config` | The externally provided AWS configuration file containing credentials, etc. This is intended to be a Docker [secret](https://docs.docker.com/compose/how-tos/use-secrets/) but could also be a bind mount.
`AWS_S3_BUCKET_NAME` |  | Required parameter. The backup files will be uploaded to this S3 bucket. You may include slashes after the bucket name if you want to upload into a specific path within the bucket, e.g. `your-bucket-name/backups/daily` (without trailing forward slash (`/`)).
`BACKUP_DIR` | `/backups` | Where to look for the HA backup files.
`CRON_EXPRESSION` | `@daily` | Busybox `crond` expression for when the backup should run. Use e.g. `0 4 * * *` to back up at 4 AM every night. See [crontab.guru](https://crontab.guru/) for more. Note: busybox `crond` syntax differs slightly from Vixie cron.
`DEBUG` | `false` | Set to `true` to enable `xtrace` and `verbose` shell options.
`DRYRUN` | `false` | Set to `true` to pass `--dryrun` to AWS CLI commands.
`TZ` | `UTC` | Which timezone should `cron` use, e.g. `America/New_York` or `Europe/Warsaw`. See [full list of available time zones](http://manpages.ubuntu.com/manpages/bionic/man3/DateTime::TimeZone::Catalog.3pm.html).

## Testing

Run the test suite (requires Docker):

```bash
test/run-all
```

Tests use [Bats](https://github.com/bats-core/bats-core) via the `bats/bats:latest` Docker image. The suite includes unit tests for filename transformation and integration tests with a mocked `aws` CLI.

## Building

1. `docker buildx build --sbom=true --provenance=true --provenance=mode=max --platform linux/amd64,linux/arm64 -t 1121citrus/ha-offsite-backups:latest -t 1121citrus/ha-offsite-backups:x.y.z --push .`
