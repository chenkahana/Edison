#if canImport(Sparkle)
import Sparkle

/// Sparkle updates for copies installed from the DMG on GitHub Releases. It reads the newest release's
/// `appcast.xml` (`SUFeedURL` in Config/Info.plist) and installs a DMG only if its EdDSA signature matches
/// `SUPublicEDKey`. Sparkle asks before its first automatic check. `swift build` doesn't link Sparkle, so this
/// file is compiled only by the Xcode project. See docs/release.md.
@MainActor
final class Updater {
    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
#endif
