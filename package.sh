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

ditto -c -k --keepParent build/Ruler.app "$DIST/Ruler-$VERSION.zip"

STAGE=$(mktemp -d)
cp -R build/Ruler.app "$STAGE/Ruler.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Ruler $VERSION" -srcfolder "$STAGE" -ov -format UDZO \
  "$DIST/Ruler-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"

echo "Packaged:"
ls -lh "$DIST" | tail -n +2
