# Security Policy

## Security Design

The image is built with defence-in-depth from the ground up:

| Control | Implementation |
| --- | --- |
| Non-root execution | Dedicated `ha-offsite-backups` user, UID 10001, shell `/sbin/nologin` |
| Minimal base image | `1121citrus/aws-backup-base` (Amazon Linux 2023, digest-pinned) |
| Supply-chain pinning | All dependencies pinned to specific versions; digest pinning for AL2023 base |
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

The following HIGH-severity CVEs have no available fix and are accepted in
`.trivyignore` pending upstream releases. Each entry is removed as soon as the
fixed package lands.

#### `python3.12-pip` — AL2023 package (not yet patched in repo)

| CVE | Severity | Fixed version | Status |
| --- | --- | --- | --- |
| CVE-2026-3219 | HIGH | `23.2.1-4.amzn2023.0.9` | Fix identified; not yet in AL2023 repo (current: `.0.8`) |
| CVE-2026-6357 | HIGH | `23.2.1-4.amzn2023.0.9` | Fix identified; not yet in AL2023 repo (current: `.0.8`) |

#### `supercronic` — embedded Go stdlib (no new release yet)

Supercronic v0.2.45 (latest) embeds a Go stdlib with multiple HIGH CVEs fixed
in Go ≥ 1.25.10 / ≥ 1.26.3. A new supercronic release built against the
patched runtime is required; none is available yet.

| CVE | Severity | Description |
| --- | --- | --- |
| CVE-2026-33811 | HIGH | `LookupCNAME` memory issue via cgo DNS resolver |
| CVE-2026-33814 | HIGH | HTTP/2 SETTINGS frame processing hang |
| CVE-2026-39820 | HIGH | DoS via malformed input in `ParseAddress`/`ParseAddressList` |
| CVE-2026-39836 | HIGH | Panic in `Dial`/`LookupPort` on NUL byte input |
| CVE-2026-42499 | HIGH | DoS via pathological input in `consumePhrase` |

Supercronic is used solely as a cron scheduler; it processes no external network
input in this application, which substantially limits the practical exposure.

#### `python3.12` / `python3.12-pip` — CPython (fix not yet in AL2023 repo)

| CVE | Severity | Description |
| --- | --- | --- |
| CVE-2026-3644 | HIGH | Incomplete control-char validation in `http.cookies` |
| CVE-2026-4224 | HIGH | Stack overflow parsing XML with deeply nested DTD |
| CVE-2026-4786 | HIGH | Arbitrary code execution via `webbrowser.open()` command injection |
| CVE-2026-6100 | HIGH | Use-after-free in decompression (arbitrary code execution / info disclosure) |

#### `glibc` — AL2023 package (fix not yet in AL2023 repo)

| CVE | Severity | Description |
| --- | --- | --- |
| CVE-2026-4046 | HIGH | DoS via `iconv()` — fix `2.34-231.amzn2023.0.4` not yet in repo |

---

### Remediated Vulnerabilities

| CVE / Advisory | Component | Remediation |
| --- | --- | --- |
| Alpine APK CVEs (multiple) | `py3-jmespath`, `python3`, `py3-urllib3`, `py3-cryptography`, `supercronic` | Resolved by migrating base image from Alpine 3.22 to AL2023 (v1.0.7) |
| CVE-2026-24049 / GHSA-8rrh-rw8j-w5fx | wheel (pip) | Pinned `wheel>=0.47.0` in `requirements.txt` |
| GHSA-58pv-8j8x-9vj2 | jaraco-context (pip) | Pinned `jaraco-context>=6.1.2` in `requirements.txt` |
| multiple | zipp (pip) | Raised floor to `zipp>=4.1.0` in `requirements.txt` (2026-05-23) |
| multiple | cryptography (pip) | Raised floor to `cryptography>=48.0.0` in `requirements.txt` (v1.0.10) |
| CVE-2026-21441, CVE-2025-66471, CVE-2025-66418, CVE-2026-44431 | urllib3 (pip) | Raised floor to `urllib3>=2.7.0` in `requirements.txt` (v1.0.10) |

---

**Last updated:** 2026-05-23
**License:** AGPL-3.0-or-later
