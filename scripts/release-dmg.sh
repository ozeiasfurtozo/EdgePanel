#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
: "${EDGE_SIGN_IDENTITY:?Set EDGE_SIGN_IDENTITY to a Developer ID Application certificate}"
: "${EDGE_NOTARY_PROFILE:?Set EDGE_NOTARY_PROFILE to a notarytool keychain profile}"
./scripts/build-app.sh
app=".build/EdgePanel.app"
codesign --force --options runtime --timestamp --sign "$EDGE_SIGN_IDENTITY" "$app/Contents/MacOS/m1ddc"
codesign --force --options runtime --timestamp --sign "$EDGE_SIGN_IDENTITY" "$app"
codesign --verify --strict --verbose=2 "$app"
mkdir -p .build/release-output
hdiutil create -volname EdgePanel -srcfolder "$app" -format UDZO -ov .build/release-output/EdgePanel.dmg
codesign --force --timestamp --sign "$EDGE_SIGN_IDENTITY" .build/release-output/EdgePanel.dmg
xcrun notarytool submit .build/release-output/EdgePanel.dmg --keychain-profile "$EDGE_NOTARY_PROFILE" --wait
xcrun stapler staple .build/release-output/EdgePanel.dmg
xcrun stapler validate .build/release-output/EdgePanel.dmg
echo "$PWD/.build/release-output/EdgePanel.dmg"
