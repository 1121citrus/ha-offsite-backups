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

@test "build --advise Dive enables Dive" {
    run "${BUILD_SCRIPT}" --advise Dive --dry-run --no-lint --no-test --no-scan
    [ "$status" -eq 0 ]
    [[ "$output" == *"Stage 5c: Advise (Dive)"* ]]
}

@test "build --advise DIVE enables Dive" {
    run "${BUILD_SCRIPT}" --advise DIVE --dry-run --no-lint --no-test --no-scan
    [ "$status" -eq 0 ]
    [[ "$output" == *"Stage 5c: Advise (Dive)"* ]]
}

@test "build --advise none disables all advisements" {
    run "${BUILD_SCRIPT}" --advise none --dry-run --no-lint --no-test --no-scan
    [ "$status" -eq 0 ]
    [[ "$output" != *"Stage 5a"* ]]
    [[ "$output" != *"Stage 5b"* ]]
    [[ "$output" != *"Stage 5c"* ]]
}

@test "build --advise NONE disables all advisements" {
    run "${BUILD_SCRIPT}" --advise NONE --dry-run --no-lint --no-test --no-scan
    [ "$status" -eq 0 ]
    [[ "$output" != *"Stage 5a"* ]]
    [[ "$output" != *"Stage 5b"* ]]
    [[ "$output" != *"Stage 5c"* ]]
}

@test "build --advice none disables all advisements" {
    run "${BUILD_SCRIPT}" --advice none --dry-run --no-lint --no-test --no-scan
    [ "$status" -eq 0 ]
    [[ "$output" != *"Stage 5a"* ]]
    [[ "$output" != *"Stage 5b"* ]]
    [[ "$output" != *"Stage 5c"* ]]
}

@test "build --no-advise disables all advisements" {
    run "${BUILD_SCRIPT}" --no-advise --dry-run --no-lint --no-test --no-scan
    [ "$status" -eq 0 ]
    [[ "$output" != *"Stage 5a"* ]]
    [[ "$output" != *"Stage 5b"* ]]
    [[ "$output" != *"Stage 5c"* ]]
}

@test "build --advise scout,dive enables Scout and Dive" {
    run "${BUILD_SCRIPT}" --advise scout,dive --dry-run --no-lint --no-test --no-scan
    [ "$status" -eq 0 ]
    [[ "$output" == *"Stage 5b: Advise (Scout)"* ]]
    [[ "$output" == *"Stage 5c: Advise (Dive)"* ]]
}

@test "build --advise rejects unknown advisement" {
    run "${BUILD_SCRIPT}" --advise unknown --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown advisement"* ]]
}

@test "build defaults to no advisory scans" {
    run "${BUILD_SCRIPT}" --dry-run --no-lint --no-test --no-scan
    [ "$status" -eq 0 ]
    [[ "$output" != *"Stage 5a"* ]]
    [[ "$output" != *"Stage 5b"* ]]
    [[ "$output" != *"Stage 5c"* ]]
}

@test "build --cache reset=all reports both cache resets" {
    run "${BUILD_SCRIPT}" --cache "reset=all" --dry-run --no-lint --no-test --no-scan --no-advise
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cache: reset Trivy DB"* ]]
    [[ "$output" == *"Cache: reset Grype DB"* ]]
}

@test "build --cache Reset=All reports both cache resets" {
    run "${BUILD_SCRIPT}" --cache "Reset=All" --dry-run --no-lint --no-test --no-scan --no-advise
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cache: reset Trivy DB"* ]]
    [[ "$output" == *"Cache: reset Grype DB"* ]]
}

@test "build --cache Skip-Update=TrIvY skips Trivy DB update" {
    run "${BUILD_SCRIPT}" --cache "Skip-Update=TrIvY" --dry-run --no-lint --no-test
    [ "$status" -eq 0 ]
    [[ "$output" == *"Trivy DB update skipped"* ]]
}

@test "build defaults to Stage 3b smoke" {
    run "${BUILD_SCRIPT}" --dry-run --no-lint --no-test --no-scan --no-advise
    [ "$status" -eq 0 ]
    [[ "$output" == *"Stage 3b: Smoke"* ]]
}

@test "build --no-smoke skips Stage 3b smoke" {
    run "${BUILD_SCRIPT}" --dry-run --no-lint --no-test --no-smoke --no-scan --no-advise
    [ "$status" -eq 0 ]
    [[ "$output" != *"Stage 3b: Smoke"* ]]
}
