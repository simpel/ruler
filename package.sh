#!/bin/bash
# Builds the universal app and packages it for a GitHub release:
# build/dist/Ruler-<version>.dmg and .zip
set -euo pipefail
cd "$(dirname "$0")"

./build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
DIST="build/dist"
rm -rf "$DIST"
mkdir -p "$DIST"

ditto -c -k --keepParent build/Distanser.app "$DIST/Distanser-$VERSION.zip"
ln -sf "Distanser-$VERSION.zip" "$DIST/Ruler-$VERSION.zip"

STAGE=$(mktemp -d)
cp -R build/Distanser.app "$STAGE/Distanser.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Distanser $VERSION" -srcfolder "$STAGE" -ov -format UDZO \
  "$DIST/Distanser-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"

# Stable direct-download URLs
cp "$DIST/Distanser-$VERSION.dmg" "$DIST/Distanser.dmg"
ln -sf "Distanser-$VERSION.dmg" "$DIST/Ruler-$VERSION.dmg"
ln -sf "Distanser.dmg" "$DIST/Ruler.dmg"

echo "Packaged:"
ls -lh "$DIST" | tail -n +2
