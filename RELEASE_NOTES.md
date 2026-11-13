# V2A Version 1.2.1 Release Notes

## Multi-Platform Native Audio Conversion Studio (Windows, macOS, Linux, Android)

V2A v1.2.1 introduces major desktop engine architectural enhancements, multi-stream track extraction (for MKV, MP4, and multi-track containers), batch conversion, custom output directory enforcement, comprehensive metadata/artwork support, and first-class native Linux packaging.

---

### Key Highlights & Changes in v1.2.1

#### 1. Conversion Engine & Progress Accuracy
- **Fixed 99% Progress Jump**: Resolved an issue where FFmpeg progress microseconds (`out_time_us`) were parsed as milliseconds, causing conversion progress to jump to 99% prematurely. Progress now accurately reflects exact duration progress and smoothly transitions to 100% only upon complete verification of the output file.
- **Strict Destination Enforcement**: Converted files strictly respect `DestinationMode`:
  - **Default configured directory** (persisted in preferences and accessible in Settings).
  - **Beside source file** (`p.dirname(sourcePath)`).
  - **Custom destination folder** selected via native system folder picker.
- **Never-Overwrite Duplicate Safety**: Atomic temporary staging files (`.tmp`) ensure corrupt or partial output never clobbers existing files. Unique auto-increment naming (`_1`, `_2`) guarantees lossless file safety.

#### 2. Multiple Audio Stream Selection & Extraction (MKV, MP4, WebM)
- **Container Stream Enumeration**: FFprobe inspects all container streams and surfaces every audio track with stream index, codec, language code, channel layout (Mono, Stereo, 5.1, 7.1), sample rate, and default flags.
- **Dynamic Stream Mapping**: Employs dynamic `-map 0:a:N` parameters for exact track extraction without video re-encoding overhead.
- **Batch Track Extraction**: Option to convert all audio tracks into separate labeled files simultaneously (`filename_Track1_eng.mp3`, `filename_Track2_tam.mp3`).

#### 3. Advanced Audio Configuration & Processing
- **Extended Channel Routing**: Supports Mono, Stereo, 2.1 Surround (3ch), 4.0 Quadraphonic (4ch), 5.1 Surround (6ch), and 7.1 Surround (8ch).
- **Decibel Volume Adjustment**: Precision slider and numeric input from -24 dB to +24 dB with one-click reset to 0 dB.
- **Broadcast Loudness Normalization**: Integrated EBU R128 loudness filter (`loudnorm=I=-16:TP=-1.5:LRA=11`).
- **Smooth Fades & Silence Trimming**: Configurable fade-in and fade-out durations and intelligent dead air removal (`silenceremove`).

#### 4. Metadata, ID3v2 Tags & Album Artwork
- Comprehensive tag editing: Title, Artist, Album, Album Artist, Year, Genre, Track Number, Disc Number, Composer, Copyright, Comment, Lyrics, and Language.
- Option to strip all existing metadata (`-map_metadata -1`) or preserve source tags.
- Front cover album artwork embedding (`attached_pic`).

#### 5. Native Linux Support & Packaging
- Added full native Linux desktop build support.
- Generated standard Linux desktop packaging:
  - Debian / Ubuntu `.deb` package (`dpkg-deb`).
  - Red Hat / Fedora `.rpm` package (`alien`).
  - Universal `.AppImage` bundle (`appimagetool`).
  - Portable `.tar.gz` distribution bundle.

#### 6. Absolute Android Protection
- Zero changes to the `android/` directory (`git diff android/` is completely empty).
- All Android builds, architectures, and features remain 100% intact and backward-compatible.

---

### Release Binaries & Installers

- **Windows 10/11 (x64)**:
  - `V2A-Setup-1.2.1-x64.exe` (Inno Setup Installer)
  - `V2A-1.2.1-x64.msi` (WiX Toolset Windows Installer)
  - `V2A-1.2.1-Windows-x64-Portable.zip` (Portable ZIP Bundle)
- **macOS**:
  - `V2A-1.2.1-macOS.dmg` (Apple Disk Image)
  - `V2A-1.2.1-macOS.pkg` (Apple Installer Package)
- **Linux (x64)**:
  - `V2A-1.2.1-Linux-x64.deb` (Debian / Ubuntu)
  - `V2A-1.2.1-Linux-x64.rpm` (Fedora / RHEL)
  - `V2A-1.2.1-x86_64.AppImage` (Universal AppImage)
  - `V2A-1.2.1-Linux-x64-Portable.tar.gz` (Portable Tarball)
- **Android**:
  - `V2A-arm64-v8a-release.apk`, `V2A-armeabi-v7a-release.apk`, `V2A-x86_64-release.apk`, `V2A-universal-release.apk`
  - `V2A-release.aab` (Google Play App Bundle)
