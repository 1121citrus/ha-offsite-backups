#!/usr/bin/env bats

@test "noop" {
    run true
    [ "$status" -eq 0 ]
}

