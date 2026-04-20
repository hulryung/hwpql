#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

PROFILE="${NOTARY_PROFILE:-HWPQuickLook}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" HWPQuickLook/Info.plist)
BUILD_DIR="/tmp/hwpql-release"
APP_PATH="$BUILD_DIR/Build/Products/Release/HWPQuickLook.app"
DMG_STAGE="$BUILD_DIR/dmg-stage"
DMG_PATH="$PROJECT_DIR/build/HWPQuickLook-v${VERSION}.dmg"

echo "== Building v${VERSION} =="
rm -rf "$BUILD_DIR"
xcodebuild -project HWPQuickLook.xcodeproj \
  -scheme HWPQuickLook -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build >/dev/null

echo "== Notarizing .app =="
APP_ZIP="$BUILD_DIR/HWPQuickLook.zip"
ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP_PATH"
spctl --assess --type exec -vv "$APP_PATH"

echo "== Building DMG =="
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$APP_PATH" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
mkdir -p "$(dirname "$DMG_PATH")"
rm -f "$DMG_PATH"
hdiutil create -volname "HWP Quick Look ${VERSION}" \
  -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"

echo "== Signing DMG =="
codesign --sign "Developer ID Application: HUCONN Co.,Ltd. (XGJ87M8ZZR)" \
  --timestamp "$DMG_PATH"

echo "== Notarizing DMG =="
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
spctl --assess --type open --context context:primary-signature -vv "$DMG_PATH"

echo ""
echo "== Done =="
echo "DMG: $DMG_PATH"
ls -lh "$DMG_PATH"
shasum -a 256 "$DMG_PATH"
