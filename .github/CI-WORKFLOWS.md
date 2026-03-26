# GitHub CI Workflows

Automated linting, building, testing, security scanning, and Docker image publication for ha-offsite-backups.

## Workflow Overview

| Stage          | Trigger                              | Purpose                                        |
| -------------- | ------------------------------------ | ---------------------------------------------- |
| **Lint**       | All pushes, PRs, tags                | Validate Dockerfile and shell scripts          |
| **Build**      | After lint                           | Build image as artifact (for scan)             |
| **Test**       | After lint (parallel with build)     | Run bats tests in a bats Docker container      |
| **Scan**       | After build                          | Trivy image scan — blocks push on fixable CVEs |
| **Push**       | Version tags and staging branch only | Multi-platform build and push to Docker Hub    |
| **Dependabot**       | Weekly (Monday 06:00 UTC)            | Keep GitHub Actions versions current           |
| **Release Please**   | Push to main/master                  | Open release PR; create tag and GitHub Release |

## CI Workflow (`ci.yml`)

Single unified workflow for all CI/CD stages.

### Global configuration

- **Image name:** `1121citrus/ha-offsite-backups`
- **Node.js actions runtime:** v24 (via `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`)

### Trigger Events

- **Push:** `main`, `staging` branches and `v*` version tags
- **Pull requests:** To `main` branch

### Concurrency

- **Group:** `<workflow-name>-<ref>` — one concurrent run per workflow + branch/tag
- **Branches and PRs:** Cancel any in-progress run when a newer one starts
- **Version tags:** Never cancelled — release builds always complete

### Versioning

Tag-driven. Push a git tag to publish a release:

```bash
git tag v1.2.3
git push origin v1.2.3
# Publishes: 1121citrus/ha-offsite-backups:1.2.3 + :1.2 + :1 + :latest
```

No automation bumps the version — the tag is always a deliberate decision.

---

## Stage 1: Lint

- **Hadolint** — Dockerfile best-practice checks
- **ShellCheck** — static analysis (`-x`) of `src/` shell scripts:
  - `src/ha-offsite-backups`, `src/healthcheck`, `src/startup`
  - `src/include/common-functions`
  - Per-file `# shellcheck disable=SC1090,SC1091` directives handle dynamic and
    install-time source paths

---

## Stage 2: Build

Builds the Docker image for `linux/amd64` and exports as a GitHub Actions artifact (`docker-image`). The image is used only by the scan job — tests run in a separate bats container.

Artifact retention: 1 day.

**Docker layer cache:** `cache-from: type=gha` / `cache-to: type=gha,mode=max` — build
layers are saved to and restored from GitHub Actions cache, speeding up incremental
builds. The push job restores from the same cache.

---

## Stage 3: Test

Runs in parallel with the build job (both depend only on lint). The test suite runs inside the official `bats/bats:1.13.0` Docker container with the project source bind-mounted:

```bash
docker run -i --rm -v "$PWD:/code" -w /code bats/bats:1.13.0 test
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
- **DB caching:** `~/.cache/trivy` is cached between runs with `actions/cache`; the
  vulnerability DB is only re-downloaded when the cache is cold or the DB has been updated
- **Download noise:** `TRIVY_NO_PROGRESS=true` suppresses progress bars; `TRIVY_QUIET=true`
  suppresses `INFO [vulndb]` log lines during DB download

---

## Stage 5: Push to Docker Hub

Runs only when test and scan both pass, and only on version tags or the staging branch.

### Tagging

- **Tag `v1.2.3`** → `1121citrus/ha-offsite-backups:1.2.3` + `:1.2` + `:1` + `:latest`
- **Push to `staging`** → `1121citrus/ha-offsite-backups:staging-<sha>` + `:staging`

`:latest` is set **only** on version-tagged releases. Staging uses a short commit SHA for traceability.

### Build configuration

- **Platforms:** `linux/amd64`, `linux/arm64`
- **Attestations:** `sbom: true` + `provenance: mode=max` (SLSA L3)
- **Layer cache:** `cache-from: type=gha` / `cache-to: type=gha,mode=max`

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

## Automated dependency updates

`dependabot.yml` configures weekly automated PRs to keep GitHub Actions current.

- **Schedule:** Every Monday at 06:00 UTC
- **Scope:** GitHub Actions (`package-ecosystem: github-actions`) — updates action pins in
  `.github/workflows/*.yml`
- **Labels:** `dependencies`, `github-actions`
- **Security benefit:** Dependabot also proposes SHA-pinned digests (recommended for SLSA /
  OpenSSF Scorecard hardening)

---

## Local Workflow Parity

- `./build` supports `--advise`/`--advice`, `--no-advise`, and `--cache` with Trivy/Grype cache targets.
- Local stage 5 advisories (Grype, Scout, Dive) are non-gating and mirror the rotate-aws-backups pattern.

---

## Automated releases (release-please)

`release-please.yml` watches for [conventional commits](https://www.conventionalcommits.org/)
merged to `main`/`master` and automates the release lifecycle:

1. Opens a "release PR" that bumps `version.txt`, prepends to `CHANGELOG.md`, and proposes the next semver tag
2. When the release PR is merged, creates a GitHub Release and pushes the version tag
3. The existing CI `push` job fires on the new tag and builds and publishes the Docker image

### Conventional commit types that trigger version bumps

| Commit prefix | Bump |
|---|---|
| `fix:` | patch (1.0.x) |
| `feat:` | minor (1.x.0) |
| `feat!:` or `BREAKING CHANGE:` | major (x.0.0) |

All other prefixes (`ci:`, `docs:`, `chore:`, `refactor:`, `test:`, etc.) appear in the
changelog but do not trigger a version bump on their own.

### Configuration

- `release-please-config.json` — release type (`simple`) and package root
- `.release-please-manifest.json` — current version (updated by release-please on each release)
- `version.txt` — plain-text version file (updated by release-please; can be referenced in Dockerfile)
- `CHANGELOG.md` — generated/updated by release-please
