#!/bin/zsh
set -euo pipefail

framework="$1"
identity="$2"
mode="${3:-local}"
sign_options=(--force --sign "$identity")
if [[ "$mode" == release ]]; then
  sign_options+=(--options runtime --timestamp)
fi

# Sparkle's helpers are nested code. Sign from the inside out; --deep would
# overwrite the Downloader service's entitlements.
codesign "${sign_options[@]}" "$framework/Versions/B/XPCServices/Installer.xpc"
codesign "${sign_options[@]}" --preserve-metadata=entitlements "$framework/Versions/B/XPCServices/Downloader.xpc"
codesign "${sign_options[@]}" "$framework/Versions/B/Autoupdate"
codesign "${sign_options[@]}" "$framework/Versions/B/Updater.app"
codesign "${sign_options[@]}" "$framework"
