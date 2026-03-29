#!/usr/bin/env bats

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
}

teardown() {
    rm -rf "$TEST_TMPDIR"
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
