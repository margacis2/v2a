# V2A macOS Desktop Build & Packaging Guide

This guide covers building, signing, and packaging **V2A — Video to Audio Studio** (v1.2.0) for **macOS (Apple Silicon & Intel x86_64)**.

---

## 1. Prerequisites

- **macOS**: macOS 13 (Ventura), macOS 14 (Sonoma), or macOS 15 (Sequoia)
- **Xcode**: 15.0 or newer with command line developer tools (`xcode-select --install`)
- **Flutter SDK**: 3.22.0 or newer
- **CocoaPods**: `brew install cocoapods`
- **Optional**: `create-dmg` (`brew install create-dmg`) for styled DMG builds

Verify environment:
```bash
flutter doctor -v
```

---

## 2. Configuration & Identity

- **Application Name**: V2A
- **Bundle Identifier**: `com.v2a.converter.desktop`
- **Minimum macOS Version**: 10.15 (Catalina)
- **Architectures**: Universal 2 (arm64 + x86_64)

Entitlements are configured in `macos/Runner/Release.entitlements`:
- Network client & server (for local FFmpeg socket/pipe communication)
- User-selected file read/write permissions
- Hardened Runtime enabled for notarization

---

## 3. Building Release App Bundle

1. Install CocoaPods dependencies:
   ```bash
   cd macos && pod install && cd ..
   ```

2. Compile release app bundle:
   ```bash
   flutter build macos --release
   ```

The compiled application bundle will be created at:
`build/macos/Build/Products/Release/V2A.app`

---

## 4. Packaging macOS Distributions

### A. Apple Disk Image (DMG)
Run the automated DMG build script:
```bash
chmod +x packaging/macos/build_dmg.sh
./packaging/macos/build_dmg.sh
```
Output artifact: `dist/V2A-1.2.0-macOS.dmg`

Features:
- Drag-and-drop installer into `/Applications`
- Compressed UDZO format
- Custom volume icon and installer window geometry

---

### B. Apple Component Package (PKG)
Run the automated PKG build script:
```bash
chmod +x packaging/macos/build_pkg.sh
./packaging/macos/build_pkg.sh
```
Output artifact: `dist/V2A-1.2.0-macOS.pkg`

---

## 5. Code Signing & Notarization (Production Release)

To sign and notarize with an Apple Developer account:
```bash
# 1. Sign App Bundle
codesign --deep --force --verify --verbose \
  --options runtime \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  "build/macos/Build/Products/Release/V2A.app"

# 2. Submit for Notarization
xcrun notarytool submit "dist/V2A-1.2.0-macOS.dmg" \
  --apple-id "your-apple-id@example.com" \
  --password "app-specific-password" \
  --team-id "TEAM_ID" \
  --wait

# 3. Staple Notarization Ticket
xcrun stapler staple "dist/V2A-1.2.0-macOS.dmg"
```
