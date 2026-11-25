# Releasing Edison

Each release puts a notarized `Edison.dmg` on [GitHub Releases](https://github.com/chenkahana/Edison/releases).
The README's **Download for Mac** button links to `releases/latest/download/Edison.dmg`, so it always points at the
newest release.

Every commit to `main` that changes the app (`Edison/`, `Config/`, `Assets.xcassets/`, `Edison.xcodeproj/`) is
released by [`.github/workflows/release.yml`](../.github/workflows/release.yml) on a GitHub-hosted Mac with Xcode 27.
It archives the `Edison DMG` scheme, signs it with the team's Developer ID certificate, has Apple notarize it, and
creates the release `vX.Y.Z` with `Edison.dmg`, its checksum and the `appcast.xml` that installed copies read.

## Updates

Installed copies update themselves with [Sparkle 2](https://sparkle-project.org). Sparkle asks on the second launch
whether to check automatically. It then checks once a day, and whenever someone chooses **Check for Updates…** from
the menu-bar icon. It reads `appcast.xml` from the newest GitHub release (`releases/latest/download/appcast.xml`),
and installs a newer DMG only if the DMG's EdDSA signature matches the public key the app carries (`SUPublicEDKey`).

Edison is sandboxed and has no network entitlement, so Sparkle's own XPC services do the work. The downloader
service fetches the feed and the DMG (`SUEnableDownloaderService`). The installer runs outside the sandbox through
its launcher service (`SUEnableInstallerLauncherService`, with the mach-lookup exceptions `<bundle ID>-spks` and
`-spki` in [`Config/Edison.entitlements`](../Config/Edison.entitlements)). The Sparkle keys are in
[`Config/Info.plist`](../Config/Info.plist), which Xcode merges into the generated Info.plist.

Sparkle is only in the DMG. The Xcode project has two targets built from the same sources:

| Target | Ships as | Sparkle |
|---|---|---|
| `Edison` | the App Store build (archive this scheme for App Store Connect) | none: App Store Connect rejects Sparkle's unsandboxed helpers, and the App Store updates the app itself |
| `Edison DMG` | `Edison.dmg` on GitHub Releases (the release workflow archives it) | linked, with `Config/Info.plist`, `Config/Edison.entitlements` and the `SPARKLE` compilation condition that compiles [`Updater.swift`](../Edison/App/Updater.swift) |

Both have the same bundle ID and product name, so install one copy at a time in `/Applications`. `swift build` and
`swift test` don't resolve Sparkle. CI archives the App Store target and fails if `Sparkle.framework` is inside.

Copies built before 2.1 have no updater, so people on those versions download the DMG once. From 2.1 on, updates
arrive in the app.

## Versions

- If CHANGELOG.md's newest section, `## X.Y.Z — YYYY-MM-DD`, is newer than every `v*` tag, the release is that
  version, with that section as its notes. So a pull request with user-visible changes adds a new section at the top
  (the next patch, or a minor version for a feature).
- Otherwise the release is the next patch after the newest tag (2.2 → 2.2.1 → 2.2.2), with the commit's subject as
  its notes.
- A newest section still marked `unreleased` stops the release: give it the date.
- The build number (`CFBundleVersion`, which Sparkle compares) is the release time in UTC, `YYYYMMDDHHMM`, so each
  release is newer than the last. CI never edits CHANGELOG.md.

To build, sign and notarize without publishing, run the workflow by hand (Actions › Release › Run workflow) with
`dry_run` checked, the default. The DMG and appcast are kept as a workflow artifact for three days. Running it with
`dry_run` unchecked on `main` publishes, which also re-releases a commit whose release failed.

## Secrets

The workflow stops before building, listing any that are missing:

| Secret | What it is |
|---|---|
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` | An App Store Connect team API key (Users and Access › Integrations › Team Keys) with the Admin role. `ASC_KEY_P8` is the text of the downloaded `AuthKey_KEYID.p8`. It finds the certificate and notarizes |
| `DEVELOPER_ID_KEY` | The unencrypted PEM private key of a Developer ID Application certificate on team `DPF8459C2J`. [`scripts/developer-id.py`](../scripts/developer-id.py) finds the certificate whose public key matches, so no certificate ID is configured |
| `SPARKLE_ED_PRIVATE_KEY` | Sparkle's EdDSA private key, as `generate_keys -x` writes it. The workflow checks the DMG's signature against `SUPublicEDKey` |

Set them from the maintainer's Mac with [`scripts/set-release-secrets.sh`](../scripts/set-release-secrets.sh):

```sh
scripts/set-release-secrets.sh --issuer ISSUER_ID [--asc-key ~/Downloads/AuthKey_KEYID.p8] [--developer-id-key KEY.pem]
```

It takes the API key from `--asc-key`, or the one `AuthKey_*.p8` in `~/Downloads` or `~/.appstoreconnect/private_keys`.
Without `--developer-id-key` it makes a new private key and has Apple issue a Developer ID Application certificate
for it through the API key; if Apple refuses, it keeps the request and says where to upload it. It exports the Sparkle
key from the login keychain after checking it is the one behind `SUPublicEDKey` (macOS may ask to allow that). It
never prints a key, and deletes the copies it made. When the certificate expires or is revoked, run it again.

Edison's entitlements (the sandbox, read-only user-selected files and Sparkle's mach-lookup exceptions) need no
provisioning profile, so the workflow signs manually with the imported identity.

The App Store target doesn't release this way: archive the `Edison` scheme for App Store Connect as before.

## Releasing from a Mac

[`scripts/release-dmg.sh`](../scripts/release-dmg.sh) is the fallback when the workflow can't run. It signs and
notarizes through the Apple account signed in to Xcode (Settings › Accounts, Account Holder or Admin on team
`DPF8459C2J`) and the Sparkle key in the login keychain, and publishes with the GitHub CLI.

1. Date the version's CHANGELOG section, merge, tag the merge commit and push the tag:
   `git tag -a vX.Y.Z -m "Edison X.Y.Z" && git push origin vX.Y.Z`.
2. Check out the tag and run `scripts/release-dmg.sh X.Y.Z`; `--no-publish` builds into `build/release/` only.

On another Mac, move the Sparkle key with `generate_keys -x <file>` and `generate_keys -f <file>` instead of making a
new one: installed copies only accept updates signed with the key they carry. Never commit a private key.

## Notes

- The app inside the DMG is signed, notarized and stapled. The DMG itself isn't code-signed. Gatekeeper doesn't
  require that, and Sparkle checks the DMG's EdDSA signature before opening it (`SUVerifyUpdateBeforeExtraction`).
- Before publishing, the workflow checks that Gatekeeper reports the app as "Notarized Developer ID", the ticket is
  stapled, the version and build number are the chosen ones, and the Sparkle signature verifies.
