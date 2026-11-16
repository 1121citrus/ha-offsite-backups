#!/usr/bin/env bats

load "test_helper"

setup() {
  repo_root=$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)
}

@test "Dockerfile uses dnf install" {
  run grep -F "dnf install -y" "${repo_root}/Dockerfile"
  [ "$status" -eq 0 ]
}

@test "Dockerfile installs aws" {
  run grep -F "aws" "${repo_root}/Dockerfile"
  [ "$status" -eq 0 ]
}

@test "Dockerfile contains HEALTHCHECK" {
  run grep -F "HEALTHCHECK --interval=60s --timeout=5s --retries=3" "${repo_root}/Dockerfile"
  [ "$status" -eq 0 ]
}

@test "Dockerfile uses ha-offsite-backups as ENTRYPOINT" {
  run grep -F 'ENTRYPOINT ["/usr/local/bin/ha-offsite-backups"]' "${repo_root}/Dockerfile"
  [ "$status" -eq 0 ]
}

@test "Dockerfile has no CMD (mode must be chosen explicitly)" {
  run grep -E '^CMD ' "${repo_root}/Dockerfile"
  [ "$status" -ne 0 ]
}

@test "Dockerfile dnf upgrade and install use --releasever=latest" {
  run grep -E 'dnf upgrade -y .*--releasever=latest' "${repo_root}/Dockerfile"
  [ "$status" -eq 0 ]
  run grep -E 'dnf install -y .*--releasever=latest' "${repo_root}/Dockerfile"
  [ "$status" -eq 0 ]
}

@test "Dockerfile rebuilds supercronic with a patched local Go toolchain" {
  run grep -E '^FROM golang:1\.27\.[0-3]-' "${repo_root}/Dockerfile"
  [ "$status" -ne 0 ]
  run grep -F 'GOTOOLCHAIN=local' "${repo_root}/Dockerfile"
  [ "$status" -eq 0 ]
  run grep -F 'COPY --from=supercronic-builder' "${repo_root}/Dockerfile"
  [ "$status" -eq 0 ]
}
