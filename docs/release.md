# Releasing Edison

Each release puts a notarized `Edison.dmg` on [GitHub Releases](https://github.com/chenkahana/Edison/releases).
The README's **Download for Mac** button links to `releases/latest/download/Edison.dmg`, so it always points at the
newest release.

A release is built on a maintainer's Mac with [`scripts/release-dmg.sh`](../scripts/release-dmg.sh). Signing with
Developer ID and notarization go through the Apple account signed in to Xcode, and the update signing key stays in
that Mac's login keychain, so the repository and its CI hold no certificates or keys.

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
| `Edison DMG` | `Edison.dmg` on GitHub Releases (`release-dmg.sh` archives it) | linked, with `Config/Info.plist`, `Config/Edison.entitlements` and the `SPARKLE` compilation condition that compiles [`Updater.swift`](../Edison/App/Updater.swift) |

Both have the same bundle ID and product name, so install one copy at a time in `/Applications`. `swift build` and
`swift test` don't resolve Sparkle. CI archives the App Store target and fails if `Sparkle.framework` is inside.

Copies built before 2.1 have no updater, so people on those versions download the DMG once. From 2.1 on, updates
arrive in the app.

## Before the first release on a Mac

- Xcode › Settings › Accounts is signed in to an account with the Account Holder or Admin role on team `DPF8459C2J`.
  The first export creates the team's Developer ID certificate in the cloud.
- The GitHub CLI is installed and signed in (`gh auth login`) with write access to the repository.
- Sparkle's EdDSA private key is in the login keychain, and its public half is `SUPublicEDKey` in
  `Config/Info.plist`. Edison shares the maintainer's Sparkle key with their other apps. To check it, or to create
  the key on a Mac that has none, build once so the package is downloaded, then run the package's `generate_keys`
  (under `SourcePackages/artifacts/sparkle/Sparkle/bin/`). It prints the public key.

  On another Mac, move the key with `generate_keys -x <file>` and `generate_keys -f <file>` instead of making a new
  one: installed copies only accept updates signed with the key they carry. Never commit the private key.
  `release-dmg.sh` stops if the public key in the app isn't the one in the keychain.

## Each release

1. In `CHANGELOG.md`, change `## X.Y — unreleased` to `## X.Y — YYYY-MM-DD`, and merge.
2. Tag the merge commit and push: `git tag -a vX.Y -m "Edison X.Y" && git push origin vX.Y`.
3. Check out the tag (`git checkout vX.Y`) and run `scripts/release-dmg.sh X.Y`. It:
   1. archives Edison with that version;
   2. signs it with Developer ID and waits for Apple's notarization, which takes a few minutes;
   3. builds `Edison.dmg` and signs it with the Sparkle key (`sign_update`, which may ask for keychain access);
   4. writes `appcast.xml`;
   5. publishes the GitHub release with the DMG, its checksum and the appcast, using the changelog section as the
      release notes.

   Installed copies see the update on their next check.

To build the DMG without publishing it, run `scripts/release-dmg.sh X.Y --no-publish`. The DMG and appcast go to
`build/release/`.

## Notes

- The app inside the DMG is signed, notarized and stapled. The DMG itself isn't code-signed (Xcode keeps the
  Developer ID key in the cloud). Gatekeeper doesn't require that, and Sparkle checks the DMG's EdDSA signature before
  opening it (`SUVerifyUpdateBeforeExtraction`).
- Sparkle compares build numbers (`CFBundleVersion`). The script sets the build number to the release time, so each
  release is newer than the last, and newer than any local build.
