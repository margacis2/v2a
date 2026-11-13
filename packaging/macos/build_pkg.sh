#!/usr/bin/env bash
# Script to build macOS PKG installer for V2A Studio
set -euo pipefail

APP_NAME="V2A"
VERSION="1.2.0"
IDENTIFIER="com.v2a.converter.desktop"
BUILD_DIR="build/macos/Build/Products/Release"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DIST_DIR="dist"
PKG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}-macOS.pkg"

mkdir -p "${DIST_DIR}"

echo "Building macOS component package..."
pkgbuild \
  --component "${APP_BUNDLE}" \
  --install-location "/Applications" \
  --identifier "${IDENTIFIER}" \
  --version "${VERSION}" \
  "${PKG_PATH}"

echo "PKG successfully created at: ${PKG_PATH}"

