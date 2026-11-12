#!/usr/bin/env bash
# Script to build macOS DMG installer for V2A Studio
set -euo pipefail

APP_NAME="V2A"
VERSION="1.2.0"
BUILD_DIR="build/macos/Build/Products/Release"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DIST_DIR="dist"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}-macOS.dmg"

echo "Building macOS Release bundle..."
flutter build macos --release

mkdir -p "${DIST_DIR}"
rm -f "${DMG_PATH}"

echo "Creating DMG image..."
if command -v create-dmg &> /dev/null; then
    create-dmg \
      --volname "${APP_NAME} Installer" \
      --window-pos 200 120 \
      --window-size 800 400 \
      --icon-size 100 \
      --app-drop-link 600 185 \
      "${DMG_PATH}" \
      "${APP_BUNDLE}"
else
    # Fallback to hdiutil
    hdiutil create -volname "${APP_NAME}" -srcfolder "${APP_BUNDLE}" -ov -format UDZO "${DMG_PATH}"
fi

echo "DMG successfully created at: ${DMG_PATH}"
