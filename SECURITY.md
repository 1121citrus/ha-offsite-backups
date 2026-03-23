# Security Policy

## Security Design

The image is built with defence-in-depth from the ground up:

| Control | Implementation |
| --- | --- |
| Non-root execution | Dedicated `ha-offsite-backups` user, UID 10001, shell `/sbin/nologin` |
| Minimal base image | `alpine:3.21` — no package manager beyond apk, minimal utilities |
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

To report a security vulnerability, please email [security contact TBD] with:

- **Description:** What is the vulnerability?
- **Affected versions:** Which image tags are impacted?
- **Severity:** CRITICAL / HIGH / MEDIUM / LOW
- **Steps to reproduce:** How can the vulnerability be demonstrated?
- **Impact:** What can an attacker achieve?

We will acknowledge receipt within 48 hours and provide a timeline for remediation.

## Known Vulnerabilities

No CVEs are currently accepted. All images must pass `trivy image --severity HIGH,CRITICAL --exit-code 1` before release.

---

**Last updated:** 2026-03-23  
**License:** AGPL-3.0-or-later
