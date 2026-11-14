#!/usr/bin/env bash
# Script to build AppImage for Linux
set -euo pipefail

VERSION="1.2.3"
DIST_DIR="dist"
APP_DIR="build/v2a.AppDir"
BUNDLE_DIR="build/linux/x64/release/bundle"

if [ ! -d "$BUNDLE_DIR" ]; then
    echo "Bundle directory $BUNDLE_DIR does not exist. Run flutter build linux --release first."
    exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/usr/bin"
mkdir -p "$APP_DIR/usr/lib"

# Copy flutter bundle
cp -r "$BUNDLE_DIR"/* "$APP_DIR/usr/bin/"

# AppRun script
cat << 'EOF' > "$APP_DIR/AppRun"
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${HERE}/usr/bin/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/v2a" "$@"
EOF
chmod +x "$APP_DIR/AppRun"

# Desktop file
cp packaging/linux/com.v2a.converter.desktop.desktop "$APP_DIR/v2a.desktop"

# Icon
if [ -f "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png" ]; then
    cp "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png" "$APP_DIR/v2a.png"
    cp "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png" "$APP_DIR/.DirIcon"
fi

# Download appimagetool if not present
if ! command -v appimagetool &> /dev/null; then
    echo "Downloading appimagetool..."
    curl -L -s https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -o build/appimagetool
    chmod +x build/appimagetool
    rm -rf build/squashfs-root
    (cd build && ./appimagetool --appimage-extract > /dev/null)
    ARCH=x86_64 ./build/squashfs-root/AppRun "$APP_DIR" "$DIST_DIR/V2A-${VERSION}-x86_64.AppImage"
else
    ARCH=x86_64 appimagetool "$APP_DIR" "$DIST_DIR/V2A-${VERSION}-x86_64.AppImage"
fi

echo "AppImage created at: $DIST_DIR/V2A-${VERSION}-x86_64.AppImage"

