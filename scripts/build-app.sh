#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p .build/clang-module-cache .build/swiftpm-module-cache .build/cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swiftpm-module-cache"
export XDG_CACHE_HOME="$PWD/.build/cache"
swift build -c release -debug-info-format none --disable-sandbox --scratch-path .build
app=".build/EdgePanel.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/EdgePanel "$app/Contents/MacOS/EdgePanel"
mkdir -p .build/ddc
xcrun clang -arch arm64 -mmacosx-version-min=14.0 -Wall -Werror -Wextra -fmodules \
  -I ThirdParty/m1ddc/headers \
  ThirdParty/m1ddc/sources/i2c.m ThirdParty/m1ddc/sources/ioregistry.m ThirdParty/m1ddc/sources/m1ddc.m \
  -framework CoreDisplay -o .build/ddc/m1ddc
cp .build/ddc/m1ddc "$app/Contents/MacOS/m1ddc"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp Resources/StatusIcon.png "$app/Contents/Resources/StatusIcon.png"
cp LICENSE "$app/Contents/Resources/LICENSE"
cp THIRD_PARTY_NOTICES.md "$app/Contents/Resources/THIRD_PARTY_NOTICES.md"
plutil -lint "$app/Contents/Info.plist"
codesign --force --sign - "$app/Contents/MacOS/m1ddc"
codesign --force --sign - "$app"
mkdir -p dist
ditto "$app" dist/EdgePanel.app
codesign --verify --strict dist/EdgePanel.app
echo "$PWD/dist/EdgePanel.app"
