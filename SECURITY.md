# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.1.x   | ✓         |
| < 1.1   | ✗         |

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Report vulnerabilities by opening a [GitHub Security Advisory](../../security/advisories/new) in this repository. Include:

- A clear description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We aim to acknowledge reports within **7 days** and provide a resolution or mitigation plan within **14 days**.

## Scope

Edison is a local-first macOS app with no backend, no accounts, and no external data transmission. All clipboard and screenshot data remains on your device. Security concerns in scope include:

- Local privilege escalation
- Sandbox escape
- Unauthorized access to clipboard/screenshot data by other processes
- Privacy leaks via IPC or notifications
