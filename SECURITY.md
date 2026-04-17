# Security Policy

## Security Design

The image is built with defence-in-depth from the ground up:

| Control | Implementation |
| --- | --- |
| Non-root execution | Dedicated `ha-offsite-backups` user, UID 10001, shell `/sbin/nologin` |
| Minimal base image | `alpine:3.22` — no package manager beyond apk, minimal utilities |
| Supply-chain pinning | All dependencies pinned to specific versions; digest pinning for Alpine base |
| OS patch hygiene | Python and Alpine versions are pinned; images include the latest available patches for pinned versions |
| Read-only filesystem | Configuration read from mounted secrets; use `--read-only --tmpfs /tmp` for runtime |
| Credential isolation | AWS credentials via `AWS_CONFIG_FILE` or Docker secrets; never exposed in startup logs |
| Cron isolation | Scheduled backups via crond; no manual script invocations in production |
| SLSA Build Provenance | SLSA Level 3 attestations on every published image |
| SBOM attestation | SPDX SBOM attached to every published image |
| Vulnerability scanning | Trivy (Aqua) scans every CI build; fixable HIGH/CRITICAL CVEs block the pipeline |

## Threat Model

| Threat | Risk | Mitigation |
| --- | --- | --- |
| **Adjacent container access** | High | Use `--network=none` in production; image makes no outbound connections outside the cron job |
| **Malicious HA backup file** | Medium | Backup archives are never extracted; only synced to S3. XML parsing is read-only. |
| **Compromised AWS credentials** | High | Store in `AWS_CONFIG_FILE` (mounted read-only secret) or Docker secret; never in env vars |
| **Leaked S3 bucket name** | Low | Bucket name is visible in startup logs; this is expected and logged with restricted permissions |
| **DRYRUN default protecting against accidental sync** | Medium | `AWS_DRYRUN=false` must be explicitly set to perform destructive operations |

## Security Reporting

Please report security vulnerabilities through the [GitHub Security tab](https://github.com/1121citrus/ha-offsite-backups/security).
Do not open a public GitHub issue for security vulnerabilities. Include:

- **Description:** What is the vulnerability?
- **Affected versions:** Which image tags are impacted?
- **Severity:** CRITICAL / HIGH / MEDIUM / LOW
- **Steps to reproduce:** How can the vulnerability be demonstrated?
- **Impact:** What can an attacker achieve?

## Known Vulnerabilities

### Open Vulnerabilities

The following vulnerabilities have no fix available in the Alpine package index.
Each is accepted with a documented mitigation and tracked in `.grype.yaml`.

#### CVE-2022-32511 (CRITICAL)

- **Component**: py3-jmespath (Alpine apk)
- **Affected Version**: 1.0.1-r4
- **Fixed Version**: no apk fix available
- **Description**: Denial of service via crafted JMESPath expression.
- **Status**: No Alpine package fix available; monitoring for upstream release
- **Mitigation**: jmespath is consumed internally by the AWS CLI for JSON
  response filtering; it is not exposed to user-controlled input at runtime
- **Reference**: <https://avd.aquasec.com/nvd/cve-2022-32511>

#### CVE-2025-13836 (HIGH)

- **Component**: python3 (Alpine apk)
- **Affected Version**: 3.12.13-r0
- **Fixed Version**: no apk fix available
- **Description**: CPython vulnerability in the affected 3.12 release.
- **Status**: No Alpine package fix available; monitoring for upstream release
- **Mitigation**: ha-offsite-backups does not use the affected CPython code path;
  the application performs file renaming and S3 sync only
- **Reference**: <https://avd.aquasec.com/nvd/cve-2025-13836>

#### CVE-2025-66471, CVE-2025-66418 (HIGH)

- **Component**: py3-urllib3 (Alpine apk)
- **Affected Version**: 1.26.20-r1
- **Fixed Version**: no apk fix available
- **Description**: Multiple HIGH vulnerabilities in urllib3 1.26.x.
- **Status**: No Alpine apk fix available; pip-installed urllib3 >= 2.6.3 is
  the active runtime version (installed at `/usr/local/lib/python3.12/`) and
  is fully patched. The apk copy at `/usr/lib/python3.12/` is superseded by
  the pip install and not imported at runtime.
- **References**: <https://avd.aquasec.com/nvd/cve-2025-66471>,
  <https://avd.aquasec.com/nvd/cve-2025-66418>

#### GHSA-58pv-8j8x-9vj2 / wheel CVE-2026-24049 (HIGH)

- **Component**: jaraco-context 5.3.0, wheel 0.45.1 (vendored inside `py3-setuptools`)
- **Location**: `/usr/lib/python3.12/site-packages/setuptools/_vendor/`
- **Installed Runtime Version**: jaraco-context 6.1.2, wheel 0.46.3 (pip-installed, patched)
- **Fixed Version**: no apk fix for the setuptools-vendored copies
- **Description**: setuptools ships private vendored copies of several packages
  inside its `_vendor/` tree. These copies are not importable by application
  code; only setuptools itself uses them for its own installation machinery.
- **Status**: No apk fix available; monitoring for a setuptools package rebuild
  that vendors the patched versions
- **Mitigation**: The application does not invoke setuptools at runtime.
  The runtime Python import path resolves to the pip-installed copies
  (jaraco-context 6.1.2, wheel 0.46.3) which are fully patched.
- **References**: <https://github.com/advisories/GHSA-58pv-8j8x-9vj2>,
  <https://avd.aquasec.com/nvd/cve-2026-24049>

#### CVE-2025-68121 (CRITICAL), CVE-2025-61732 (HIGH)

- **Component**: Go stdlib (embedded in `supercronic=0.2.33-r10`, Alpine apk)
- **Affected Version**: go1.24.12 (compiled into supercronic binary)
- **Fixed Version**: Go >= 1.24.13 — no Alpine apk update for supercronic available
- **Description**: Vulnerabilities in the Go standard library net/http and
  crypto packages, fixed in Go 1.24.13.
- **Status**: No Alpine apk update available for `supercronic=0.2.33-r10`;
  monitoring for an Alpine package rebuild with a newer Go toolchain
- **Mitigation**: supercronic is used solely as a cron scheduler to invoke the
  backup script on a schedule; it does not act as an HTTP server or handle
  cryptographic operations that exercise the vulnerable code paths
- **References**: <https://avd.aquasec.com/nvd/cve-2025-68121>,
  <https://avd.aquasec.com/nvd/cve-2025-61732>

---

### Remediated Vulnerabilities

Addressed by pinning vulnerable packages to their minimum fixed versions
in `requirements.txt`:

| CVE / Advisory | Component | Was | Fixed at |
| --- | --- | --- | --- |
| CVE-2026-24049 / GHSA-8rrh-rw8j-w5fx | wheel (pip) | 0.45.1 | 0.46.2 |
| GHSA-58pv-8j8x-9vj2 | jaraco-context (pip) | 5.3.0 | 6.1.0 |
| multiple | cryptography (pip) | 44.0.3 | 46.0.7 |
| multiple | urllib3 (pip) | 1.26.20 | 2.6.3 |
| multiple | zipp (pip) | 3.17.0 | 3.23.1 |

---

**Last updated:** 2026-04-16
**License:** AGPL-3.0-or-later
