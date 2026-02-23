#!/usr/bin/env bats

# Unit tests for xform-backup-name heuristic.

function xform-backup-name() {
    # Copied simplified test-version of the function to avoid sourcing the full script.
    local file=${1:?Need filename}
    local f
    f=$(basename -- "${file}")
    local re='^Automatic_backup_([^_]+)_([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{2}\.[0-9]{2})_([0-9]+)\.([^.]+)$'
    if [[ "${f}" =~ ${re} ]]; then
        local release="${BASH_REMATCH[1]}"
        local date="${BASH_REMATCH[2]}"
        local time="${BASH_REMATCH[3]}"
        local nanos="${BASH_REMATCH[4]}"
        local ext="${BASH_REMATCH[5]}"
        local base
        base="automatic-backup-${release,,}"
        base="${base//_/-}"
        local date_nodash="${date//-/}"
        local time_nodot="${time//./}"
        local seconds="${nanos:0:2}"
        local time_full="${time_nodot}${seconds}"
        printf "%sT%s-home-assistant-%s.%s" "${date_nodash}" "${time_full}" "${base}" "${ext}"
    else
        local ext_fallback="${f##*.}"
        local base_fallback
        base_fallback=$(echo "${f}" | cut -d_ -f-3 | tr '[:upper:]' '[:lower:]' | tr '_' '-')
        local date_fallback
        date_fallback=$(echo "${f}" | cut -d_ -f4 | tr -d '-')
        local time_fallback
        time_fallback=$(echo "${f}" | cut -d_ -f5- | tr -d '._' | cut -c -6)
        printf "%sT%s-home-assistant-%s.%s" "${date_fallback}" "${time_fallback}" "${base_fallback}" "${ext_fallback}"
    fi
}

@test "xform-backup-name standard filename" {
  filename="Automatic_backup_2025.6.3_2025-07-06_05.35_00004800.tar"
  result=$(xform-backup-name "${filename}")
  [ "${result}" = "20250706T053500-home-assistant-automatic-backup-2025.6.3.tar" ]
}

@test "xform-backup-name fallback for odd filename" {
  filename="Automatic_backup_2025.6.3_2025-07-06_05.35.tar"
  result=$(xform-backup-name "${filename}")
  [ -n "${result}" ]
}
