#!/usr/bin/env bats
# shellcheck shell=bash

load "test_helper"

setup() {
    repo_root=$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)
    export PATH="$repo_root/src:$PATH"
    TEST_TMPDIR=$(mktemp -d)
    export TEST_TMPDIR
    export INCLUDE_DIR="$repo_root/src/include"
    export AWS_CMD=echo
    export VERSION_FILE="$TEST_TMPDIR/version"
    echo "1.2.3" > "$VERSION_FILE"

    mkdir -p /var/spool/cron/crontabs

    # pgrep stub: simulate supercronic running (exit 0 always).
    STUB_DIR="${TEST_TMPDIR}/stubs"
    mkdir -p "${STUB_DIR}"
    printf '#!/bin/sh\nexec /bin/true\n' > "${STUB_DIR}/pgrep"
    chmod +x "${STUB_DIR}/pgrep"
    export STUB_DIR
}

teardown() {
    rm -rf "$TEST_TMPDIR"
    rm -f /var/spool/cron/crontabs/ha-offsite-backups
}

@test "missing bucket exits non-zero" {
    run bash "$repo_root/src/ha-offsite-backups"
    [ "$status" -ne 0 ]
    [[ "$output" == *"need to specify BUCKET"* ]]
}

@test "unknown option exits non-zero" {
    run bash "$repo_root/src/ha-offsite-backups" --notarealflag
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown option"* ]]
}

@test "unexpected argument exits non-zero" {
    run bash "$repo_root/src/ha-offsite-backups" foo
    [ "$status" -ne 0 ]
    [[ "$output" == *"unexpected argument"* ]]
}

# ── src/healthcheck ───────────────────────────────────────────────────────────

@test "healthcheck: exits 0 when crontab ok, supercronic mocked, fresh marker" {
    printf '%s\n' '@daily /usr/local/bin/ha-offsite-backups' \
        > /var/spool/cron/crontabs/ha-offsite-backups
    marker="${TEST_TMPDIR}/marker"
    touch "${marker}"
    run env \
        DEBUG=true \
        ENV=/dev/null \
        COMMON_FUNCTIONS_FILE="${INCLUDE_DIR}/common-functions" \
        PATH="${STUB_DIR}:${PATH}" \
        HEALTHCHECK_SUCCESS_FILE="${marker}" \
        bash "${repo_root}/src/healthcheck"
    [ "$status" -eq 0 ]
}

@test "healthcheck: exits non-zero when crontab is not configured" {
    rm -f /var/spool/cron/crontabs/ha-offsite-backups
    run env \
        DEBUG=true \
        ENV=/dev/null \
        COMMON_FUNCTIONS_FILE="${INCLUDE_DIR}/common-functions" \
        PATH="${STUB_DIR}:${PATH}" \
        HEALTHCHECK_SUCCESS_FILE="${TEST_TMPDIR}/marker" \
        bash "${repo_root}/src/healthcheck"
    [ "$status" -ne 0 ]
    [[ "$output" == *"crontab is not configured"* ]]
}

@test "healthcheck: exits non-zero when supercronic is not running" {
    printf '%s\n' '@daily /usr/local/bin/ha-offsite-backups' \
        > /var/spool/cron/crontabs/ha-offsite-backups
    # Omit STUB_DIR from PATH so real pgrep finds no supercronic process.
    run env \
        DEBUG=true \
        ENV=/dev/null \
        COMMON_FUNCTIONS_FILE="${INCLUDE_DIR}/common-functions" \
        HEALTHCHECK_SUCCESS_FILE="${TEST_TMPDIR}/marker" \
        bash "${repo_root}/src/healthcheck"
    [ "$status" -ne 0 ]
    [[ "$output" == *"supercronic is not running"* ]]
}

@test "healthcheck: exits non-zero when backup has not run (no marker)" {
    printf '%s\n' '@daily /usr/local/bin/ha-offsite-backups' \
        > /var/spool/cron/crontabs/ha-offsite-backups
    run env \
        DEBUG=true \
        ENV=/dev/null \
        COMMON_FUNCTIONS_FILE="${INCLUDE_DIR}/common-functions" \
        PATH="${STUB_DIR}:${PATH}" \
        HEALTHCHECK_SUCCESS_FILE="${TEST_TMPDIR}/nonexistent-marker" \
        bash "${repo_root}/src/healthcheck"
    [ "$status" -ne 0 ]
    [[ "$output" == *"backup has not run recently"* ]]
}

@test "healthcheck: exits non-zero when marker is stale" {
    printf '%s\n' '@daily /usr/local/bin/ha-offsite-backups' \
        > /var/spool/cron/crontabs/ha-offsite-backups
    marker="${TEST_TMPDIR}/marker"
    touch -t 200001010000.00 "${marker}"
    run env \
        DEBUG=true \
        ENV=/dev/null \
        COMMON_FUNCTIONS_FILE="${INCLUDE_DIR}/common-functions" \
        PATH="${STUB_DIR}:${PATH}" \
        HEALTHCHECK_SUCCESS_FILE="${marker}" \
        bash "${repo_root}/src/healthcheck"
    [ "$status" -ne 0 ]
    [[ "$output" == *"backup has not run recently"* ]]
}
