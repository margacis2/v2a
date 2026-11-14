#!/usr/bin/env bash
# Script to build Debian / Ubuntu .deb package for V2A Studio
set -euo pipefail

VERSION="1.2.2"
ARCH="amd64"
DIST_DIR="dist"
STAGE_DIR="build/linux_deb_stage"
BUNDLE_DIR="build/linux/x64/release/bundle"

if [ ! -d "$BUNDLE_DIR" ]; then
    echo "Bundle directory $BUNDLE_DIR does not exist. Run flutter build linux --release first."
    exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/DEBIAN"
mkdir -p "$STAGE_DIR/usr/lib/v2a"
mkdir -p "$STAGE_DIR/usr/bin"
mkdir -p "$STAGE_DIR/usr/share/applications"
mkdir -p "$STAGE_DIR/usr/share/icons/hicolor/512x512/apps"

# Copy bundle
cp -r "$BUNDLE_DIR"/* "$STAGE_DIR/usr/lib/v2a/"

# Symlink launcher
cat << 'EOF' > "$STAGE_DIR/usr/bin/v2a"
#!/bin/sh
exec /usr/lib/v2a/v2a "$@"
EOF
chmod +x "$STAGE_DIR/usr/bin/v2a"

# Desktop entry
cp packaging/linux/com.v2a.converter.desktop.desktop "$STAGE_DIR/usr/share/applications/v2a.desktop"

# Icon
if [ -f "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png" ]; then
    cp "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png" "$STAGE_DIR/usr/share/icons/hicolor/512x512/apps/v2a.png"
fi

# Control file
cat << EOF > "$STAGE_DIR/DEBIAN/control"
Package: v2a
Version: ${VERSION}
Section: sound
Priority: optional
Architecture: ${ARCH}
Maintainer: margacis2 <https://github.com/margacis2/v2a>
Depends: ffmpeg, libgtk-3-0, libsqlite3-0
Description: V2A - Video to Audio Converter & Studio
 High-performance desktop application for extracting audio from video,
 format conversion, audio trimming, multi-track extraction, and tagging.
EOF

dpkg-deb --build "$STAGE_DIR" "$DIST_DIR/V2A-${VERSION}-Linux-x64.deb"
echo "DEB package created at: $DIST_DIR/V2A-${VERSION}-Linux-x64.deb"

