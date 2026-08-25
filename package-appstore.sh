#!/bin/bash
# Builds and packages Ruler for Mac App Store submission: a signed, sandboxed
# .app wrapped in a signed .pkg, ready for Transporter or `altool --upload-package`.
#
# This is a separate pipeline from build.sh/package.sh, which produce the
# Developer-ID-signed build shipped via GitHub Releases and Homebrew — that
# build stays ad-hoc/Developer-ID signed and unsandboxed; this one is
# sandboxed and can only be distributed through the App Store.
#
# Requires, all from developer.apple.com / App Store Connect:
#   APPSTORE_SIGN_IDENTITY       "Apple Distribution: Name (TEAMID)"
#   APPSTORE_INSTALLER_IDENTITY  "3rd Party Mac Developer Installer: Name (TEAMID)"
#   APPSTORE_PROFILE             path to the downloaded .provisionprofile
#
#   APPSTORE_SIGN_IDENTITY="Apple Distribution: ..." \
#   APPSTORE_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: ..." \
#   APPSTORE_PROFILE=~/Downloads/Ruler_MAS.provisionprofile \
#   ./package-appstore.sh
set -euo pipefail
cd "$(dirname "$0")"

: "${APPSTORE_SIGN_IDENTITY:?Set APPSTORE_SIGN_IDENTITY to your Apple Distribution identity}"
: "${APPSTORE_INSTALLER_IDENTITY:?Set APPSTORE_INSTALLER_IDENTITY to your Mac Installer Distribution identity}"
: "${APPSTORE_PROFILE:?Set APPSTORE_PROFILE to the path of your downloaded provisioning profile}"
[ -f "$APPSTORE_PROFILE" ] || { echo "error: provisioning profile not found at $APPSTORE_PROFILE" >&2; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
APP="build/appstore/Ruler.app"
DIST="build/dist"

# Regenerate the icon whenever its source is newer than the .icns (same as build.sh).
if [ ! -f Resources/AppIcon.icns ] || [ Tools/make-icon.swift -nt Resources/AppIcon.icns ]; then
  swift Tools/make-icon.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
fi

echo "Building universal binary..."
swift build -c release
HOST_ARCH=$(uname -m)
OTHER_ARCH=$([ "$HOST_ARCH" = "arm64" ] && echo x86_64 || echo arm64)
swift build -c release \
  -Xswiftc -target -Xswiftc "${OTHER_ARCH}-apple-macos13.0" \
  --scratch-path ".build-${OTHER_ARCH}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/PrivacyInfo.xcprivacy "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
cp "$APPSTORE_PROFILE" "$APP/Contents/embedded.provisionprofile"
lipo -create -output "$APP/Contents/MacOS/Ruler" \
  ".build/release/RulerApp" ".build-${OTHER_ARCH}/release/RulerApp"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# A profile downloaded through a browser carries com.apple.quarantine, and a
# plain cp propagates it into the bundle — Apple's validator rejects any
# quarantined file inside an uploaded package.
xattr -cr "$APP"

# The profile itself carries the entitlements a matching signature must
# contain (application-identifier, team-identifier, keychain-access-groups).
# Xcode merges these in automatically under automatic signing; signing by hand
# needs to do the same merge explicitly, or the signature won't match what the
# profile promises and TestFlight/App Store validation rejects the build.
PROFILE_PLIST=$(mktemp)
MERGED_ENTITLEMENTS=$(mktemp)
security cms -D -i "$APPSTORE_PROFILE" > "$PROFILE_PLIST"
/usr/libexec/PlistBuddy -x -c "Print :Entitlements" "$PROFILE_PLIST" > "$MERGED_ENTITLEMENTS"
/usr/libexec/PlistBuddy -c "Add :com.apple.security.app-sandbox bool true" "$MERGED_ENTITLEMENTS"

echo "Signing with $APPSTORE_SIGN_IDENTITY..."
codesign --force --deep --options runtime --timestamp \
  --entitlements "$MERGED_ENTITLEMENTS" \
  --sign "$APPSTORE_SIGN_IDENTITY" "$APP"
rm -f "$PROFILE_PLIST" "$MERGED_ENTITLEMENTS"
codesign --verify --deep --strict "$APP"
spctl --assess --type execute "$APP" 2>&1 || true   # informational; MAS apps aren't Gatekeeper-checked this way

mkdir -p "$DIST"
PKG="$DIST/Ruler-$VERSION-appstore.pkg"
echo "Packaging $PKG..."
productbuild --component "$APP" /Applications --sign "$APPSTORE_INSTALLER_IDENTITY" "$PKG"
xattr -c "$PKG" 2>/dev/null || true

echo
if [ ! -f Resources/AppStoreIcon-1024.png ] || [ Tools/make-icon.swift -nt Resources/AppStoreIcon-1024.png ]; then
  swift Tools/make-icon.swift build/AppIcon.iconset --marketing
  cp build/AppIcon.iconset/AppStoreIcon-1024.png Resources/AppStoreIcon-1024.png
fi
echo "App Store Connect marketing icon: Resources/AppStoreIcon-1024.png"
echo "(upload it under App Information -> App Store icon -- it is never taken from the binary)"
echo
echo "Built $PKG"
echo "Upload it with Transporter (recommended), or:"
echo "  xcrun altool --upload-package \"$PKG\" --type osx --apple-id <app-apple-id> --bundle-id se.joelsanden.ruler --bundle-version $VERSION --bundle-short-version-string $VERSION --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
