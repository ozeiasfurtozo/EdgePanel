#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
local_identity="${EDGE_LOCAL_SIGN_IDENTITY:-}"
if [[ -z "$local_identity" && -f .edgepanel-signing-identity ]]; then
  local_identity=$(<.edgepanel-signing-identity)
  if [[ ! "$local_identity" =~ '^[0-9A-Fa-f]{40}$' ]]; then
    echo ".edgepanel-signing-identity must contain one 40-character certificate SHA-1 fingerprint." >&2
    exit 1
  fi
fi
if [[ -z "$local_identity" ]]; then
  if [[ "${EDGE_ALLOW_ADHOC_SIGN:-}" == 1 ]]; then
    local_identity="-"
    echo "Warning: this explicit ad-hoc build will lose privacy permissions after a code change." >&2
  else
    echo "No stable EdgePanel code-signing identity was found." >&2
    echo "Set EDGE_LOCAL_SIGN_IDENTITY to an existing identity, or put its SHA-1 fingerprint in .edgepanel-signing-identity." >&2
    echo "For a disposable test build only, set EDGE_ALLOW_ADHOC_SIGN=1." >&2
    exit 1
  fi
fi
if [[ "$local_identity" == "-" && "${EDGE_ALLOW_ADHOC_SIGN:-}" != 1 ]]; then
  echo "Ad-hoc signing requires EDGE_ALLOW_ADHOC_SIGN=1 because it does not preserve permissions." >&2
  exit 1
fi
mkdir -p .build/clang-module-cache .build/swiftpm-module-cache .build/cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swiftpm-module-cache"
export XDG_CACHE_HOME="$PWD/.build/cache"
swift build -c release -debug-info-format none --disable-sandbox --scratch-path .build
app=".build/EdgePanel.app"
sparkle_framework=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
test -d "$sparkle_framework"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp .build/release/EdgePanel "$app/Contents/MacOS/EdgePanel"
ditto "$sparkle_framework" "$app/Contents/Frameworks/Sparkle.framework"
mkdir -p .build/ddc
xcrun clang -arch arm64 -mmacosx-version-min=14.0 -Wall -Werror -Wextra -fmodules \
  -I ThirdParty/m1ddc/headers \
  ThirdParty/m1ddc/sources/i2c.m ThirdParty/m1ddc/sources/ioregistry.m ThirdParty/m1ddc/sources/m1ddc.m \
  -framework CoreDisplay -o .build/ddc/m1ddc
cp .build/ddc/m1ddc "$app/Contents/MacOS/m1ddc"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp Resources/StatusIcon.png "$app/Contents/Resources/StatusIcon.png"
cp Resources/PrivacyInfo.xcprivacy "$app/Contents/Resources/PrivacyInfo.xcprivacy"
cp LICENSE "$app/Contents/Resources/LICENSE"
cp THIRD_PARTY_NOTICES.md "$app/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp ThirdParty/Sparkle/LICENSE "$app/Contents/Resources/SPARKLE_LICENSE"
plutil -lint "$app/Contents/Info.plist"
plutil -lint "$app/Contents/Resources/PrivacyInfo.xcprivacy"
./scripts/sign-sparkle.sh "$app/Contents/Frameworks/Sparkle.framework" "$local_identity"
codesign --force --sign "$local_identity" "$app/Contents/MacOS/m1ddc"
codesign --force --sign "$local_identity" "$app"
mkdir -p dist
ditto "$app" dist/EdgePanel.app
codesign --verify --deep --strict dist/EdgePanel.app
echo "$PWD/dist/EdgePanel.app"
