# V2A Version 1.2.2 Release Notes

## Complete Desktop Conversion Engine Repair & Professional Multi-Platform Audio Converter Upgrade

V2A v1.2.2 addresses critical desktop conversion engine stability issues, repairs background queue execution, fixes database schema migrations, and implements configurable multi-threading, dynamic audio stream extraction, and full cross-platform desktop & mobile packaging (Windows, macOS, Linux, and Android).

---

### 🚀 Key Highlights & Critical Fixes in v1.2.2

#### 1. Conversion Engine Root-Cause Fix (Conversion Not Executing Repaired)
- **Database Schema Migration (Smoking Gun Bug #1)**:
  - In earlier builds, new fields (`audioStreamIndex`, `selectedAudioTrackIndexes`, metadata, and silence trim parameters) were serialized in `ConversionJob.toMap()`, but the SQLite database remained at schema version 1.
  - Calling `db.insertJob(job)` triggered an uncaught `DatabaseException: table jobs has no column named audioStreamIndex`, causing queue enqueue operations to crash silently and jobs to be lost on screen changes.
  - In v1.2.2, `DatabaseService` is upgraded to `version: 2` with full `onUpgrade` migrations (`ALTER TABLE jobs ADD COLUMN ...`), completely restoring persistent job queueing.
- **Desktop Queue Startup Initialization (Smoking Gun Bug #2)**:
  - On desktop platforms, `DesktopAppShell` launched directly, bypassing mobile `SplashScreen`. As a result, `JobQueueService.init()` was never called on desktop startup.
  - In v1.2.2, `DesktopAppShell` initializes `JobQueueService` upon startup, recovering any interrupted conversions and mounting background queues immediately.
- **Robust Probe Resolution & Fallback (Smoking Gun Bug #3)**:
  - Files enqueued before FFprobe analysis completes now automatically await inspection or generate safe fallback audio stream descriptors, ensuring 100% of selected files are successfully converted without silent drops.

#### 2. Real Dedicated Background Conversion Worker
- **Thread Isolation & Responsiveness**: Conversions execute in separate background processes without blocking Flutter UI rendering.
- **Configurable Multi-Threading Concurrency**: Configurable concurrent execution (1, 2, 3, or 4 simultaneous conversions) with thread-safe process management.
- **Granular Lifecycle State Tracking**:
  - `QUEUED` → `VALIDATING` → `INSPECTING` → `PREPARING` → `RUNNING` → `FINALIZING` → `COMPLETED`
  - Robust failure states: `FAILED`, `CANCELLED`, `INTERRUPTED`.
- **Zero Data Loss & Failure Isolation**: Failed or cancelled conversions remain visible with detailed logs and one-click retry; succeeding jobs continue unaffected.

#### 3. Complete Desktop Conversion Studio
- **Multi-Stream Audio Track Extraction**: Full inspection of MKV, MP4, WebM containers to select individual or all audio tracks with stream mapping (`-map 0:a:N`).
- **Precision Audio Configuration**: Complete sample rate, channel mode (Mono, Stereo, 2.1, 4.0, 5.1, 7.1), decibel volume adjustment (-24 dB to +24 dB), and EBU R128 loudness normalization.
- **Metadata & Album Artwork**: Comprehensive ID3v2 tag editor and embedded album cover support.
- **Accurate Real-Time Progress**: Continuous progress calculation based on exact microseconds with no premature jumps to 99%.

#### 4. Absolute Android Protection
- The `android/` directory has zero modifications (`git diff android/` is completely empty).
- Android mobile builds (ARM64-v8a, ARMeabi-v7a, x86_64, Universal APK, and Google Play AAB) remain completely untouched and backward-compatible.

---

### 📦 Available Release Packages

| Platform | Package Format | File Name | Architecture |
| :--- | :--- | :--- | :--- |
| **Windows** | Setup Installer (.exe) | `V2A-Setup-1.2.2-x64.exe` | x64 |
| **Windows** | Windows Installer (.msi) | `V2A-1.2.2-x64.msi` | x64 |
| **Windows** | Portable Archive (.zip) | `V2A-1.2.2-Windows-x64-Portable.zip` | x64 |
| **macOS** | Disk Image (.dmg) | `V2A-1.2.2-macOS.dmg` | Universal (Apple Silicon & Intel) |
| **macOS** | Installer Package (.pkg) | `V2A-1.2.2-macOS.pkg` | Universal (Apple Silicon & Intel) |
| **Linux** | Debian / Ubuntu (.deb) | `V2A-1.2.2-Linux-x64.deb` | x64 (Ubuntu, Debian, Mint) |
| **Linux** | Red Hat / Fedora (.rpm) | `V2A-1.2.2-Linux-x64.rpm` | x64 (Fedora, RHEL, openSUSE) |
| **Linux** | Universal AppImage (.AppImage) | `V2A-1.2.2-x86_64.AppImage` | x64 (All Linux distributions) |
| **Linux** | Portable Archive (.tar.gz) | `V2A-1.2.2-Linux-x64-Portable.tar.gz` | x64 |
| **Android** | Universal APK (.apk) | `V2A-universal-release.apk` | All Devices |
| **Android** | ARM64 APK (.apk) | `V2A-arm64-v8a-release.apk` | Modern 64-bit phones |
| **Android** | ARMv7 APK (.apk) | `V2A-armeabi-v7a-release.apk` | Older 32-bit phones |
| **Android** | x86_64 APK (.apk) | `V2A-x86_64-release.apk` | Emulators & Chromebooks |
| **Android** | App Bundle (.aab) | `V2A-release.aab` | Google Play Store |
