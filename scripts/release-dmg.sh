#!/bin/bash
# Releases Edison: signs it with Developer ID, has Apple notarize it, and publishes Edison.dmg on the GitHub release
# for tag vVERSION, with the appcast.xml that Sparkle in installed copies reads to update them. Signing and
# notarization go through the Apple account signed in to Xcode (Settings › Accounts), and Sparkle's EdDSA key stays in
# this Mac's login keychain, so no certificates or keys are kept anywhere else. See docs/release.md.
#
#   scripts/release-dmg.sh 2.1 [--no-publish]
set -euo pipefail

VERSION=${1:?usage: scripts/release-dmg.sh VERSION [--no-publish]}
PUBLISH=${2:-}
TAG=v$VERSION
TEAM_ID=DPF8459C2J
APP_NAME="Edison - Clipboard Manager.app"
OUT=build/release
ARCHIVE=$OUT/Edison.xcarchive
BUILD=$(date +%Y%m%d%H%M)
# Where the archive resolves Sparkle, whose package carries sign_update and generate_keys.
PACKAGES=$OUT/SourcePackages
SPARKLE_BIN=$PACKAGES/artifacts/sparkle/Sparkle/bin

cd "$(dirname "$0")/.."
NOTES=$(mktemp)
# The release notes are the CHANGELOG section "## VERSION — YYYY-MM-DD".
awk -v v="$VERSION" 'index($0, "## " v " — ") == 1 {on=1; next} on && /^## / {exit} on' CHANGELOG.md > "$NOTES"
if [ "$PUBLISH" != "--no-publish" ]; then
    ! grep -q "^## $VERSION — unreleased" CHANGELOG.md || {
        echo "CHANGELOG.md still says $VERSION is unreleased: date it first."; exit 1; }
    [ -s "$NOTES" ] || { echo "CHANGELOG.md has no \"## $VERSION — YYYY-MM-DD\" section."; exit 1; }
    git fetch -q origin tag "$TAG" 2>/dev/null || { echo "Tag $TAG isn't on GitHub yet: tag the release commit first."; exit 1; }
    [ "$(git rev-parse HEAD)" = "$(git rev-parse "$TAG^{commit}")" ] || { echo "Check out $TAG first."; exit 1; }
fi
rm -rf "$OUT" && mkdir -p "$OUT"
mv "$NOTES" "$OUT/notes.md"

echo "==> Archiving Edison $VERSION"
xcodebuild archive -project Edison.xcodeproj -scheme Edison -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates -quiet \
    -clonedSourcePackagesDirPath "$PACKAGES" MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD"

# An update installs only on copies that carry the public half of the key it was signed with.
KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$ARCHIVE/Products/Applications/$APP_NAME/Contents/Info.plist")
[ "$KEY" = "$("$SPARKLE_BIN/generate_keys" -p)" ] || {
    echo "SUPublicEDKey in Config/Info.plist isn't the public half of this Mac's Sparkle key (docs/release.md)."; exit 1; }

echo "==> Signing with Developer ID and sending to Apple for notarization"
cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>teamID</key><string>$TEAM_ID</string>
    <key>signingStyle</key><string>automatic</string>
    <key>destination</key><string>upload</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT/upload" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates -quiet

echo "==> Waiting for notarization"
# Usually minutes; give up after an hour and show why the last attempt failed.
for attempt in $(seq 120); do
    xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath "$OUT/export" -quiet 2> "$OUT/notarize.log" && break
    # Apple turning the app down won't change by waiting.
    grep -qiE "invalid|rejected" "$OUT/notarize.log" && { echo "Notarization failed:"; tail -20 "$OUT/notarize.log"; exit 1; }
    [ "$attempt" = 120 ] && { echo "Notarization didn't finish within an hour:"; tail -20 "$OUT/notarize.log"; exit 1; }
    sleep 30
done
APP=$OUT/export/$APP_NAME
xcrun stapler validate "$APP"
spctl --assess --type execute "$APP"

echo "==> Making the DMG"
mkdir -p "$OUT/dmg"
cp -R "$APP" "$OUT/dmg/"
ln -s /Applications "$OUT/dmg/Applications"
hdiutil create -volname Edison -srcfolder "$OUT/dmg" -fs HFS+ -format UDZO -ov "$OUT/Edison.dmg" -quiet
(cd "$OUT" && shasum -a 256 Edison.dmg > Edison.dmg.sha256 && cat Edison.dmg.sha256)

echo "==> Signing the DMG for Sparkle and writing the appcast"
# sign_update reads the EdDSA private key from the login keychain and prints only the signature.
SIGNATURE=$("$SPARKLE_BIN/sign_update" -p "$OUT/Edison.dmg")
cat > "$OUT/appcast.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Edison</title>
        <item>
            <title>Edison $VERSION</title>
            <pubDate>$(LC_ALL=C date -R)</pubDate>
            <sparkle:version>$BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <sparkle:releaseNotesLink>https://github.com/chenkahana/Edison/releases/tag/$TAG</sparkle:releaseNotesLink>
            <enclosure url="https://github.com/chenkahana/Edison/releases/download/$TAG/Edison.dmg"
                       length="$(stat -f%z "$OUT/Edison.dmg")" type="application/octet-stream"
                       sparkle:edSignature="$SIGNATURE"/>
        </item>
    </channel>
</rss>
EOF

[ "$PUBLISH" = "--no-publish" ] && { echo "Built $OUT/Edison.dmg and $OUT/appcast.xml (not published)."; exit 0; }

echo "==> Publishing $TAG"
printf '\n---\nOpen the DMG and drag Edison to Applications. Requires macOS 14 or later. Signed with Developer ID and notarized by Apple. Installed copies update themselves from here on.\n' \
    >> "$OUT/notes.md"
# Installed copies read the newest release's appcast: releases/latest/download/appcast.xml (SUFeedURL).
gh release create "$TAG" "$OUT/Edison.dmg" "$OUT/Edison.dmg.sha256" "$OUT/appcast.xml" --title "Edison $VERSION" \
    --notes-file "$OUT/notes.md" --verify-tag
