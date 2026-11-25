#!/bin/bash
# Gives the release workflow (.github/workflows/release.yml) its signing secrets on chenkahana/Edison. Run it
# yourself on the maintainer's Mac; it never prints a key. See docs/release.md.
#
#   scripts/set-release-secrets.sh --issuer ISSUER_ID [--asc-key AuthKey_KEYID.p8] [--developer-id-key KEY.pem]
#
# - ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8: an App Store Connect team API key (Admin role). Without --asc-key, the one
#   AuthKey_*.p8 in ~/Downloads, ~/.appstoreconnect/private_keys, ~/private_keys or ~/.private_keys.
# - DEVELOPER_ID_KEY: the private key of a Developer ID Application certificate. Without --developer-id-key, a new key
#   is made here and Apple issues its certificate through the API key.
# - SPARKLE_ED_PRIVATE_KEY: Sparkle's EdDSA key from the login keychain, checked against SUPublicEDKey.
set -euo pipefail
set +x

REPO=chenkahana/Edison
cd "$(dirname "$0")/.."

issuer=${ASC_ISSUER_ID:-}
asc_key=
developer_id_key=
while [ $# -gt 0 ]; do
    case $1 in
        --issuer) issuer=$2; shift 2 ;;
        --asc-key) asc_key=$2; shift 2 ;;
        --developer-id-key) developer_id_key=$2; shift 2 ;;
        *) sed -n '5p' "$0" | sed 's/^# *//' >&2; exit 2 ;;
    esac
done
[ -n "$issuer" ] || { echo "Pass --issuer: the issuer ID above the key list in App Store Connect › Users and Access › Integrations." >&2; exit 2; }

if [ -z "$asc_key" ]; then
    found=()
    for dir in ~/Downloads ~/.appstoreconnect/private_keys ~/private_keys ~/.private_keys; do
        for file in "$dir"/AuthKey_*.p8; do [ -f "$file" ] && found+=("$file"); done
    done
    [ "${#found[@]}" = 1 ] || {
        echo "Found ${#found[@]} AuthKey_*.p8 files; pass the App Store Connect key with --asc-key." >&2; exit 2; }
    asc_key=${found[0]}
fi
key_id=$(basename "$asc_key" | sed -n 's/^AuthKey_\([A-Z0-9]*\)\.p8$/\1/p')
[ -n "$key_id" ] || { echo "$asc_key isn't named AuthKey_KEYID.p8, as App Store Connect downloads it." >&2; exit 2; }
grep -q -- '-----BEGIN PRIVATE KEY-----' "$asc_key" || { echo "$asc_key isn't a .p8 private key." >&2; exit 2; }

gh auth status > /dev/null
[ "$(gh api "repos/$REPO" --jq .permissions.push)" = true ] || { echo "The signed-in gh account can't write to $REPO." >&2; exit 1; }

umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "==> Finding Sparkle's generate_keys"
generate_keys=
for file in build/release/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys \
    ~/Library/Developer/Xcode/DerivedData/*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys; do
    [ -x "$file" ] && { generate_keys=$file; break; }
done
if [ -z "$generate_keys" ]; then
    xcodebuild -resolvePackageDependencies -project Edison.xcodeproj -scheme "Edison DMG" \
        -clonedSourcePackagesDirPath "$work/SourcePackages" -quiet
    generate_keys=$work/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
fi
[ "$("$generate_keys" -p)" = "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' Config/Info.plist)" ] || {
    echo "The login keychain's Sparkle key isn't the one behind SUPublicEDKey in Config/Info.plist." >&2; exit 1; }

echo "==> Checking the App Store Connect key"
export ASC_KEY_PATH=$asc_key ASC_KEY_ID=$key_id ASC_ISSUER_ID=$issuer
if [ -n "$developer_id_key" ]; then
    grep -q -- '-----BEGIN PRIVATE KEY-----' "$developer_id_key" || {
        echo "$developer_id_key isn't an unencrypted PEM private key (-----BEGIN PRIVATE KEY-----)." >&2; exit 2; }
    python3 scripts/developer-id.py check --key "$developer_id_key"
else
    echo "==> Making a Developer ID Application certificate"
    developer_id_key=$work/developer-id.key
    /usr/bin/openssl req -new -newkey rsa:2048 -nodes -keyout "$developer_id_key" -out "$work/developer-id.csr" \
        -subj "/CN=Edison release workflow/C=IL" 2> /dev/null
    if ! python3 scripts/developer-id.py create --csr "$work/developer-id.csr"; then
        kept=~/tmp/edison-developer-id
        mkdir -p "$kept" && mv "$developer_id_key" "$work/developer-id.csr" "$kept/"
        echo "Apple didn't issue the certificate through the API. Upload $kept/developer-id.csr at" >&2
        echo "https://developer.apple.com/account/resources/certificates/add (Developer ID Application, G2 Sub-CA)," >&2
        echo "then run this again with --developer-id-key $kept/developer-id.key, and delete $kept." >&2
        exit 1
    fi
fi

echo "==> Setting the secrets on $REPO"
gh secret set ASC_KEY_ID -R "$REPO" --body "$key_id"
gh secret set ASC_ISSUER_ID -R "$REPO" --body "$issuer"
gh secret set ASC_KEY_P8 -R "$REPO" < "$asc_key"
gh secret set DEVELOPER_ID_KEY -R "$REPO" < "$developer_id_key"
# macOS may ask to let generate_keys read the key from the login keychain.
"$generate_keys" -x "$work/sparkle.key" > /dev/null
gh secret set SPARKLE_ED_PRIVATE_KEY -R "$REPO" < "$work/sparkle.key"
gh secret list -R "$REPO"
echo "Done. Delete $asc_key once it's stored somewhere safe: App Store Connect lets you download it only once."
