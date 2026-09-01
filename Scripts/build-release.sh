#!/usr/bin/env bash
#
# Build a signed + notarized + stapled MacTaskSwitcher.dmg for distribution.
#
# One-time setup:
#   1. Apple Developer account with a "Developer ID Application" certificate
#      installed in your login keychain (Xcode ▸ Settings ▸ Accounts ▸ Manage
#      Certificates, or download from developer.apple.com).
#   2. Store notarization credentials once:
#        xcrun notarytool store-credentials MacTaskSwitcher \
#          --apple-id "you@example.com" --team-id "XXXXXXXXXX" \
#          --password "<app-specific-password>"
#
# Usage:
#   TEAM_ID=XXXXXXXXXX ./Scripts/build-release.sh
#
# Optional env:
#   NOTARY_PROFILE   keychain profile name           (default: MacTaskSwitcher)
#   SIGN_ID          codesign identity for the .dmg   (default: "Developer ID Application")
#
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="${TEAM_ID:?set TEAM_ID to your 10-character Apple Developer Team ID}"
NOTARY_PROFILE="${NOTARY_PROFILE:-MacTaskSwitcher}"
SIGN_ID="${SIGN_ID:-Developer ID Application}"
SCHEME="MacTaskSwitcher"
VOLNAME="MacTaskSwitcher"

VERSION="$(sed -n 's/^ *MARKETING_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/p' project.yml | head -1)"
VERSION="${VERSION:-0.0.0}"

BUILD_DIR="$PWD/build"
ARCHIVE="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/$SCHEME.app"
DMG="$BUILD_DIR/$SCHEME-$VERSION.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodegen generate

echo "==> Archiving (Release)"
xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -configuration Release \
  -archivePath "$ARCHIVE" -destination 'generic/platform=macOS' \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  archive

echo "==> Exporting Developer ID app"
cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"

echo "==> Notarizing the app"
APP_ZIP="$BUILD_DIR/$SCHEME-app.zip"
ditto -c -k --keepParent "$APP" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"

echo "==> Building DMG"
STAGING="$BUILD_DIR/dmg-staging"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGING" -ov -format ULFO "$DMG"

echo "==> Signing + notarizing the DMG"
codesign --force --sign "$SIGN_ID" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

echo "==> Verifying"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

echo
echo "Done: $DMG"
