#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
: "${EDGE_SIGN_IDENTITY:?Set EDGE_SIGN_IDENTITY to a Developer ID Application certificate}"
: "${EDGE_NOTARY_PROFILE:?Set EDGE_NOTARY_PROFILE to a notarytool keychain profile}"
EDGE_LOCAL_SIGN_IDENTITY=- EDGE_ALLOW_ADHOC_SIGN=1 ./scripts/build-app.sh
sparkle_tools=".build/artifacts/sparkle/Sparkle/bin"
sparkle_account="${EDGE_SPARKLE_ACCOUNT:-edgepanel}"
expected_key=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' Resources/Info.plist)
actual_key=$("$sparkle_tools/generate_keys" --account "$sparkle_account" -p)
if [[ "$actual_key" != "$expected_key" ]]; then
  echo "Sparkle key in the Keychain does not match Resources/Info.plist" >&2
  exit 1
fi
app=".build/EdgePanel.app"
./scripts/sign-sparkle.sh "$app/Contents/Frameworks/Sparkle.framework" "$EDGE_SIGN_IDENTITY" release
codesign --force --options runtime --timestamp --sign "$EDGE_SIGN_IDENTITY" "$app/Contents/MacOS/m1ddc"
codesign --force --options runtime --timestamp --sign "$EDGE_SIGN_IDENTITY" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
mkdir -p .build/release-output
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
dmg=".build/release-output/EdgePanel-${version}.dmg"
stage=$(mktemp -d "$PWD/.build/release-output/dmg-root.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/EdgePanel.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname EdgePanel -srcfolder "$stage" -format UDZO -ov "$dmg"
codesign --force --timestamp --sign "$EDGE_SIGN_IDENTITY" "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$EDGE_NOTARY_PROFILE" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
./scripts/generate-appcast.sh "$dmg"
echo "$PWD/$dmg"
