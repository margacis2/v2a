#!/usr/bin/env bash
# Script to build portable tar.gz for Linux
set -euo pipefail

VERSION="1.2.1"
DIST_DIR="dist"
BUNDLE_DIR="build/linux/x64/release/bundle"

if [ ! -d "$BUNDLE_DIR" ]; then
    echo "Bundle directory $BUNDLE_DIR does not exist. Run flutter build linux --release first."
    exit 1
fi

mkdir -p "$DIST_DIR"
ARCHIVE_NAME="V2A-${VERSION}-Linux-x64-Portable.tar.gz"

# Create archive
tar -czf "$DIST_DIR/$ARCHIVE_NAME" -C "$BUNDLE_DIR" .
echo "Linux portable archive created at: $DIST_DIR/$ARCHIVE_NAME"
