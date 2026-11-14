#!/usr/bin/env bash
# Script to build RPM package for Fedora / RHEL
set -euo pipefail

VERSION="1.2.3"
DIST_DIR="dist"
DEB_PATH="$DIST_DIR/V2A-${VERSION}-Linux-x64.deb"

if [ ! -f "$DEB_PATH" ]; then
    echo "DEB package $DEB_PATH not found. Building DEB first..."
    chmod +x packaging/linux/build_deb.sh
    ./packaging/linux/build_deb.sh
fi

if command -v alien &> /dev/null; then
    echo "Converting DEB to RPM using alien..."
    alien -r --scripts "$DEB_PATH"
    mv v2a-${VERSION}*.rpm "$DIST_DIR/V2A-${VERSION}-Linux-x64.rpm" 2>/dev/null || true
    echo "RPM package created in $DIST_DIR"
else
    echo "alien command not found; skipping RPM conversion"
fi

