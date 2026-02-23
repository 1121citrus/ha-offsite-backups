#!/usr/bin/env bats

# Unit tests for xform-backup-name.
# Sources the real script - safe because all logic is inside functions;
# common-functions sourcing only happens inside the ha-offsite-backups() body.

setup() {
    source "${BATS_TEST_DIRNAME}/../src/ha-offsite-backups"
}

@test "standard filename" {
    result=$(xform-backup-name "Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar")
    [ "${result}" = "20250706T053500-home-assistant-automatic-backup-2025.6.3.tar" ]
}

@test "filename with directory prefix is stripped" {
    result=$(xform-backup-name "/backups/Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar")
    [ "${result}" = "20250706T053500-home-assistant-automatic-backup-2025.6.3.tar" ]
}

@test "nanos first two digits become seconds field" {
    result=$(xform-backup-name "Automatic_backup_2025.6.3_2025-07-16_05.34_36783615.tar")
    [ "${result}" = "20250716T053436-home-assistant-automatic-backup-2025.6.3.tar" ]
}

@test "release with multiple version components" {
    result=$(xform-backup-name "Automatic_backup_2025.12.1_2025-12-01_00.00_00000001.tar")
    [ "${result}" = "20251201T000000-home-assistant-automatic-backup-2025.12.1.tar" ]
}

@test "zero-padded nanos produces 00 seconds" {
    result=$(xform-backup-name "Automatic_backup_2025.6.3_2025-07-15_09.10_00123456.tar")
    [ "${result}" = "20250715T091000-home-assistant-automatic-backup-2025.6.3.tar" ]
}

@test "fallback for non-matching filename produces best-effort output" {
    result=$(xform-backup-name "Automatic_backup_2025.6.3_2025-07-06_05.35.tar")
    [ "${result}" = "20250706T0535ta-home-assistant-automatic-backup-2025.6.3.tar" ]
}
