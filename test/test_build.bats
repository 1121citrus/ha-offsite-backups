#!/usr/bin/env bats

setup() {
    BUILD_SCRIPT="${BATS_TEST_DIRNAME}/../build"
}

@test "build --help documents advice and cache" {
    run "${BUILD_SCRIPT}" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--advice"* ]]
    [[ "$output" == *"--cache CACHE_RULES"* ]]
}

@test "build --advice scout enables Scout advisement" {
    run "${BUILD_SCRIPT}" --advice scout --dry-run --no-lint --no-test --no-scan
    [ "$status" -eq 0 ]
    [[ "$output" == *"Stage 5b: Advise (Scout)"* ]]
}

@test "build --cache reset=all reports both cache resets" {
    run "${BUILD_SCRIPT}" --cache "reset=all" --dry-run --no-lint --no-test --no-scan --no-advise
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cache: reset Trivy DB"* ]]
    [[ "$output" == *"Cache: reset Grype DB"* ]]
}
