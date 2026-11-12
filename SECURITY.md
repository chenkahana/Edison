# Security Policy

Edison handles some of the most sensitive data on a Mac: everything you copy, and pictures of your screen. Reports
that help keep that data safe are very welcome.

## Supported versions

Security fixes go into the latest release only.

| Version | Supported |
|---|---|
| 2.x | ✓ |
| < 2.0 | ✗ |

## Reporting a vulnerability

Please **do not** open a public issue. Report privately through
[GitHub Security Advisories](https://github.com/chenkahana/Edison/security/advisories/new) ("Report a
vulnerability" in the repository's Security tab). Include:

- what the issue is and what an attacker could do with it,
- the Edison and macOS versions,
- steps to reproduce, or a proof of concept,
- a suggested fix, if you have one.

You can expect an acknowledgement within 7 days and a fix or mitigation plan within 30 days. Please give us a
reasonable chance to ship a fix before disclosing publicly; we're happy to credit you in the release notes.

## Scope

Edison is a local-only, sandboxed macOS app with no backend, no accounts and no network code of its own; its only
connection is Sparkle's update check against GitHub Releases. In scope:

- other processes or users reading Edison's history, screenshots or temporary files,
- clipboard items marked concealed or transient (for example by password managers) being stored,
- deleted items, or items copied while history is paused, persisting anywhere on disk,
- content leaking into logs, notifications, crash reports or diagnostics exports,
- paste-back or the Accessibility integration being abused to send input to unintended apps,
- weaknesses in the sandbox, hardened runtime or entitlement configuration.

Out of scope: attacks that already require full control of the user's account, and issues in macOS itself (report
those to [Apple](https://security.apple.com)).

## Hardening already in place

- App Sandbox and hardened runtime are enabled; the app has no network entitlement. Updates are fetched by
  Sparkle's sandboxed downloader service and installed only if their EdDSA signature matches the key in the app.
- Concealed and transient pasteboard items are skipped; history can be paused.
- Logs contain error descriptions only, never clipboard or screenshot content.
- Scratch files for previews and drag-out live in an owner-only folder that is cleared when they close and on launch.
- CI runs with read-only permissions and pinned actions.
