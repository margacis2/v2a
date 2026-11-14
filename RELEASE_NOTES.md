# V2A Version 1.2.3 Release Notes

## Critical Desktop Conversion Runtime Repair, Dynamic Channel Detection & Multi-Platform Upgrade

V2A v1.2.3 delivers comprehensive desktop conversion runtime repairs, navigation synchronization, dynamic multichannel layout detection and downmixing, FFprobe output integrity verification, and production packaging for Windows, macOS, Linux, and Android.

---

### 🚀 Key Highlights & Critical Fixes in v1.2.3

#### 1. Instant Navigation & Asynchronous Conversion Enqueue (Phase 1 & Phase 2 Fixes)
- **Immediate Screen Transition**:
  - In earlier versions, clicking "Convert Now" or "Add to Queue" synchronously probed all batch media files before enqueuing or switching screens. If probing blocked or delayed, navigation appeared non-functional.
  - In v1.2.3, clicking **Convert Now** or **Add to Queue** captures the current conversion configuration and immediately transitions to the **Conversion Queue** screen (`widget.onNavigate(2)`).
  - Background workers process queue scheduling smoothly in parallel without blocking the UI thread.
- **Uninterrupted Queue Worker Scheduling**:
  - The worker immediately transitions scheduled jobs through the complete lifecycle:
    `QUEUED` → `VALIDATING` → `INSPECTING` → `PREPARING` → `RUNNING` → `FINALIZING` → `COMPLETED`.
  - Failed or cancelled conversions persist in queue history with full diagnostics, logs, and a one-click retry action.

#### 2. Dynamic Audio Channel Detection & Strict Downmixing Rules (Phase 3 & Phase 4)
- **Deep FFprobe Stream Inspection**:
  - Every audio track inside containers (MKV, MP4, WebM) is dynamically inspected for:
    - Codec name and profile
    - Sample rate and bit rate
    - Channel count (1, 2, 3, 4, 6, 8 channels)
    - Channel layout (`mono`, `stereo`, `2.1`, `4.0`, `5.1`, `7.1`)
    - Language tag and track title
- **Audio Integrity & Format Constraints**:
  - **Zero Fake Channels**: Mono sources remain pure mono by default without artificial duplication.
  - **MP3 Channel Constraint Enforcement**: MP3 (`libmp3lame`) strictly rejects >2 channels. When users convert 5.1 or 7.1 surround sound to MP3, V2A automatically generates a clean stereo downmix (`-ac 2`) to prevent encoder crashes.
  - Multichannel formats (AAC/M4A, FLAC, WAV, Opus) retain full multichannel layouts when selected.
  - The UI dynamically adapts channel layout choices based on the target container and warns users when downmixing occurs.

#### 3. Output Integrity Verification with FFprobe (Phase 6)
- Conversions are only marked `COMPLETED` when:
  1. The FFmpeg process exits with code 0.
  2. The temporary staging file is atomically finalized in the destination folder.
  3. The finalized output file exists on disk and is non-empty.
  4. FFprobe inspects and validates the output audio stream, ensuring valid headers and playable audio.

#### 4. Absolute Android Protection (Phase 11)
- The entire `android/` directory remains 100% untouched (`git diff android/` is completely empty).
- All Android APKs (Universal, ARM64, ARMv7, x86_64) and the Google Play App Bundle (AAB) remain fully functional and backward-compatible.

---

### 📦 Available Release Packages

| Platform | Package Format | File Name | Architecture |
| :--- | :--- | :--- | :--- |
| **Windows** | Setup Installer (.exe) | `V2A-Setup-1.2.3-x64.exe` | x64 |
| **Windows** | Windows Installer (.msi) | `V2A-1.2.3-x64.msi` | x64 |
| **Windows** | Portable Archive (.zip) | `V2A-1.2.3-Windows-x64-Portable.zip` | x64 |
| **macOS** | Disk Image (.dmg) | `V2A-1.2.3-macOS.dmg` | Universal (Apple Silicon & Intel) |
| **macOS** | Installer Package (.pkg) | `V2A-1.2.3-macOS.pkg` | Universal (Apple Silicon & Intel) |
| **Linux** | Debian / Ubuntu (.deb) | `V2A-1.2.3-Linux-x64.deb` | x64 (Ubuntu, Debian, Mint) |
| **Linux** | Red Hat / Fedora (.rpm) | `V2A-1.2.3-Linux-x64.rpm` | x64 (Fedora, RHEL, openSUSE) |
| **Linux** | Universal AppImage (.AppImage) | `V2A-1.2.3-x86_64.AppImage` | x64 (All Linux distributions) |
| **Linux** | Portable Archive (.tar.gz) | `V2A-1.2.3-Linux-x64-Portable.tar.gz` | x64 |
| **Android** | Universal APK (.apk) | `V2A-universal-release.apk` | All Devices |
| **Android** | ARM64 APK (.apk) | `V2A-arm64-v8a-release.apk` | Modern 64-bit phones |
| **Android** | ARMv7 APK (.apk) | `V2A-armeabi-v7a-release.apk` | Older 32-bit phones |
| **Android** | x86_64 APK (.apk) | `V2A-x86_64-release.apk` | Emulators & Chromebooks |
| **Android** | App Bundle (.aab) | `V2A-release.aab` | Google Play Store |
