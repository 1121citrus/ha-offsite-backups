#!/usr/bin/env bats

SCRIPT_PATH="${BATS_TEST_DIRNAME}/../src/ha-offsite-backups"

setup() {
    TEST_ROOT="$(mktemp -d)"
    BACKUP_DIR="${TEST_ROOT}/backups"
    MOCKBIN="${TEST_ROOT}/mockbin"
    COMMON_FUNCTIONS="${TEST_ROOT}/common-functions"
    MOCK_AWS_LOG="${TEST_ROOT}/aws.log"
    MOCK_AWS_SRC="${TEST_ROOT}/aws.src"
    MOCK_AWS_DST="${TEST_ROOT}/aws.dst"
    MOCK_AWS_LINKS="${TEST_ROOT}/aws.links"

    mkdir -p "${BACKUP_DIR}" "${MOCKBIN}"

    cat > "${COMMON_FUNCTIONS}" <<'EOF'
#!/usr/bin/env bash

function is-true() {
    local value="${1:-}"
    [[ "${value,,}" =~ ^(1|on|true|t|yes|y)$ ]]
}

function is_true() {
    is-true "${@}"
}

function info() {
    if [[ "$#" -gt 0 ]]; then
        echo "${*}" >&2
    else
        cat >&2
    fi
}

function error() {
    if [[ "$#" -gt 0 ]]; then
        echo "${*}" >&2
    else
        cat >&2
    fi
    return 1
}
EOF

    cat > "${MOCKBIN}/aws" <<'EOF'
#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

printf '%s\n' "$*" >> "${MOCK_AWS_LOG}"

args=("$@")
if [[ "${#args[@]}" -ge 4 ]] && [[ "${args[0]}" == "s3" ]] && [[ "${args[1]}" == "sync" ]]; then
    src="${args[$(( ${#args[@]} - 2 ))]}"
    dst="${args[$(( ${#args[@]} - 1 ))]}"
    printf '%s\n' "${src}" > "${MOCK_AWS_SRC}"
    printf '%s\n' "${dst}" > "${MOCK_AWS_DST}"
    find "${src}" -maxdepth 1 -type l | sed 's#.*/##' | sort > "${MOCK_AWS_LINKS}"
fi

if [[ "${MOCK_AWS_FAIL:-0}" == "1" ]]; then
    exit 2
fi
EOF

    chmod 755 "${COMMON_FUNCTIONS}" "${MOCKBIN}/aws"
}

teardown() {
    rm -rf "${TEST_ROOT}"
}

run_script() {
    run env \
        PATH="${MOCKBIN}:${PATH}" \
        HOME="${TEST_ROOT}" \
        COMMON_FUNCTIONS_FILE="${COMMON_FUNCTIONS}" \
        AWS_S3_BUCKET_NAME="backup-bucket" \
        BACKUP_DIR="${BACKUP_DIR}" \
        DRYRUN="${DRYRUN:-false}" \
        MOCK_AWS_LOG="${MOCK_AWS_LOG}" \
        MOCK_AWS_SRC="${MOCK_AWS_SRC}" \
        MOCK_AWS_DST="${MOCK_AWS_DST}" \
        MOCK_AWS_LINKS="${MOCK_AWS_LINKS}" \
        MOCK_AWS_FAIL="${MOCK_AWS_FAIL:-0}" \
        bash "${SCRIPT_PATH}"
}

@test "sync calls aws with dryrun and transformed symlink names" {
    touch "${BACKUP_DIR}/Automatic_backup_2025.6.3_2025-07-16_05.34_36783615.tar"
    touch "${BACKUP_DIR}/Automatic_backup_2025.6.3_2025-07-15_09.10_35433883.tar"

    DRYRUN=true
    run_script

    [ "${status}" -eq 0 ]
    grep -q "^s3 sync --no-progress --dryrun " "${MOCK_AWS_LOG}"
    grep -q "^s3://backup-bucket$" "${MOCK_AWS_DST}"
    grep -q "^20250716T053436-home-assistant-automatic-backup-2025.6.3.tar$" "${MOCK_AWS_LINKS}"
    grep -q "^20250715T091035-home-assistant-automatic-backup-2025.6.3.tar$" "${MOCK_AWS_LINKS}"
}

@test "empty backup directory logs no matches and still syncs" {
    DRYRUN=true
    run_script

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"no matching backup files found"* ]]
    grep -q "^s3 sync --no-progress --dryrun " "${MOCK_AWS_LOG}"
}

@test "aws failure returns non-zero and logs exit status" {
    touch "${BACKUP_DIR}/Automatic_backup_2025.6.3_2025-07-16_05.34_36783615.tar"

    MOCK_AWS_FAIL=1
    run_script

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"aws s3 sync exited with status 2"* ]]
}
