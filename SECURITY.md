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
| Vulnerability scanning | Trivy (Aqua) scans every CI build; fixable HIGH/CRITICAL CVEs block the pipeline. Grype and Docker Scout also scan every build (including MEDIUM severity) but do not block it — findings are reviewed manually and tracked here |

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

As of 2026-11-15, Trivy (all severities, including unfixed, no
`.trivyignore`) reports zero findings, and `.trivyignore` carries no
suppressions. Grype reports one finding, which `.grype.yaml` suppresses:
`urllib3` GHSA-q2q7-5pp4-w6pg (CVE-2021-33503), which AL2023 rates
"Not Affected".

`python3-urllib3` and `python3-idna` are runtime dependencies of
`awscli-2`. The installed builds (`python3-urllib3-1.25.10-5.amzn2023.0.9`,
`python3-idna-2.10-3.amzn2023.0.4`) are the latest that AL2023 publishes.
AL2023 backports fixes without changing the upstream `1.25.10` / `2.10`
version strings, so scanners that read package metadata report CVEs that
the installed RPMs already fix.

Docker Scout reports the following findings, which cannot be fixed in this
repository:

| CVE | Component | Why it remains |
| --- | --- | --- |
| CVE-2023-45803, CVE-2025-50181, CVE-2025-66418, CVE-2025-66471, CVE-2026-21441, CVE-2026-44431, CVE-2026-97689 | `urllib3` 1.25.10 | False positives. Each is listed as fixed in `rpm -q --changelog python3-urllib3` |
| CVE-2021-33503 (HIGH) | `urllib3` 1.25.10 | AL2023 rates the package "Not Affected". Suppressed in `.grype.yaml` |
| CVE-2023-43804 (HIGH), CVE-2024-37891 (MEDIUM) | `urllib3` 1.25.10 | Residual risk accepted. The RPM changelog does not list a fix, and AL2023 has no newer build. The AWS CLI only connects to AWS endpoints over HTTPS, which limits exposure to the cookie and proxy-header leaks these describe |
| CVE-2024-3651, CVE-2026-45409 | `idna` 2.10 | False positives. Each is listed as fixed in `rpm -q --changelog python3-idna` |
| CVE-2026-19617 (MEDIUM) | `lvm2` / `device-mapper-libs` | False positive. Scout compares the `device-mapper-libs` version (`1.02.185-1.amzn2023.0.6`) against the `lvm2` source package version. The installed RPM is built from `lvm2-2.03.16-1.amzn2023.0.6.src.rpm`, which is the fixed version Scout names |
| CVE-2026-97054 (unspecified) | Go `stdlib` `1.27.3` | Unreachable. It is the `supercronic` binary in an `aws-backup-base:latest` layer that this image overwrites with its own Go 1.27.4 build; Scout indexes every layer. Clears when `aws-backup-base` is next published |

If a new finding has no fixed AL2023 build (confirm with
`dnf --releasever=latest list --showduplicates <pkg>`), add it to
`.trivyignore`/`.grype.yaml` with a dated justification and list it here.

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
| CVE-2026-14456 | openssl-fips-provider-latest / openssl-libs | Resolved by aws-backup-base 1.2.2's 2026-10-28 AL2023 digest refresh |
| 351 Grype/Scout findings (0 CRITICAL, 92 HIGH, 255 MEDIUM, 4 LOW) across `perl`/`perl-*`, `python3-pygments`, `python3-setuptools(-wheel)`, `python3.12-setuptools`, `python3.12-pip(-wheel)`, `python3-pip-wheel` | perl, pygments, setuptools, pip | Removed entirely from the image (v1.1.8): none has a runtime dependent (`rpm -q --whatrequires`) and nothing in `src/`/`include/`/`test/` invokes python, pip, perl, or pygments — `aws s3 sync` and the cron/healthcheck scripts never needed them. Reduced open findings from 351 to 35, all in the 11-package AL2023 repo-mirror-gap list above |
| CVE-2025-66471, CVE-2025-66418, CVE-2026-21441, CVE-2026-44431, CVE-2026-97689 | python3-urllib3 | Confirmed false positives via `rpm -q --changelog python3-urllib3`: AL2023 backports these fixes without bumping the "1.25.10" version string that Grype/Scout match against |
| CVE-2026-86805 | glibc / glibc-common / glibc-minimal-langpack | `dnf upgrade --releasever=latest` (2026-11-15) |
| CVE-2026-103242, CVE-2026-84837, CVE-2026-95519, CVE-2026-95520, CVE-2026-95521 | rpm family / python3-rpm | `dnf upgrade --releasever=latest` (2026-11-15) |
| CVE-2026-119371, CVE-2026-119372, CVE-2026-119373, CVE-2026-119375, CVE-2026-119376, CVE-2026-119378 | sqlite-libs | `dnf upgrade --releasever=latest` (2026-11-15) |
| ALAS2023-2026-3267, -3290, -3255, -3269, -3278, -3230, -3306 (CVE-2026-92392, CVE-2026-107161, CVE-2026-78659, CVE-2026-78667, CVE-2026-94440, CVE-2026-103111, CVE-2026-86145, CVE-2026-89156, CVE-2026-89160, CVE-2026-19553, CVE-2026-15310, CVE-2026-15806, CVE-2026-17084, CVE-2026-19445, CVE-2026-19672, CVE-2026-82049, CVE-2026-87910, CVE-2026-113470, CVE-2026-114406) | curl, cyrus-sasl, libcap, pcre2, python3, python3.12, ca-certificates | Fixed RPMs reached via `dnf upgrade --releasever=latest`; suppressions removed (2026-11-15) |
| GO-2026-6859 | supercronic (Go stdlib) | Rebuilt in this image with `golang:1.27.4-alpine` (2026-11-15) |

---

**Last updated:** 2026-11-15
**License:** AGPL-3.0-or-later
