#!/usr/bin/env bats

load "test_helper"

setup() {
    repo_root=$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)
    export PATH="$repo_root/src:$PATH"
    TEST_TMPDIR=$(mktemp -d)
    export TEST_TMPDIR
    export HEALTHCHECK_SUCCESS_FILE="$TEST_TMPDIR/success"
    export HEALTHCHECK_STARTUP_FILE="$TEST_TMPDIR/started"
    mkdir -p /var/spool/cron/crontabs
    echo '/usr/local/bin/ha-offsite-backups' | tee /var/spool/cron/crontabs/ha-offsite-backups > /dev/null

    # Mock pgrep to always report supercronic running.
    echo -e '#!/bin/sh\nexit 0' > "$TEST_TMPDIR/pgrep"
    chmod +x "$TEST_TMPDIR/pgrep"
    export PATH="$TEST_TMPDIR:$PATH"
}

teardown() {
    rm -f /var/spool/cron/crontabs/ha-offsite-backups
    rm -rf "$TEST_TMPDIR"
}

@test "healthcheck: healthy when success marker is fresh" {
    touch "$HEALTHCHECK_SUCCESS_FILE"
    run env HOME="$TEST_TMPDIR" PATH="$PATH" bash "$repo_root/src/healthcheck"
    [ "$status" -eq 0 ]
}

@test "healthcheck: missing crontab" {
    rm -f /var/spool/cron/crontabs/ha-offsite-backups
    run env HOME="$TEST_TMPDIR" PATH="$PATH" bash "$repo_root/src/healthcheck"
    [ "$status" -ne 0 ]
}

@test "healthcheck: scheduler not running" {
    echo -e '#!/bin/sh\nexit 1' > "$TEST_TMPDIR/pgrep"
    chmod +x "$TEST_TMPDIR/pgrep"
    run env HOME="$TEST_TMPDIR" PATH="$PATH" bash "$repo_root/src/healthcheck"
    [ "$status" -ne 0 ]
}

@test "healthcheck: unhealthy with no success marker and no startup marker" {
    run env HOME="$TEST_TMPDIR" PATH="$PATH" bash "$repo_root/src/healthcheck"
    [ "$status" -ne 0 ]
}

@test "healthcheck: unhealthy when success marker is older than HEALTHCHECK_MAX_AGE_SECONDS" {
    touch -d '@0' "$HEALTHCHECK_SUCCESS_FILE"
    run env HOME="$TEST_TMPDIR" PATH="$PATH" HEALTHCHECK_MAX_AGE_SECONDS=60 \
        bash "$repo_root/src/healthcheck"
    [ "$status" -ne 0 ]
}

@test "healthcheck: healthy on a two-hour-old success marker under the default HEALTHCHECK_MAX_AGE_SECONDS" {
    # Regression test: the default freshness window used to be a
    # hardcoded 3600s, incompatible with schedules coarser than hourly
    # (production runs every 8-24 hours). A marker older than one hour
    # but within the default 48h window must still pass.
    touch -d "@$(( $(date +%s) - 7200 ))" "$HEALTHCHECK_SUCCESS_FILE"
    run env HOME="$TEST_TMPDIR" PATH="$PATH" bash "$repo_root/src/healthcheck"
    [ "$status" -eq 0 ]
}

@test "healthcheck: healthy within startup grace period despite no success marker" {
    touch "$HEALTHCHECK_STARTUP_FILE"
    run env HOME="$TEST_TMPDIR" PATH="$PATH" bash "$repo_root/src/healthcheck"
    [ "$status" -eq 0 ]
}

@test "healthcheck: unhealthy once startup grace period is exceeded with no success marker" {
    touch -d '@0' "$HEALTHCHECK_STARTUP_FILE"
    run env HOME="$TEST_TMPDIR" PATH="$PATH" HEALTHCHECK_STARTUP_GRACE_SECONDS=60 \
        bash "$repo_root/src/healthcheck"
    [ "$status" -ne 0 ]
}
