#!/usr/bin/env bats

load "test_helper"

setup() {
    repo_root=$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)
    TEST_TMPDIR=$(mktemp -d)
    export TEST_TMPDIR

    # Put the mock aws on PATH first so it shadows the real one.
    mkdir -p "${TEST_TMPDIR}/bin"
    cp "${repo_root}/test/bin/aws" "${TEST_TMPDIR}/bin/aws"
    chmod +x "${TEST_TMPDIR}/bin/aws"
    export PATH="${TEST_TMPDIR}/bin:${PATH}"

    # Log file for mock aws invocations.
    export AWS_MOCK_SYNC_LOG="${TEST_TMPDIR}/aws-sync.log"

    # Point the script at the project's include dir so it can source
    # common-functions during tests (no built image required).
    export INCLUDE_DIR="${repo_root}/src/include"

    # Override the aws command to use the mock.
    export AWS_CMD="${TEST_TMPDIR}/bin/aws"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# ---------------------------------------------------------------------------
# CLI flag tests
# ---------------------------------------------------------------------------

@test "--help exits 0" {
    run bash "${repo_root}/src/ha-offsite-backups" --help
    [ "$status" -eq 0 ]
}

@test "-h exits 0" {
    run bash "${repo_root}/src/ha-offsite-backups" -h
    [ "$status" -eq 0 ]
}

@test "--help output contains 'Usage:'" {
    run bash "${repo_root}/src/ha-offsite-backups" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "--version exits 0" {
    run bash "${repo_root}/src/ha-offsite-backups" --version
    [ "$status" -eq 0 ]
}

@test "-v exits 0" {
    run bash "${repo_root}/src/ha-offsite-backups" -v
    [ "$status" -eq 0 ]
}

@test "CLI mode without bucket exits non-zero" {
    run env \
        HA_OFFSITE_BACKUPS_AWS_S3_BUCKET_NAME= \
        AWS_S3_BUCKET_NAME= \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups"
    [ "$status" -ne 0 ]
}

@test "--cron without bucket exits non-zero" {
    run env \
        HA_OFFSITE_BACKUPS_AWS_S3_BUCKET_NAME= \
        AWS_S3_BUCKET_NAME= \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups" --cron
    [ "$status" -ne 0 ]
}

@test "unknown option exits non-zero" {
    run bash "${repo_root}/src/ha-offsite-backups" --not-a-real-flag
    [ "$status" -ne 0 ]
}

@test "unexpected positional argument exits non-zero" {
    run bash "${repo_root}/src/ha-offsite-backups" unexpected-arg
    [ "$status" -ne 0 ]
}

@test "CRON_EXPRESSION env var implies scheduler mode (exits non-zero without bucket)" {
    # When CRON_EXPRESSION is set before the script runs, scheduler mode is
    # entered.  Without a bucket the scheduler validates early and fails.
    run env \
        CRON_EXPRESSION="@daily" \
        HA_OFFSITE_BACKUPS_AWS_S3_BUCKET_NAME= \
        AWS_S3_BUCKET_NAME= \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Sync behaviour tests
# ---------------------------------------------------------------------------

@test "sync: empty BACKUP_DIR completes successfully (no uploads)" {
    mkdir -p "${TEST_TMPDIR}/backups"

    run env \
        AWS_S3_BUCKET_NAME=test-bucket \
        BACKUP_DIR="${TEST_TMPDIR}/backups" \
        DRYRUN=false \
        AWS_CMD="${AWS_CMD}" \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups"
    [ "$status" -eq 0 ]
}

@test "sync: matching backup files are synced to S3" {
    mkdir -p "${TEST_TMPDIR}/backups"
    touch "${TEST_TMPDIR}/backups/Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"

    run env \
        AWS_S3_BUCKET_NAME=test-bucket \
        BACKUP_DIR="${TEST_TMPDIR}/backups" \
        DRYRUN=false \
        AWS_CMD="${AWS_CMD}" \
        AWS_MOCK_SYNC_LOG="${AWS_MOCK_SYNC_LOG}" \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups"
    [ "$status" -eq 0 ]

    # Mock aws must have received an s3 sync call targeting the test bucket.
    run grep "s3://test-bucket" "${AWS_MOCK_SYNC_LOG}"
    [ "$status" -eq 0 ]
}

@test "sync: non-matching files in BACKUP_DIR are not synced" {
    # A file that does not match 'Automatic_backup_*.tar' must be ignored.
    mkdir -p "${TEST_TMPDIR}/backups"
    touch "${TEST_TMPDIR}/backups/some-other-file.tar"
    touch "${TEST_TMPDIR}/backups/Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"

    run env \
        AWS_S3_BUCKET_NAME=test-bucket \
        BACKUP_DIR="${TEST_TMPDIR}/backups" \
        DRYRUN=false \
        AWS_CMD="${AWS_CMD}" \
        AWS_MOCK_SYNC_LOG="${AWS_MOCK_SYNC_LOG}" \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups"
    [ "$status" -eq 0 ]

    # 'some-other-file.tar' must not appear anywhere in the sync args.
    if [ -f "${AWS_MOCK_SYNC_LOG}" ]; then
        run grep "some-other-file" "${AWS_MOCK_SYNC_LOG}"
        [ "$status" -ne 0 ]
    fi
}

@test "sync: DRYRUN=true passes --dryrun to aws s3 sync" {
    mkdir -p "${TEST_TMPDIR}/backups"
    touch "${TEST_TMPDIR}/backups/Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"

    run env \
        AWS_S3_BUCKET_NAME=test-bucket \
        BACKUP_DIR="${TEST_TMPDIR}/backups" \
        DRYRUN=true \
        AWS_CMD="${AWS_CMD}" \
        AWS_MOCK_SYNC_LOG="${AWS_MOCK_SYNC_LOG}" \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups"
    [ "$status" -eq 0 ]

    # aws mock should have received '--dryrun' in the argument list.
    run grep -- "--dryrun" "${AWS_MOCK_SYNC_LOG}"
    [ "$status" -eq 0 ]
}

@test "sync: DRYRUN=false does not pass --dryrun to aws s3 sync" {
    mkdir -p "${TEST_TMPDIR}/backups"
    touch "${TEST_TMPDIR}/backups/Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"

    run env \
        AWS_S3_BUCKET_NAME=test-bucket \
        BACKUP_DIR="${TEST_TMPDIR}/backups" \
        DRYRUN=false \
        AWS_CMD="${AWS_CMD}" \
        AWS_MOCK_SYNC_LOG="${AWS_MOCK_SYNC_LOG}" \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups"
    [ "$status" -eq 0 ]

    # '--dryrun' must NOT appear when DRYRUN=false.
    if [ -f "${AWS_MOCK_SYNC_LOG}" ]; then
        run grep -- "--dryrun" "${AWS_MOCK_SYNC_LOG}"
        [ "$status" -ne 0 ]
    fi
}

@test "--dryrun flag enables dryrun mode" {
    mkdir -p "${TEST_TMPDIR}/backups"
    touch "${TEST_TMPDIR}/backups/Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"

    run env \
        AWS_S3_BUCKET_NAME=test-bucket \
        BACKUP_DIR="${TEST_TMPDIR}/backups" \
        AWS_CMD="${AWS_CMD}" \
        AWS_MOCK_SYNC_LOG="${AWS_MOCK_SYNC_LOG}" \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups" --dryrun
    [ "$status" -eq 0 ]

    run grep -- "--dryrun" "${AWS_MOCK_SYNC_LOG}"
    [ "$status" -eq 0 ]
}

@test "--no-dryrun flag disables dryrun mode" {
    mkdir -p "${TEST_TMPDIR}/backups"
    touch "${TEST_TMPDIR}/backups/Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"

    run env \
        AWS_S3_BUCKET_NAME=test-bucket \
        BACKUP_DIR="${TEST_TMPDIR}/backups" \
        AWS_CMD="${AWS_CMD}" \
        AWS_MOCK_SYNC_LOG="${AWS_MOCK_SYNC_LOG}" \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups" --no-dryrun
    [ "$status" -eq 0 ]

    if [ -f "${AWS_MOCK_SYNC_LOG}" ]; then
        run grep -- "--dryrun" "${AWS_MOCK_SYNC_LOG}"
        [ "$status" -ne 0 ]
    fi
}

@test "--bucket flag sets the destination bucket" {
    mkdir -p "${TEST_TMPDIR}/backups"
    touch "${TEST_TMPDIR}/backups/Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"

    run env \
        DRYRUN=false \
        BACKUP_DIR="${TEST_TMPDIR}/backups" \
        AWS_CMD="${AWS_CMD}" \
        AWS_MOCK_SYNC_LOG="${AWS_MOCK_SYNC_LOG}" \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups" --bucket flag-bucket
    [ "$status" -eq 0 ]

    run grep "s3://flag-bucket" "${AWS_MOCK_SYNC_LOG}"
    [ "$status" -eq 0 ]
}

@test "AWS_S3_BUCKET_NAME env var sets the destination bucket" {
    mkdir -p "${TEST_TMPDIR}/backups"
    touch "${TEST_TMPDIR}/backups/Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"

    run env \
        AWS_S3_BUCKET_NAME=s3name-bucket \
        BACKUP_DIR="${TEST_TMPDIR}/backups" \
        DRYRUN=false \
        AWS_CMD="${AWS_CMD}" \
        AWS_MOCK_SYNC_LOG="${AWS_MOCK_SYNC_LOG}" \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups"
    [ "$status" -eq 0 ]

    run grep "s3://s3name-bucket" "${AWS_MOCK_SYNC_LOG}"
    [ "$status" -eq 0 ]
}

@test "HA_OFFSITE_BACKUPS_AWS_S3_BUCKET_NAME takes priority over AWS_S3_BUCKET_NAME" {
    mkdir -p "${TEST_TMPDIR}/backups"
    touch "${TEST_TMPDIR}/backups/Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"

    run env \
        HA_OFFSITE_BACKUPS_AWS_S3_BUCKET_NAME=bucket-wins \
        AWS_S3_BUCKET_NAME=s3name-loses \
        BACKUP_DIR="${TEST_TMPDIR}/backups" \
        DRYRUN=false \
        AWS_CMD="${AWS_CMD}" \
        AWS_MOCK_SYNC_LOG="${AWS_MOCK_SYNC_LOG}" \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups"
    [ "$status" -eq 0 ]

    run grep "s3://bucket-wins" "${AWS_MOCK_SYNC_LOG}"
    [ "$status" -eq 0 ]

    # AWS_S3_BUCKET_NAME must not be used when HA_OFFSITE_BACKUPS_AWS_S3_BUCKET_NAME is set.
    if [ -f "${AWS_MOCK_SYNC_LOG}" ]; then
        run grep "s3://s3name-loses" "${AWS_MOCK_SYNC_LOG}"
        [ "$status" -ne 0 ]
    fi
}

@test "--backup-dir flag sets the source directory" {
    # Alternate backup dir passed via CLI flag.
    local alt_dir="${TEST_TMPDIR}/alt-backups"
    mkdir -p "${alt_dir}"
    touch "${alt_dir}/Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"

    run env \
        AWS_S3_BUCKET_NAME=test-bucket \
        DRYRUN=false \
        AWS_CMD="${AWS_CMD}" \
        AWS_MOCK_SYNC_LOG="${AWS_MOCK_SYNC_LOG}" \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups" --backup-dir "${alt_dir}"
    [ "$status" -eq 0 ]

    run grep "s3://test-bucket" "${AWS_MOCK_SYNC_LOG}"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# xform-backup-name filename transformation tests
#
# These test the rename logic indirectly: the mock aws records the symlink
# names that appear in the WORKDIR handed to 'aws s3 sync'.  The recorded
# argument line includes the WORKDIR path; the renamed filenames are only
# visible via the WORKDIR contents, so we check the script log output.
# ---------------------------------------------------------------------------

@test "xform: Automatic_backup renamed to ISO-datetime format" {
    mkdir -p "${TEST_TMPDIR}/backups"
    touch "${TEST_TMPDIR}/backups/Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"

    run env \
        AWS_S3_BUCKET_NAME=test-bucket \
        BACKUP_DIR="${TEST_TMPDIR}/backups" \
        DRYRUN=false \
        AWS_CMD="${AWS_CMD}" \
        AWS_MOCK_SYNC_LOG="${AWS_MOCK_SYNC_LOG}" \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups"
    [ "$status" -eq 0 ]

    # Script logs the rename; verify expected ISO name appears.
    [[ "$output" == *"20250706T053500-home-assistant-automatic-backup-2025.6.3.tar"* ]]
}

@test "xform: multiple backups each renamed correctly" {
    mkdir -p "${TEST_TMPDIR}/backups"
    touch "${TEST_TMPDIR}/backups/Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"
    touch "${TEST_TMPDIR}/backups/Automatic_backup_2025.6.3_2025-07-15_09.10_35433883.tar"

    run env \
        AWS_S3_BUCKET_NAME=test-bucket \
        BACKUP_DIR="${TEST_TMPDIR}/backups" \
        DRYRUN=false \
        AWS_CMD="${AWS_CMD}" \
        AWS_MOCK_SYNC_LOG="${AWS_MOCK_SYNC_LOG}" \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        bash "${repo_root}/src/ha-offsite-backups"
    [ "$status" -eq 0 ]

    [[ "$output" == *"20250706T053500-home-assistant-automatic-backup-2025.6.3.tar"* ]]
    [[ "$output" == *"20250715T091035-home-assistant-automatic-backup-2025.6.3.tar"* ]]
}
