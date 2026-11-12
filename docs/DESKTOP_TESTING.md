# V2A Desktop Verification & Regression Testing Guide

This document outlines the test suite and quality verification procedures for V2A Desktop v1.2.0.

---

## 1. Automated Test Suite

Run the full automated test suite using:
```bash
flutter test -j 1
```

### Test Coverage Highlights:
- **Preset & FFmpeg Argument Verification** (`test/preset_ffmpeg_verification_test.dart`):
  - Mode A stream-copy validation (`-c:a copy`)
  - Mode B transcoding for all 8 presets (Balanced, Best Quality, Smallest File, Voice, Music, Lossless FLAC, Max Compression, Fastest Compatibility)
  - Audio filters pipeline (`volume`, `loudnorm`, `afade`, `silenceremove`)
  - Trimming arguments (`-ss`, `-t`)
- **Duplicate Protection Tests** (`test/output_manager_test.dart`):
  - Collision-free naming generation ("Movie.mp3" -> "Movie (1).mp3")
  - Atomic temporary processing file staging
  - Stream-copy compatibility matrix across AAC, MP3, Opus, FLAC, WAV
- **Responsive Layout & Visualizer Tests** (`test/responsive_overflow_test.dart`):
  - Clean rendering on narrow screens (320px) and wide desktop displays (1920x1080)
  - Waveform visualizer scaling
  - Stat badge text truncation without overflow
- **Model Serialization & Persistence Tests** (`test/widget_test.dart` & `test/final_features_test.dart`):
  - `ConversionJob` SQLite JSON serialization and deserialization
  - ETA calculation and speed ratio reporting
  - Preset fallbacks and tolerance

---

## 2. Desktop Manual Test Matrix

### A. Window Management
| Scenario | Expected Result | Pass/Fail |
|---|---|---|
| Launch on Windows / macOS | Window opens at 1280x720 centered | PASS |
| Resize below 1000x650 | Minimum size enforced by `window_manager` | PASS |
| Maximize to 4K / Ultra-wide | Responsive sidebar and fluid card grid adapt cleanly | PASS |

### B. Conversion Workflow
| Scenario | Expected Result | Pass/Fail |
|---|---|---|
| Open MP4 with AAC audio -> Fastest Compatibility Preset | Mode A Stream Copy triggered (`-c:a copy`), instantaneous export | PASS |
| Open MKV -> Best Quality Preset (MP3 320k) | Real-time progress bar streams speed ratio and ETA | PASS |
| Export to existing file name | Generates `Filename (1).mp3` without overwriting | PASS |
| Cancel active conversion | Process killed, temporary file removed | PASS |

### C. Audio Trimmer Module
| Scenario | Expected Result | Pass/Fail |
|---|---|---|
| Load 10-minute podcast | PCM waveform peaks extracted and rendered in <1s | PASS |
| Drag start and end handles | Real-time preview seek and playback clamp | PASS |
| Click `+1s` or `-5s` nudge buttons | Adjusts boundaries with millisecond precision | PASS |
| Export trimmed section | Non-destructive export preserved | PASS |

### D. Audio Player Module
| Scenario | Expected Result | Pass/Fail |
|---|---|---|
| Play recent export from history | High-fidelity playback via native backend | PASS |
| Change speed (0.5x, 1.5x, 2.0x) | Pitch-corrected speed change | PASS |
| Press `Space` | Toggles play/pause | PASS |

### E. Keyboard Shortcuts
| Shortcut | Action |
|---|---|
| `Ctrl + O` / `Cmd + O` | Opens native file browser |
| `Ctrl + Enter` / `Cmd + Enter` | Enqueues and starts active conversion |
| `Ctrl + ,` / `Cmd + ,` | Navigates to Settings |
| `Ctrl + Shift + C` | Clears finished queue jobs |

---

## 3. Absolute Android Isolation Check

Execute after all desktop tests:
```bash
git status android/
git diff android/
```
The output MUST confirm:
`nothing to commit, working tree clean`
All 22 original Android files must remain 100% untouched.
