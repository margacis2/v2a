# V2A — Video-to-Audio Converter for Android

<p align="center">
  <img src="android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" width="96" height="96" alt="V2A Logo" />
</p>

<p align="center">
  <b>Extract, convert, trim and manage audio from video files — all from your Android device.</b><br>
  V2A is a high-performance Android application built with Flutter and FFmpeg. It provides video-to-audio extraction, audio format conversion, video preview, audio playback, background batch processing, and precision audio trimming through an intuitive, modern interface.
</p>

<p align="center">
  <a href="https://github.com/margacis2/v2a/releases/latest"><img src="https://img.shields.io/github/v/release/margacis2/v2a?style=flat-square&color=blue" alt="Latest Release" /></a>
  <img src="https://img.shields.io/badge/Platform-Android%207.0%2B-brightgreen?style=flat-square" alt="Platform: Android 7.0+" />
  <img src="https://img.shields.io/badge/Architecture-ARM64%20|%20ARMv7%20|%20x86__64-orange?style=flat-square" alt="Supported Architectures" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT%20%2F%20GPLv3-blue?style=flat-square" alt="License: MIT / GPLv3" /></a>
  <img src="https://img.shields.io/badge/Engine-FFmpeg%20v4.6.8-purple?style=flat-square" alt="FFmpeg Engine" />
  <img src="https://img.shields.io/badge/Framework-Flutter%203-blueviolet?style=flat-square" alt="Flutter 3" />
</p>

---

## 📸 Screenshots

Here are screenshots of the **V2A** application running on Android:

| Home Screen | Video Preview | Conversion Settings |
|:---:|:---:|:---:|
| <img src="screenshots/home_screen.png" width="240" alt="Home Screen" /> | <img src="screenshots/video_preview.png" width="240" alt="Video Preview" /> | <img src="screenshots/conversion_settings.png" width="240" alt="Conversion Settings" /> |

| Preset Selection | Conversion Queue | Background Processing |
|:---:|:---:|:---:|
| <img src="screenshots/preset_selection.png" width="240" alt="Preset Selection" /> | <img src="screenshots/batch_conversion.png" width="240" alt="Conversion Queue" /> | <img src="screenshots/conversion_history.png" width="240" alt="Background Conversion" /> |

> [!TIP]
> Add or update your screenshots in the [`screenshots/`](screenshots/) directory in the repository as the application evolves.

---

## ✨ Key Features

### 1. Video Preview
- **ExoPlayer Playback**: Hardware-accelerated streaming video playback using Android Media3 ExoPlayer without buffering entire files into memory.
- **Precision Controls**: Play, pause, forward and backward 10-second seek buttons, and full seek bar.
- **Audio & Volume Control**: Volume slider, mute/unmute toggle.
- **Variable Playback Speed**: 0.5×, 0.75×, 1.0×, 1.25×, 1.5×, and 2.0×.
- **Audio Track Inspection**: Detailed breakdown of audio tracks with codec, channels, sample rate, language, and title for multi-language videos.
- **Video Metadata Inspection**: Real-time display of duration, resolution, video codec, file size, and container type.

### 2. Audio Extraction and Conversion

#### Fastest Compatible Mode
- Uses direct FFmpeg packet stream copying (`-c:a copy`) when the source audio codec matches the chosen output container (e.g. AAC to M4A, Opus to Opus/OGG, MP3 to MP3).
- Avoids unnecessary audio re-encoding, achieving speeds of 20× to 80× real-time with 0% CPU transcoding overhead.
- Preserves the original bit-perfect encoded audio stream with zero quality loss.

#### Audio Re-encoding
- **Bitrates**: Configurable audio bitrates from 16 kbps to 320 kbps.
- **Bitrate Modes**: Constant Bitrate (CBR) and Variable Bitrate (VBR) where supported by the selected encoder.
- **Sample Rates**: 8.0 kHz, 12.0 kHz, 16.0 kHz, 22.05 kHz, 24.0 kHz, 32.0 kHz, 44.1 kHz, and 48.0 kHz.
- **Channel Layouts**: Keep Original, Mono, and Stereo.

#### Audio Processing
- **Volume Boost/Attenuation**: Adjustable volume gain from -12 dB to +12 dB.
- **Loudness Normalization**: Integrated EBU R128 (`loudnorm=I=-16:TP=-1.5:LRA=11`) loudness normalization.
- **Silence Trimming**: Automatic leading and trailing silence detection and removal.
- **Fade Effects**: Configurable smooth fade-in and fade-out transitions.

#### Lossless Export
- Uncompressed 16-bit linear PCM WAV.
- Bit-perfect FLAC lossless compression (level 5).
- Clear warning banner when converting lossy audio sources into lossless containers, clarifying that transcoding cannot restore previously discarded audio frequencies.

---

## ⚡ 3. Eight Built-in Conversion Presets

| Preset | Target Format | Bitrate | Sample Rate | Channels | Description |
|---|---|---|---|---|---|
| **Fastest Compatibility** | Passthrough / AAC fallback | Source / 192 kbps | Source / Configured | Original / Stereo | Direct stream-copy without transcoding; instant & zero quality loss |
| **Balanced** | MP3 | 192 kbps | 44.1 kHz | Stereo | Standard everyday audio balance for universal playback |
| **Best Quality** | MP3 | 320 kbps | 48.0 kHz | Stereo | Maximum MP3 fidelity with studio sample rate |
| **Smallest Practical File** | Opus | 48 kbps | 24.0 kHz | Mono | Ultra-efficient compact storage for podcasts and audiobooks |
| **Voice or Speech** | Opus | 64 kbps | 24.0 kHz | Mono | Speech & dialogue clarity optimization for vocal clarity |
| **Music** | AAC | 256 kbps | 48.0 kHz | Stereo | High-fidelity Apple AAC for music preservation |
| **Lossless Master** | FLAC | Lossless | Source | Original | Bit-perfect studio archival at native source sample rate |
| **Maximum Compression** | Opus | 32 kbps | 16.0 kHz | Mono | Minimum file size for messaging and low-bandwidth sharing |

*Actual output parameters depend on source media compatibility and the selected conversion mode.*

---

## ✂️ 4. Standalone Audio Trimmer

- Accessible directly from the Home screen.
- High-speed downsampled PCM waveform visualization generated using FFmpeg.
- Precise start and end timestamp controls with sub-second accuracy.
- Quick-adjustment nudge chips: `±1 second`, `±5 seconds`, and `±1 minute`.
- Non-destructive atomic export with collision-free naming.

---

## 🛡️ 5. Duplicate-Safe File Management

V2A protects existing files from accidental overwriting. For example:
```text
Audio.mp3  ──>  Audio (1).mp3  ──>  Audio (2).mp3
```

Additional safety mechanisms:
- **Automatic Duplicate Resolution**: Automatically increments filename index on collision.
- **Atomic Staging Files**: Temporary processing files (`.tmp_*`) are staged and integrity-verified before moving to the destination folder.
- **Storage Pre-flight Check**: Verifies free storage space before starting a conversion.
- **Native Android StatFs**: Real-time device storage inspection showing total, used, and free storage space.

---

## 🎵 6. Built-in Audio Player

- **Broad Codec Support**: MP3, AAC, M4A, WAV, FLAC, OGG, and Opus playback.
- **Background Playback**: Continuous background audio playback with foreground notification controls via `just_audio` and `audio_service`.
- **Lock Screen Controls**: System media notification with play/pause, seek forward/back, and track metadata.
- **Queue & Playlist**: Playlist and queue management with shuffle and repeat modes.
- **Variable Playback Speed**: Flexible audio playback speed regulation (0.5× – 2.0×).

---

## 🏗️ Architecture and APK Downloads

V2A provides separate APK builds for different Android processor architectures to minimize download and installation size:

| Architecture | Target Devices | Release APK | Size |
|---|---|---|---|
| **ARM64 (`arm64-v8a`)** | **Modern Android phones and tablets (Recommended)** | `V2A-arm64-v8a-release.apk` | **~62.4 MB** |
| **ARMv7 (`armeabi-v7a`)** | Compatible 32-bit Android devices | `V2A-armeabi-v7a-release.apk` | **~96.3 MB** |
| **x86_64 (`x86_64`)** | Android Studio emulators and compatible Chromebooks | `V2A-x86_64-release.apk` | **~70.2 MB** |
| **Universal** | All architectures bundled in a single APK | `V2A-universal-release.apk` | **~224.7 MB** |
| **Android App Bundle** | **Google Play distribution ONLY** | `V2A-release.aab` | **~137.5 MB** |

### Which APK should I download?
- **Most modern Android phones (2016+)**: Download **`V2A-arm64-v8a-release.apk`**.
- **Older 32-bit phones**: Download **`V2A-armeabi-v7a-release.apk`**.
- **Android emulators / ChromeOS**: Download **`V2A-x86_64-release.apk`**.
- **Unsure about your hardware**: Download **`V2A-universal-release.apk`**.

📦 **Downloads:** [Visit V2A GitHub Releases](https://github.com/margacis2/v2a/releases)

---

## 📱 System Requirements

| Requirement | Details |
|---|---|
| **Operating System** | Android 7.0 (API level 24) or newer |
| **Recommended Android** | Android 13 (API level 33) or newer |
| **Architecture** | ARM64 (`arm64-v8a`), ARMv7 (`armeabi-v7a`), or x86_64 |
| **Storage** | Minimum 100 MB free space for app; conversion storage depends on input file sizes |
| **RAM** | Minimum 2 GB (512 MB free during heavy conversion batches) |

---

## 🛠️ Building from Source

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.12.2+ or latest stable)
- [Android Studio](https://developer.android.com/studio) with Android SDK and NDK installed
- Java 17 JDK
- Git

### Installation Steps

```bash
# 1. Clone the repository
git clone https://github.com/margacis2/v2a.git
cd v2a

# 2. Install dependencies
flutter pub get

# 3. Run tests
flutter test

# 4. Build architecture-specific APKs (Split per ABI)
flutter build apk --release --split-per-abi

# 5. Build a Universal APK
flutter build apk --release

# 6. Build an Android App Bundle (for Google Play)
flutter build appbundle --release
```

### Build Output Locations
```text
build/
└── app/
    └── outputs/
        ├── flutter-apk/
        └── bundle/
            └── release/
```

---

## 🧰 Technology Stack

| Technology | Purpose |
|---|---|
| **Flutter** | Cross-platform Android UI framework |
| **Dart** | Modern reactive application logic |
| **FFmpeg** (`ffmpeg_kit_flutter_new`) | High-performance audio extraction and encoding engine |
| **Android Media3 ExoPlayer** | Hardware-accelerated streaming video playback |
| **`just_audio`** | Advanced audio player engine |
| **`audio_service`** | Android background audio service and lock-screen notification controls |
| **SQLite** (`sqflite`) | Persistent local conversion database and job queue |

---

## 🔐 Privacy

V2A is designed from the ground up to process media **100% locally** on your Android device:
- All audio extraction, transcoding, and trimming operations execute entirely offline.
- No network connection or cloud server is required for conversion functionality.
- Your media files and personal data never leave your device.

---

## 📄 License

- **Application Source Code**: Licensed under the **[MIT License](LICENSE)**.
- **FFmpeg Binaries**: The precompiled FFmpeg binary package used by this project (`ffmpeg-kit-full-gpl`) is distributed under **[GNU General Public License v3.0 (GPLv3)](https://www.gnu.org/licenses/gpl-3.0.en.html)**.
- **Other Dependencies**: Governed by their respective open-source licenses (Apache 2.0, BSD-3-Clause, MIT).

*Users and redistributors should review applicable third-party license terms prior to commercial distribution.*

---

## 🤝 Contributions

Suggestions, bug reports, and pull requests are welcome!

If you find an issue or have an idea to improve V2A:
1. Open an issue describing the problem or proposal.
2. Include device model, Android version, and steps to reproduce.
3. Submit a pull request if you have a proposed fix.

---

## 👨‍💻 Project

**V2A — Video-to-Audio Converter for Android**  
*Developed with Flutter and FFmpeg.*  

[GitHub Repository](https://github.com/margacis2/v2a) · [Releases](https://github.com/margacis2/v2a/releases) · [Issues](https://github.com/margacis2/v2a/issues)
