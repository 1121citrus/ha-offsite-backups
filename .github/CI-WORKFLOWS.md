# GitHub CI Workflows

Automated linting, building, testing, security scanning, and Docker image publication for ha-offsite-backups.

## Workflow Overview

| Stage     | Trigger                              | Purpose                                        |
| --------- | ------------------------------------ | ---------------------------------------------- |
| **Lint**  | All pushes, PRs, tags                | Validate Dockerfile and shell scripts          |
| **Build** | After lint                           | Build image as artifact (for scan)             |
| **Test**  | After lint (parallel with build)     | Run bats tests in a bats Docker container      |
| **Scan**  | After build                          | Trivy image scan — blocks push on fixable CVEs |
| **Push**  | Version tags and staging branch only | Multi-platform build and push to Docker Hub    |

## CI Workflow (`ci.yml`)

Single unified workflow for all CI/CD stages.

### Trigger Events

- **Push:** `main`, `staging` branches and `v*` version tags
- **Pull requests:** To `main` branch

### Versioning

Tag-driven. Push a git tag to publish a release:

```bash
git tag v1.2.3
git push origin v1.2.3
# Publishes: 1121citrus/ha-offsite-backups:1.2.3 + :latest
```

No automation bumps the version — the tag is always a deliberate decision.

---

## Stage 1: Lint

- **Hadolint** — Dockerfile best-practice checks
- **ShellCheck** — static analysis of `src/` shell scripts:
  - `src/ha-offsite-backups`, `src/healthcheck`, `src/startup`
  - `src/include/common-functions`
  - `--exclude=SC1090,SC2148` — suppresses warnings for intentionally sourced library files

---

## Stage 2: Build

Builds the Docker image for `linux/amd64` and exports as a GitHub Actions artifact (`docker-image`). The image is used only by the scan job — tests run in a separate bats container.

Artifact retention: 1 day.

---

## Stage 3: Test

Runs in parallel with the build job (both depend only on lint). The test suite runs inside the official `bats/bats:latest` Docker container with the project source bind-mounted:

```bash
docker run -i --rm -v "$PWD:/code" -w /code bats/bats:latest test
```

This runs all `.bats` files in the `test/` directory:

- `test/test_sync_mocked.bats` — sync logic with mocked dependencies
- `test/test_xform.bats` — filename transformation logic

Tests do not require the application image.

**Note:** The `test/run-all` helper uses `-it` (allocates a TTY) which is not available in CI. The CI step calls `docker run -i` (stdin only) directly.

---

## Stage 4: Security scan

Scans the built image **before** it is pushed to Docker Hub.

- **Tool:** Trivy `aquasecurity/trivy-action@0.35.0` (pinned)
- **Severity:** CRITICAL, HIGH
- **Blocking:** `exit-code: 1` — fails and blocks push if fixable CVEs found
- **Noise reduction:** `ignore-unfixed: true` — suppresses CVEs with no available patch

---

## Stage 5: Push to Docker Hub

Runs only when test and scan both pass, and only on version tags or the staging branch.

### Tagging

- **Tag `v1.2.3`** → `1121citrus/ha-offsite-backups:1.2.3` + `:latest`
- **Push to `staging`** → `1121citrus/ha-offsite-backups:staging-<timestamp>` + `:staging`

`:latest` is set **only** on version-tagged releases. Staging gets a datetime timestamp for traceability.

### Build configuration

- **Platforms:** `linux/amd64`, `linux/arm64`
- **Attestations:** `sbom: true` + `provenance: mode=max` (SLSA L3)

---

## Execution Flow

```
On push/PR
    ↓
[Lint] — hadolint + shellcheck
    ↓ (parallel)
[Build]                          [Test]
 - Docker image → artifact        - bats container, source mounted
 - for scan only                  - test_sync_mocked.bats
    ↓                             - test_xform.bats
[Scan] — Trivy CRITICAL/HIGH
    ↓ (both test + scan must pass)
[Push] (tags and staging only)
 - QEMU + Buildx multi-arch
 - push amd64 + arm64
 - SBOM + provenance
```

---

## Configuration Reference

### Required Secrets

- `DOCKERHUB_USERNAME` — Docker Hub account
- `DOCKERHUB_TOKEN` — Docker Hub access token

### Key Files

- `Dockerfile` — Container build definition
- `src/ha-offsite-backups` — Main sync script
- `src/include/common-functions` — Shared shell library
- `test/test_sync_mocked.bats` — Sync logic tests
- `test/test_xform.bats` — Filename transformation tests
- `test/run-all` — Local test runner (uses `-it`; not used in CI)

## Local Workflow Parity

- `./build` supports `--advise`/`--advice`, `--no-advise`, and `--cache` with Trivy/Grype cache targets.
- Local stage 5 advisories (Grype, Scout, Dive) are non-gating and mirror the rotate-aws-backups pattern.
