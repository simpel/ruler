#!/bin/bash
# Builds Ruler.app into ./build
#
#   ./build.sh          universal (arm64 + x86_64) — what ships
#   ./build.sh --fast   native arch only, for a quick dev loop
set -euo pipefail
cd "$(dirname "$0")"

FAST=false
[ "${1:-}" = "--fast" ] && FAST=true

APP="build/Ruler.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

# Regenerate the icon whenever its source is newer than the .icns.
if [ ! -f Resources/AppIcon.icns ] || [ Tools/make-icon.swift -nt Resources/AppIcon.icns ]; then
  swift Tools/make-icon.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
fi

swift build -c release
BINARIES=(".build/release/RulerApp")

if [ "$FAST" = false ]; then
  # `swift build --arch a --arch b` needs full Xcode; building each slice with
  # the Command Line Tools and lipo-ing them works everywhere.
  HOST_ARCH=$(uname -m)
  OTHER_ARCH=$([ "$HOST_ARCH" = "arm64" ] && echo x86_64 || echo arm64)
  swift build -c release \
    -Xswiftc -target -Xswiftc "${OTHER_ARCH}-apple-macos13.0" \
    --scratch-path ".build-${OTHER_ARCH}"
  BINARIES+=(".build-${OTHER_ARCH}/release/RulerApp")
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
lipo -create -output "$APP/Contents/MacOS/Ruler" "${BINARIES[@]}"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature with the hardened runtime enabled. Replace `-` with a
# "Developer ID Application: …" identity to produce a notarizable build.
codesign --force --options runtime --sign "${CODESIGN_IDENTITY:--}" "$APP" >/dev/null 2>&1 \
  || codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Built $APP — version $VERSION, $(lipo -archs "$APP/Contents/MacOS/Ruler")"
