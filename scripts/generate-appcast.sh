#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

archive="${1:?Pass the signed and notarized EdgePanel-version.dmg}"
test -f "$archive"
filename="${archive:t}"
if [[ "$filename" != EdgePanel-*.dmg ]]; then
  echo "Expected EdgePanel-version.dmg" >&2
  exit 1
fi
version="${filename#EdgePanel-}"
version="${version%.dmg}"
tools_dir=".build/artifacts/sparkle/Sparkle/bin"
test -x "$tools_dir/generate_appcast"
mkdir -p .build/release-output
work=$(mktemp -d "$PWD/.build/release-output/appcast.XXXXXX")
trap 'rm -rf "$work"' EXIT
cp "$archive" "$work/$filename"
if [[ -f appcast.xml ]]; then cp appcast.xml "$work/appcast.xml"; fi
"$tools_dir/generate_appcast" \
  --account "${EDGE_SPARKLE_ACCOUNT:-edgepanel}" \
  --download-url-prefix "https://github.com/ozeiasfurtozo/EdgePanel/releases/download/v${version}/" \
  --maximum-versions 0 --maximum-deltas 0 \
  -o "$work/appcast.xml" "$work"
xmllint --noout "$work/appcast.xml"
cp "$work/appcast.xml" appcast.xml
echo "$PWD/appcast.xml"
