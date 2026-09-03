# Security Policy

## Security Design

The image is built with defence-in-depth from the ground up:

| Control | Implementation |
| --- | --- |
| Non-root execution | Dedicated `ha-offsite-backups` user, UID 10001, shell `/sbin/nologin` |
| Minimal base image | `1121citrus/aws-backup-base` (Amazon Linux 2023, digest-pinned) |
| Supply-chain pinning | Minimum patched versions for Python dependencies; digest pinning for AL2023 base and version pinning for build tools |
| OS patch hygiene | AL2023 is upgraded at build time (`dnf upgrade`); pip constraints enforce minimum patched versions |
| Read-only filesystem | Configuration read from mounted secrets; use `--read-only --tmpfs /tmp` for runtime |
| Credential isolation | AWS credentials via `AWS_CONFIG_FILE` or Docker secrets; never exposed in startup logs |
| Cron isolation | Scheduled backups via supercronic; no manual script invocations in production |
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

As of aws-backup-base's 2026-09-03 AL2023 digest refresh (confirmed via a
fresh-DB Trivy rescan), one HIGH CVE is pending an upstream AL2023
package fix and temporarily suppressed in `.trivyignore`:

| CVE | Component | Fix version (not yet in AL2023 repos) |
| --- | --- | --- |
| CVE-2026-14456 | `openssl-fips-provider-latest` / `openssl-libs` (inherited from aws-backup-base) | `1:3.5.7-2.amzn2023.0.2` |

Remove the entry from `.trivyignore` (and this table) once the
corresponding fixed RPM is available in AL2023 and adopted by the image
build.

---

### Remediated Vulnerabilities

| CVE / Advisory | Component | Remediation |
| --- | --- | --- |
| Alpine APK CVEs (multiple) | `py3-jmespath`, `python3`, `py3-urllib3`, `py3-cryptography`, `supercronic` | Resolved by migrating base image from Alpine 3.22 to AL2023 (v1.0.7) |
| CVE-2026-24049 / GHSA-8rrh-rw8j-w5fx | wheel (pip) | Pinned `wheel>=0.48.0` in `requirements.txt` (v1.1.7) |
| GHSA-58pv-8j8x-9vj2 | jaraco-context (pip) | Pinned `jaraco-context>=6.1.2` in `requirements.txt` |
| multiple | zipp (pip) | Raised floor to `zipp>=4.1.0` in `requirements.txt` (2026-05-23) |
| CVE-2026-69247 | cryptography (pip) | Raised floor to `cryptography>=50.0.1` in `requirements.txt` (v1.1.7) |
| CVE-2026-21441, CVE-2025-66471, CVE-2025-66418, CVE-2026-44431 | urllib3 (pip) | Raised floor to `urllib3>=2.7.0` in `requirements.txt` (v1.0.10) |
| CVE-2026-4046 | glibc | AL2023 digest refresh in aws-backup-base v1.1.3 (2026-05-23) |
| CVE-2026-3644, CVE-2026-4224, CVE-2026-4786, CVE-2026-6100 | python3.12 | AL2023 digest refresh in aws-backup-base v1.1.3 (2026-05-23) |
| CVE-2026-3219, CVE-2026-6357 | python3.12-pip | AL2023 digest refresh in aws-backup-base v1.1.3 (2026-05-23) |
| CVE-2026-33811, CVE-2026-33814, CVE-2026-39820, CVE-2026-39836, CVE-2026-42499 | supercronic (Go stdlib) | Supercronic now compiled from source with `golang:1.26.3-alpine` in aws-backup-base v1.1.3 |
| CVE-2026-33818, CVE-2026-39821, CVE-2026-46600, CVE-2026-56853, CVE-2026-56858, CVE-2026-56859, CVE-2026-56860, CVE-2026-56862 | supercronic (Go stdlib) | Recompiled from source with `golang:1.27.0-alpine` and `supercronic v0.2.49` in aws-backup-base v1.2.1 |
| CVE-2026-33845 | gnutls | AL2023 digest refresh in aws-backup-base v1.2.0 (2026-07-21) |
| CVE-2026-48863, CVE-2026-48864, CVE-2026-9149, CVE-2026-9150 | libsolv | AL2023 digest refresh in aws-backup-base v1.2.0 (2026-07-21) |

---

**Last updated:** 2026-09-03
**License:** AGPL-3.0-or-later
