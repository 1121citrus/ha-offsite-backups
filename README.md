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
[INFO] entering scheduler mode (*/1 * * * *)
[INFO] wrote env file /home/ha-offsite-backups/.env
[INFO] export AWS_CONFIG_FILE=/run/secrets/aws-config
[INFO] export AWS_EXTRA_ARGS=''
[INFO] export BACKUP_DIR=/backups
[INFO] export BUCKET=backup-bucket
[INFO] export DEBUG=false
[INFO] export DRYRUN=false
[INFO] unset CRON_EXPRESSION
[INFO] installing cron entry: */1 * * * * /usr/local/bin/ha-offsite-backups
[INFO] crontab: */1 * * * * /usr/local/bin/ha-offsite-backups
[INFO] handing off to supercronic
time="2025-07-12T12:57:16Z" level=info msg="read crontab: /var/spool/cron/crontabs/ha-offsite-backups"
time="2025-07-16T04:15:00Z" level=info msg=starting iteration=0 job.command=/usr/local/bin/ha-offsite-backups job.position=0 job.schedule="*/1 * * * *"
time="2025-07-16T04:15:00Z" level=info msg="[INFO] begin sync from '/backups' to 's3://backup-bucket'" channel=stderr iteration=0 job.command=/usr/local/bin/ha-offsite-backups job.position=0 job.schedule="*/1 * * * *"
time="2025-07-16T04:15:00Z" level=info msg="[INFO] begin sync '/backups' to 's3://backup-bucket'" channel=stderr iteration=0 job.command=/usr/local/bin/ha-offsite-backups job.position=0 job.schedule="*/1 * * * *"
time="2025-07-16T04:15:00Z" level=info msg="[INFO] renaming 'Automatic_backup_2025.6.3_2025-07-15_09.10_35433883.tar' → '20250715T091035-home-assistant-automatic-backup-2025.6.3.tar'" channel=stderr iteration=0 job.command=/usr/local/bin/ha-offsite-backups job.position=0 job.schedule="*/1 * * * *"
time="2025-07-16T04:15:00Z" level=info msg="[INFO] renaming 'Automatic_backup_2025.6.3_2025-07-15_05.30_43004208.tar' → '20250715T053043-home-assistant-automatic-backup-2025.6.3.tar'" channel=stderr iteration=0 job.command=/usr/local/bin/ha-offsite-backups job.position=0 job.schedule="*/1 * * * *"
time="2025-07-16T04:15:00Z" level=info msg="[INFO] renaming 'Automatic_backup_2025.6.3_2025-07-16_05.34_36783615.tar' → '20250716T053436-home-assistant-automatic-backup-2025.6.3.tar'" channel=stderr iteration=0 job.command=/usr/local/bin/ha-offsite-backups job.position=0 job.schedule="*/1 * * * *"
time="2025-07-16T04:15:00Z" level=info msg="[INFO] running 'aws s3 sync  /tmp/tmp.iDz9kNja24 s3://backup-bucket'" channel=stderr iteration=0 job.command=/usr/local/bin/ha-offsite-backups job.position=0 job.schedule="*/1 * * * *"
time="2025-07-16T04:15:01Z" level=info msg="[INFO] upload: tmp/tmp.iDz9kNja24/20250716T053436-home-assistant-automatic-backup-2025.6.3.tar to s3://backup-bucket/20250716T053436-home-assistant-automatic-backup-2025.6.3.tar" channel=stderr iteration=0 job.command=/usr/local/bin/ha-offsite-backups job.position=0 job.schedule="*/1 * * * *"
time="2025-07-16T04:15:01Z" level=info msg="[INFO] Completed 1 file(s) with 2 file(s) remaining\rupload: tmp/tmp.iDz9kNja24/20250715T091035-home-assistant-automatic-backup-2025.6.3.tar to s3://backup-bucket/20250715T091035-home-assistant-automatic-backup-2025.6.3.tar" channel=stderr iteration=0 job.command=/usr/local/bin/ha-offsite-backups job.position=0 job.schedule="*/1 * * * *"
time="2025-07-16T04:15:01Z" level=info msg="[INFO] Completed 2 file(s) with 1 file(s) remaining\rupload: tmp/tmp.iDz9kNja24/20250715T053043-home-assistant-automatic-backup-2025.6.3.tar to s3://backup-bucket/20250715T053043-home-assistant-automatic-backup-2025.6.3.tar" channel=stderr iteration=0 job.command=/usr/local/bin/ha-offsite-backups job.position=0 job.schedule="*/1 * * * *"
time="2025-07-16T04:15:01Z" level=info msg="[INFO] finish sync '/backups' to 's3://backup-bucket'" channel=stderr iteration=0 job.command=/usr/local/bin/ha-offsite-backups job.position=0 job.schedule="*/1 * * * *"
time="2025-07-16T04:15:01Z" level=info msg="[INFO] completed sync from '/backups' to 's3://backup-bucket'" channel=stderr iteration=0 job.command=/usr/local/bin/ha-offsite-backups job.position=0 job.schedule="*/1 * * * *"
time="2025-07-16T04:15:01Z" level=info msg="job succeeded" iteration=0 job.command=/usr/local/bin/ha-offsite-backups job.position=0 job.schedule="*/1 * * * *"
```

## Configuration

Variable | Default | Notes
--- | --- | ---
`AWS_CONFIG_FILE` | `/run/secrets/aws-config` | The externally provided AWS configuration file containing credentials, etc. This is intended to be a Docker [secret](https://docs.docker.com/compose/how-tos/use-secrets/) but could also be a bind mount.
`AWS_S3_BUCKET_NAME` |  | Required parameter. The backup files will be uploaded to this S3 bucket. You may include slashes after the bucket name if you want to upload into a specific path within the bucket, e.g. `your-bucket-name/backups/daily` (without trailing forward slash (`/`)).
`BACKUP_DIR` | `/backups` | Where to look for the HA backup files.
`CRON_EXPRESSION` | `@daily` | Busybox `crond` expression for when the backup should run. Use e.g. `0 4 * * *` to back up at 4 AM every night. See [crontab.guru](https://crontab.guru/) for more. Note: busybox `crond` syntax differs slightly from Vixie cron.
`DEBUG` | `false` | Set to `true` to enable `xtrace` and `verbose` shell options.
`DRYRUN` | `true` | Set to `false` to enable live uploads to S3.
`TZ` | `UTC` | Which timezone should `cron` use, e.g. `America/New_York` or `Europe/Warsaw`. See [full list of available time zones](http://manpages.ubuntu.com/manpages/bionic/man3/DateTime::TimeZone::Catalog.3pm.html).

## Testing

Run the automated bats suite (requires Docker):

```bash
test/run-all
```

Run final production-equivalent staging integration tests against a built image:

```bash
test/staging 1121citrus/ha-offsite-backups:dev-<sha>
```

For staging runs that exercise AWS connectivity and scheduler behavior:

```bash
test/staging --bucket test.staging.ha-offsite-backups \
    --aws-config ~/.secrets/aws-config \
    --aws-credentials ~/.secrets/aws-credentials \
    1121citrus/ha-offsite-backups:dev-<sha>
```

Skip the Trivy scan and advisory scans for fast local iteration:

```bash
test/staging --no-scan 1121citrus/ha-offsite-backups:dev-<sha>
```

Run a specific advisory scan after skipping the Trivy gate:

```bash
test/staging --no-scan --advise grype 1121citrus/ha-offsite-backups:dev-<sha>
```

Automated bats tests cover shell logic and mocked AWS paths. `test/staging`
validates the built image end-to-end in a production-equivalent staging setup.

## Building

The `build` script runs all stages in order — lint, build, test, smoke, scan,
and advisory scans (Grype, Scout, Dive, and coverage via kcov):

```bash
./build
```

Skip the slower advisory scans during development:

```bash
./build --no-scan --no-coverage
```

Run only the Grype and coverage advisories:

```bash
./build --advise grype,coverage
```

To tag and push a release to Docker Hub (multi-platform `linux/amd64` + `linux/arm64`):

```bash
./build --push --version 1.2.3
```

Run `./build --help` for the full list of flags.
