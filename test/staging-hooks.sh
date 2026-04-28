#!/usr/bin/env bash
# shellcheck shell=bash

# test/staging-hooks.sh — repo-specific helpers and test implementations
# for the ha-offsite-backups staging harness (test/staging).
#
# Called by: test/staging (generated) via `source staging-hooks.sh`
# Provides:  setup_hooks() — docker-run helpers
#            test_staging_* — repo-specific test functions
#
# The generated test/staging provides: scan/advise tests, setup(), run_tests(),
# main(). This file provides only what is repo-specific.

# ---------------------------------------------------------------------------
# setup_hooks — defines docker-run helpers used by test functions.
# Called by setup() in the generated harness after credentials are ready.
# Exported env vars from setup(): _aws_cfg_mount, _aws_creds_mount, _scan_tar
# ---------------------------------------------------------------------------
setup_hooks() {
    # Run ha-offsite-backups with staging credentials and the given CLI args.
    # Set _backup_dir before calling to mount a local directory at /backups.
    run_ha_offsite_backups() {
        local args=()
        _append_aws_mounts args
        [[ -n "${_backup_dir:-}" ]] && args+=(-v "${_backup_dir}:/backups:ro")
        # shellcheck disable=SC2086
        docker run --rm ${DOCKER_RUN_ARGS:-} \
            -e "HA_OFFSITE_BACKUPS_AWS_S3_BUCKET_NAME=${S3_BUCKET_NAME:-}" \
            -e "DRYRUN=${DRYRUN:-true}" \
            "${args[@]}" \
            "${IMAGE}" "$@" 2>&1
    }

    # Start the full service container (scheduler mode) detached.
    # Prints the container ID to stdout; caller is responsible for stop/rm.
    run_service_detached() {
        local args=()
        _append_aws_mounts args
        # shellcheck disable=SC2086
        docker run -d ${DOCKER_RUN_ARGS:-} \
            -e "HA_OFFSITE_BACKUPS_AWS_S3_BUCKET_NAME=${S3_BUCKET_NAME:-}" \
            -e "DRYRUN=${DRYRUN:-true}" \
            "${args[@]}" \
            "$@" \
            "${IMAGE}"
    }

    # Run an aws CLI command inside the image, bypassing the entrypoint.
    # Used for bucket setup/teardown in test_staging_sync_e2e.
    _aws() {
        local args=()
        _append_aws_mounts args
        # shellcheck disable=SC2086
        docker run --rm --entrypoint /usr/bin/aws \
            ${DOCKER_RUN_ARGS:-} \
            "${args[@]}" \
            -e "AWS_RETRY_MODE=standard" \
            -e "AWS_MAX_ATTEMPTS=5" \
            "${IMAGE}" "$@"
    }

    export -f _aws run_ha_offsite_backups run_service_detached
}

# ---------------------------------------------------------------------------
# CLI / smoke tests (no AWS required)
# ---------------------------------------------------------------------------

test_staging_help() {
    local output result=0
    output=$(run_ha_offsite_backups --help 2>&1) || result=$?
    if [[ ${result} -eq 0 ]] && echo "${output}" | grep -q 'Usage:'; then
        echo "PASS '${FUNCNAME[0]}': --help exits 0 and prints usage"
    else
        echo "FAIL '${FUNCNAME[0]}': --help failed (exit=${result})"
        return 1
    fi
}

test_staging_version() {
    local output result=0
    output=$(run_ha_offsite_backups --version 2>&1) || result=$?
    if [[ ${result} -eq 0 ]] && [[ -n "${output}" ]]; then
        echo "PASS '${FUNCNAME[0]}': --version exits 0 and prints: ${output}"
    else
        echo "FAIL '${FUNCNAME[0]}': --version failed (exit=${result})"
        return 1
    fi
}

test_staging_unknown_option() {
    local result=0
    run_ha_offsite_backups --no-such-option > /dev/null 2>&1 || result=$?
    if [[ ${result} -ne 0 ]]; then
        echo "PASS '${FUNCNAME[0]}': exits non-zero for unknown option"
    else
        echo "FAIL '${FUNCNAME[0]}': should have exited non-zero for unknown option"
        return 1
    fi
}

test_staging_no_bucket_cli_mode() {
    local result=0
    docker run --rm "${IMAGE}" > /dev/null 2>&1 || result=$?
    if [[ ${result} -ne 0 ]]; then
        echo "PASS '${FUNCNAME[0]}': CLI mode without bucket exits non-zero"
    else
        echo "FAIL '${FUNCNAME[0]}': should have exited non-zero without bucket"
        return 1
    fi
}

test_staging_cron_no_bucket() {
    local result=0
    docker run --rm "${IMAGE}" --cron > /dev/null 2>&1 || result=$?
    if [[ ${result} -ne 0 ]]; then
        echo "PASS '${FUNCNAME[0]}': --cron without bucket exits non-zero"
    else
        echo "FAIL '${FUNCNAME[0]}': should have exited non-zero without bucket"
        return 1
    fi
}


# ---------------------------------------------------------------------------
# AWS-dependent tests
# ---------------------------------------------------------------------------

test_staging_cli_dryrun() {
    printf '  starting CLI dry-run sync (DRYRUN=%s)...\n' "${DRYRUN:-true}" >&2

    local output result=0
    output=$(run_ha_offsite_backups 2>&1) || result=$?

    if [[ ${result} -ne 0 ]]; then
        echo "FAIL '${FUNCNAME[0]}': sync exited non-zero (${result})"
        printf '  -- full output --\n' >&2
        printf '%s\n' "${output}" >&2
        printf '  -- end output --\n' >&2
        return 1
    fi
    if echo "${output}" | grep -q 'completed sync'; then
        echo "PASS '${FUNCNAME[0]}': CLI sync completed (DRYRUN=${DRYRUN:-true})"
    else
        echo "FAIL '${FUNCNAME[0]}': 'completed sync' not found in output"
        printf '  -- full output --\n' >&2
        printf '%s\n' "${output}" >&2
        printf '  -- end output --\n' >&2
        return 1
    fi
}

test_staging_cron_fires() {
    local container_id
    container_id=$(run_service_detached -e "CRON_EXPRESSION=* * * * *")
    printf '  container %s started; waiting for first cron sync (up to 2m)...\n' \
        "${container_id:0:12}" >&2

    local result=0
    _wait_for_log_pattern "${container_id}" 'completed sync' 120 || result=$?

    docker stop "${container_id}" > /dev/null 2>&1
    docker rm   "${container_id}" > /dev/null 2>&1

    if [[ ${result} -eq 0 ]]; then
        echo "PASS '${FUNCNAME[0]}': cron sync completed within ${_WAIT_ELAPSED}s" \
             "(DRYRUN=${DRYRUN:-true})"
    else
        echo "FAIL '${FUNCNAME[0]}': sync did not complete within 120s"
        return 1
    fi
}

test_staging_sync_e2e() {
    local epoch test_bucket backup_dir
    epoch=$(date +%s)
    test_bucket="test.staging.backups.ha-offsite-backups-${epoch}"
    backup_dir=$(mktemp -d)

    # shellcheck disable=SC2064
    trap "rm -rf '${backup_dir}'; \
        _aws s3 rb 's3://${test_bucket}' --force > /dev/null 2>&1 || true" \
        RETURN

    local f1 f2 k1 k2
    f1="Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"
    f2="Automatic_backup_2025.6.4_2025-08-01_03.00_00004800.tar"
    k1="20250706T053500-home-assistant-automatic-backup-2025.6.3.tar"
    k2="20250801T030000-home-assistant-automatic-backup-2025.6.4.tar"
    touch "${backup_dir}/${f1}" "${backup_dir}/${f2}"
    printf '  created 2 synthetic HA backup files in %s...\n' "${backup_dir}" >&2

    printf '  creating transient test bucket s3://%s...\n' "${test_bucket}" >&2
    _aws s3 mb "s3://${test_bucket}" > /dev/null 2>&1 || {
        echo "FAIL '${FUNCNAME[0]}': could not create bucket" \
             "(check s3:CreateBucket on test.staging.backups.ha-offsite-backups-*)"
        return 1
    }

    printf '  running live sync (DRYRUN=false)...\n' >&2
    local sync_output sync_result=0
    local args=()
    _append_aws_mounts args
    # shellcheck disable=SC2086
    sync_output=$(docker run --rm ${DOCKER_RUN_ARGS:-} \
        -e "HA_OFFSITE_BACKUPS_AWS_S3_BUCKET_NAME=${test_bucket}" \
        -e "DRYRUN=false" \
        -e "YES=true" \
        "${args[@]}" \
        -v "${backup_dir}:/backups:ro" \
        "${IMAGE}" 2>&1) || sync_result=$?

    if [[ ${sync_result} -ne 0 ]]; then
        echo "FAIL '${FUNCNAME[0]}': sync exited non-zero (${sync_result})"
        printf '%s\n' "${sync_output}" | tail -10 >&2
        return 1
    fi

    local bucket_listing missing=()
    bucket_listing=$(_aws s3 ls "s3://${test_bucket}/" 2>/dev/null)
    echo "${bucket_listing}" | grep -q "${k1}" || missing+=("${k1}")
    echo "${bucket_listing}" | grep -q "${k2}" || missing+=("${k2}")

    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "PASS '${FUNCNAME[0]}': 2 HA backups synced with correct ISO-format keys"
    else
        echo "FAIL '${FUNCNAME[0]}': missing expected S3 keys: ${missing[*]}"
        printf 'Bucket contents:\n' >&2
        printf '%s\n' "${bucket_listing}" >&2
        printf 'Sync output (last 10 lines):\n' >&2
        printf '%s\n' "${sync_output}" | tail -10 >&2
        return 1
    fi
}
