# V2A FFmpeg & FFprobe Desktop Setup Guide

V2A utilizes native `ffmpeg` and `ffprobe` binaries to deliver hardware-accelerated stream copying (Mode A), audio transcoding across all 8 presets (Mode B), lossless mastering (Mode C), and non-destructive waveform generation.

---

## 1. Engine Execution Modes

V2A Desktop supports two operational modes:

| Mode | Binary Location | Download Size | Best For |
|---|---|---|---|
| **Complete Mode** (Recommended) | Bundled inside `<app_dir>/bin/` or alongside `v2a.exe` | ~85 MB | Self-contained, zero-configuration out of the box |
| **Lite Mode** | System PATH (`ffmpeg`, `ffprobe`) | ~25 MB | Users who already have FFmpeg installed on their OS |
| **Custom Mode** | User-configured absolute file path in Settings | Varies | Custom builds with proprietary hardware encoders |

The application automatically checks in this exact priority:
1. Custom path configured in **Settings -> FFmpeg Core Engine**
2. Bundled companion directory (`<app_dir>/bin/ffmpeg.exe` and `ffprobe.exe`)
3. System `PATH` environment variable

---

## 2. Installing FFmpeg on Windows (for Lite Mode)

If you use the Lite Edition, ensure `ffmpeg` and `ffprobe` are on your system PATH:

### Method A: Winget (Windows Package Manager — Fastest)
```powershell
winget install Gyan.FFmpeg
```

### Method B: Chocolatey
```powershell
choco install ffmpeg
```

### Method C: Scoop
```powershell
scoop install ffmpeg
```

### Method D: Manual ZIP Download
1. Download a release build from [gyan.dev/ffmpeg/builds](https://www.gyan.dev/ffmpeg/builds/) (e.g. `ffmpeg-release-essentials.zip`).
2. Extract to `C:\tools\ffmpeg\`.
3. Add `C:\tools\ffmpeg\bin` to your Windows System `PATH` Environment Variable.
4. Verify by opening a new terminal and running:
   ```cmd
   ffmpeg -version
   ffprobe -version
   ```

---

## 3. Installing FFmpeg on macOS (for Lite Mode)

### Using Homebrew
```bash
brew install ffmpeg
```

### Verification
```bash
which ffmpeg
ffmpeg -version
```

---

## 4. In-App Validation & Custom Configuration

You can configure and test your FFmpeg binary directly inside V2A:
1. Open V2A and click **Settings** on the sidebar.
2. In the **FFmpeg Core Engine** section, enter the absolute path to your `ffmpeg` and `ffprobe` executables.
3. Click **Test & Apply Executable**.
4. The status banner will instantly report:
   - Verification status (green checkmark or orange warning)
   - Exact FFmpeg build version and compile flags
   - Available codecs (`libmp3lame`, `aac`, `libopus`, `libvorbis`, `flac`, `pcm_s16le`)

---

## 5. Supported Codec Matrix

| Container | Encoder | Supported Bitrates | Sample Rates | Mode A Stream Copy |
|---|---|---|---|---|
| **MP3** | `libmp3lame` | 16 – 320 kbps (CBR / VBR) | 8 kHz – 48 kHz | Yes (when source is MP3) |
| **AAC (M4A)** | `aac` | 16 – 320 kbps | 8 kHz – 48 kHz | Yes (when source is AAC) |
| **Opus** | `libopus` | 16 – 320 kbps | 16 kHz, 24 kHz, 48 kHz | Yes (when source is Opus) |
| **FLAC** | `flac` | Lossless | Source / up to 96 kHz | Yes (when source is FLAC) |
| **WAV** | `pcm_s16le` | 1411 kbps Uncompressed | 8 kHz – 48 kHz | Yes (when source is PCM) |
| **OGG** | `libvorbis` | 32 – 320 kbps | 8 kHz – 48 kHz | Yes (when source is Vorbis) |

