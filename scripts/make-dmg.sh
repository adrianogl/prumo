#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcodegen generate
xcodebuild -project PRumo.xcodeproj -scheme PRumo -configuration Release -destination 'platform=macOS' -derivedDataPath build/release build

app="build/release/Build/Products/Release/PRumo.app"
stage="build/dmg-stage"
dmg="site/PRumo.dmg"

rm -rf "$stage"
mkdir -p "$stage"
cp -R "$app" "$stage/PRumo.app"
ln -s /Applications "$stage/Applications"

rm -f "$dmg"
hdiutil create -volname PRumo -srcfolder "$stage" -format UDZO -ov "$dmg"

echo "Arquivo: $dmg"
echo "Tamanho: $(du -h "$dmg" | cut -f1)"
echo "SHA-256: $(shasum -a 256 "$dmg" | cut -d' ' -f1)"
