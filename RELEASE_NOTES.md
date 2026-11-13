# V2A — Release Notes

---

## What's New in v1.2.0

### 1. Native Desktop Support (Windows 10/11 & macOS)
* **Native Desktop Software**: True 64-bit native Flutter Desktop compilation — 0% Electron, 0% WebView wrappers, 0% localhost servers.
* **Unified Brand Identity**: Windows `.ico` and macOS `Assets.xcassets` application icons now match the official V2A Android launcher icon.
* **Desktop Workspaces**: 8-item dedicated navigation sidebar (Home, Converter, Batch Queue, Trimmer, Studio Player, Conversion History, Settings, About).
* **High-Speed Streaming FFmpeg Engine**: Native process spawning with progress pipe streaming, real-time FPS/speed ratios, and cancellation handling.
* **Desktop Packaging Formats**:
  * Windows Inno Setup EXE (`V2A-Setup-1.2.0-x64.exe`)
  * Windows Portable ZIP (`V2A-1.2.0-Windows-x64-Portable.zip`)
  * Windows Enterprise WiX MSI (`V2A-1.2.0-x64.msi`)
  * macOS Universal 2 DMG (`V2A-1.2.0-macOS.dmg`)
  * macOS Component PKG (`V2A-1.2.0-macOS.pkg`)

### 2. Android v1.2.0 Synchronization
* **Version Parity**: Upgraded Android app version code to 2 and version name to 1.2.0 in sync with the multi-platform release.
* **Settings & About Updates**: Reflected Version 1.2.0 across settings and documentation.
* **F-Droid Metadata**: Updated F-Droid build configuration to build `v1.2.0`.
* **Zero Breaking Changes**: Maintained 100% Android protection — Android builds, manifest, and features remain completely intact.

---

## What's New in v1.0.0

### 1. Crash-Proof Conversion Presets
* **Root Cause Fixed**: Resolved the `DropdownButton` assertion failure (`items == null || ... length == 1`) triggered when selecting presets with zero/custom sample rates (`Fastest Compatibility`, `Voice or Speech`, `Lossless Master`, and `Maximum Compression`).
* **Complete Preset Suite**: Added full support for all 8 presets with stable string identifiers:
  1. **Fastest Compatibility**: Direct stream-copy pass-through without transcoding when source codecs match. Instantaneous, 0% quality loss, minimal battery drain.
  2. **Balanced**: Standard audio balance (MP3, 192 kbps, 44.1 kHz stereo).
  3. **Best Quality**: Maximum MP3 fidelity (320 kbps CBR, 48 kHz stereo).
  4. **Smallest Practical File**: Compact high-efficiency audio (Opus, 48 kbps, 24 kHz mono).
  5. **Voice or Speech**: Speech clarity optimization (Opus, 64 kbps, 24 kHz mono).
  6. **Music**: Optimized high-fidelity music (AAC, 256 kbps, 48 kHz stereo).
  7. **Lossless Master**: Bit-perfect studio archival in FLAC container at source sample rate.
  8. **Maximum Compression**: Ultra-compact file size for sharing (Opus, 32 kbps, 16 kHz mono).
* **Lossless Conversion Warning**: Informative banner alerts users when converting lossy source media into FLAC or WAV containers.

### 2. High-Performance Startup & Native Splash Screen
* **Native Android 12+ Splash**: Branded launch screen with custom dark navy background (`#0F172A`) and centered app icon.
* **Lightweight Flutter Splash Screen**: Smooth logo fade, scale animation, and title reveal transitioning smoothly into Home.
* **Cold Start Latency Reduction**: Removed synchronous blocking calls (`AudioPlayerService`, `JobQueueService`, `FeedbackService`) from `main()`. Audio services and performance monitoring now initialize asynchronously on-demand.

### 3. Responsive UI & Animation Overhaul
* Tested across 320px, 360px, 393px, 412px, and landscape orientations without `RenderFlex` overflows.
* Animated cubic page transitions respecting user reduced-motion preferences (`MediaQuery.disableAnimations`).
* Real-time device storage calculation via native Android `StatFs` (`totalBytes`, `availableBytes`, `usedBytes`, and V2A output directory disk usage).

### 4. Standalone Audio Trimmer
* Accessible directly from the Home screen.
* High-speed PCM downsampled waveform visualization using FFmpeg.
* Sub-second precision with quick-jump nudge chips (`±1s`, `±5s`, `±1m`) and editable timestamp controllers.
* Non-destructive atomic export with collision-free naming.

### 5. Multi-Select File & Queue Management
* History selection mode with Select All / Deselect All.
* Explicit confirmation dialogs protecting against accidental bulk deletions.
* Clean termination of active FFmpeg sessions before removing queued jobs.

### 6. Dramatic APK Size Reduction
* Release builds with Dart AOT compilation.
* Android R8 code shrinking and resource optimization via ProGuard.
* Split per-ABI architecture builds separating `arm64-v8a`, `armeabi-v7a`, and `x86_64`.

