#!/usr/bin/env bats

load "test_helper"

setup() {
    repo_root=$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)
    export PATH="$repo_root/src:$PATH"
    export TEST_TMPDIR=$(mktemp -d)
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "healthcheck: healthy path" {
    # Simulate crontab and supercronic running
    touch "$TEST_TMPDIR/cronjob_ran"
    export CRONJOB_RUN_MARKER="$TEST_TMPDIR/cronjob_ran"
    mkdir -p /var/spool/cron/crontabs
    echo '/usr/local/bin/ha-offsite-backups' | tee /var/spool/cron/crontabs/ha-offsite-backups > /dev/null
    # Mock pgrep to always succeed for supercronic
    PATH_ORIG="$PATH"
    echo -e '#!/bin/sh\nexit 0' > "$TEST_TMPDIR/pgrep"
    chmod +x "$TEST_TMPDIR/pgrep"
    export PATH="$TEST_TMPDIR:$PATH"
    run env HOME="$TEST_TMPDIR" PATH="$PATH" bash "$repo_root/src/healthcheck"
    export PATH="$PATH_ORIG"
    rm -f /var/spool/cron/crontabs/ha-offsite-backups
    [ "$status" -eq 0 ]
}

@test "healthcheck: missing crontab" {
    export CRONTAB_CONFIGURED=0
    run bash "$repo_root/src/healthcheck"
    [ "$status" -ne 0 ]
}

@test "healthcheck: scheduler not running" {
    export SCHEDULER_RUNNING=0
    run bash "$repo_root/src/healthcheck"
    [ "$status" -ne 0 ]
}

@test "healthcheck: cronjob not run" {
    export CRONJOB_RUN_MARKER="$TEST_TMPDIR/cronjob_ran"
    rm -f "$TEST_TMPDIR/cronjob_ran"
    run bash "$repo_root/src/healthcheck"
    [ "$status" -ne 0 ]
}
