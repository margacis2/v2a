# V2A — Professional Video-to-Audio Converter for Android

<p align="center">
  <img src="android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" width="96" height="96" alt="V2A Logo" />
</p>

<p align="center">
  <b>Fast, Private, Studio-Grade Video-to-Audio Extraction and Audio Processing for Android</b>
</p>

---

## Overview

**V2A** is a production-ready, memory-efficient Android application built with Flutter, native FFmpeg integration, Android Media3 ExoPlayer, and SQLite. It provides rapid audio extraction and format conversion with built-in video preview, audio playback, background queues, and an uncompromising duplicate-safe output architecture.

---

## Key Features

### 1. Mandatory Video Preview
- **Hardware-Accelerated ExoPlayer**: Smooth streaming preview without buffering entire files into memory.
- **Precision Controls**: Play, pause, seek bar, +/- 10s seek buttons, volume control, mute/unmute, and speed adjustments (0.5×, 0.75×, 1.0×, 1.25×, 1.5×, 2.0×).
- **Multi-Track Audio Selection**: Inspects audio tracks with codec, channels, sample rate, language, and title for multi-language videos.
- **Video Metadata Inspection**: Real-time display of duration, resolution, video codec, file size, and container type.

### 2. High-Speed Conversion Engine
- **Mode A: Fastest Compatible Stream Copy**:
  - Direct packet copy (`-c:a copy`) when source codec matches output container (e.g. AAC to M4A, Opus to Opus/OGG, MP3 to MP3).
  - 20× to 80× real-time speed with 0% CPU transcoding overhead and bit-perfect fidelity.
- **Mode B: Re-encode & Compress**:
  - Configurable bitrates from 16 kbps to 320 kbps (CBR and VBR).
  - Sample rates: 8.0 kHz, 12.0 kHz, 16.0 kHz, 22.05 kHz, 24.0 kHz, 32.0 kHz, 44.1 kHz, 48.0 kHz.
  - Channels: Keep Original, Mono, Stereo.
  - Audio filters: Volume boost/attenuation (-12 dB to +12 dB), EBU R128 loudness normalization, silence trimming, fade-in and fade-out.
- **Mode C: Lossless Archival**:
  - Uncompressed 16-bit linear PCM WAV or bit-perfect FLAC.
  - Lossless conversion banner notice when converting lossy sources to lossless containers.

### 3. All 8 Conversion Presets
| Preset | Target Format | Bitrate | Sample Rate | Channels | Description |
|---|---|---|---|---|---|
| **Fastest Compatibility** | AAC / Passthrough | Source | Source | Original | Direct stream-copy without transcoding; instant & zero quality loss |
| **Balanced** | MP3 | 192 kbps | 44.1 kHz | Stereo | Everyday audio balance for universal playback |
| **Best Quality** | MP3 | 320 kbps | 48.0 kHz | Stereo | Maximum MP3 fidelity with studio sample rate |
| **Smallest Practical File** | Opus | 48 kbps | 24.0 kHz | Mono | Ultra-efficient compact storage for podcasts and audiobooks |
| **Voice or Speech** | Opus | 64 kbps | 24.0 kHz | Mono | Optimized for dialogue clarity and vocal recordings |
| **Music** | AAC | 256 kbps | 48.0 kHz | Stereo | High-fidelity Apple AAC for music preservation |
| **Lossless Master** | FLAC | Lossless | Source | Original | Bit-perfect studio archival at native sample rate |
| **Maximum Compression** | Opus | 32 kbps | 16.0 kHz | Mono | Minimum file size for messaging and low-bandwidth sharing |

### 4. Standalone Audio Trimmer
- Accessible directly from the Home screen.
- High-speed PCM downsampled waveform visualization using FFmpeg.
- Sub-second precision with quick-jump nudge chips (`±1s`, `±5s`, `±1m`) and editable timestamp controllers.
- Non-destructive atomic export with collision-free naming.

### 5. Never Overwrite Protection
- Automatic duplicate collision resolution: `Audio.mp3` → `Audio (1).mp3` → `Audio (2).mp3`.
- Atomic temporary staging files (`.tmp_*`) verified before moving to destination.
- Real-time device storage inspection via native Android `StatFs`.

### 6. Built-in Audio Player
- Full audio player supporting MP3, AAC, M4A, WAV, FLAC, OGG, and Opus.
- Background playback and lock screen controls via `audio_service` and `just_audio`.
- Playlist queuing, shuffle, repeat, and speed controls.

---

## Architecture & ABI Variants

V2A provides dedicated APK builds for each Android architecture, drastically reducing the installed application size:

| Architecture | Target Devices | Recommended Release APK |
|---|---|---|
| **ARM64 (arm64-v8a)** | Modern Android phones & tablets (2016+) | `V2A-arm64-v8a-release.apk` |
| **ARMv7 (armeabi-v7a)** | Older 32-bit Android phones | `V2A-armeabi-v7a-release.apk` |
| **x86_64 (x86_64)** | Android emulators & Intel/AMD Chromebooks | `V2A-x86_64-release.apk` |
| **Universal** | All architectures bundled in a single APK | `V2A-universal-release.apk` |
| **App Bundle** | Google Play Store distribution | `V2A-release.aab` |

---

## System Requirements

- **Operating System**: Android 7.0 (API 24) or newer.
- **Recommended**: Android 13+ (API 33+) with Media permissions.
- **RAM**: 2 GB minimum (512 MB available).
- **Storage**: Minimum 100 MB free for app; conversion storage depends on input file sizes.

---

## Building from Source

### Prerequisites
1. [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.12.2+ or latest stable).
2. [Android SDK](https://developer.android.com/studio) with platform-tools and NDK.
3. Java 17 JDK.

### Steps
```bash
# 1. Clone repository
git clone https://github.com/v2a-project/v2a.git
cd v2a

# 2. Get dependencies
flutter pub get

# 3. Run verification tests
flutter test

# 4. Build release APKs (split per ABI)
flutter build apk --release --split-per-abi

# 5. Build universal release APK
flutter build apk --release

# 6. Build Android App Bundle
flutter build appbundle --release
```

Outputs will be generated in `build/app/outputs/flutter-apk/` and `build/app/outputs/bundle/release/`.

---

## License

This project is licensed under the [MIT License](LICENSE).
Third-party libraries include FFmpeg (licensed under LGPL/GPL).
