# V2A Windows Desktop Build & Packaging Guide

This guide covers building, testing, and packaging **V2A — Video to Audio Studio** (v1.2.0) for **Windows 10/11 (64-bit)** using Flutter Desktop.

---

## 1. System Requirements & Prerequisites

To compile native Windows desktop software from source, ensure the following tools are installed:

- **Windows OS**: Windows 10 (Build 17763 or newer) or Windows 11
- **Flutter SDK**: 3.22.0 or newer (Stable channel)
- **Dart SDK**: 3.4.0 or newer (bundled with Flutter)
- **Visual Studio 2022**: Community, Professional, or Enterprise with the **"Desktop development with C++"** workload installed, including:
  - MSVC v143 - VS 2022 C++ x64/x86 build tools
  - Windows 10/11 SDK (10.0.19041.0 or newer)
  - C++ CMake tools for Windows
- **Git for Windows**
- **FFmpeg & FFprobe**: Version 5.x, 6.x, or 7.x in system PATH or bundled in `bin/`

To verify your development environment:
```powershell
flutter doctor -v
```
Ensure `[✓] Visual Studio - develop for Windows` shows all checks green.

---

## 2. Release Compilation

1. Open PowerShell and navigate to the project root:
   ```powershell
   cd C:\Users\marga\Downloads\v2a
   ```

2. Fetch all dependencies:
   ```powershell
   flutter pub get
   ```

3. Run static analysis:
   ```powershell
   flutter analyze
   ```

4. Run the full unit and regression test suite:
   ```powershell
   flutter test -j 1
   ```

5. Compile native 64-bit Windows release binary:
   ```powershell
   flutter build windows --release
   ```

The compiled release artifacts will be placed in:
`build\windows\x64\runner\Release\`

Key files generated:
- `v2a.exe` (Main native executable)
- `flutter_windows.dll` (Flutter desktop engine)
- `data/` (Application assets, fonts, compiled Dart AOT snapshots)
- Plugin DLLs (`screen_retriever_plugin.dll`, `window_manager_plugin.dll`, `just_audio_windows_plugin.dll`)

---

## 3. Packaging Distributions

V2A provides multiple distribution formats for Windows:

### A. Portable ZIP (Zero Installation)
Users can extract and run V2A immediately from any folder or USB drive.

Run the provided packaging script:
```powershell
# Lite Edition (relies on system PATH FFmpeg)
powershell -ExecutionPolicy Bypass -File packaging\windows\build_portable.ps1 -Mode lite

# Complete Edition (bundles FFmpeg & FFprobe)
powershell -ExecutionPolicy Bypass -File packaging\windows\build_portable.ps1 -Mode complete
```
Output artifact: `dist\V2A-1.2.0-Windows-x64-Portable.zip`

---

### B. Inno Setup EXE Installer (`V2A-Setup-1.2.0-x64.exe`)
The recommended single-file installer with desktop shortcuts, Start Menu integration, and clean uninstaller.

1. Install [Inno Setup 6](https://jrsoftware.org/isdl.php).
2. Compile the installer script:
   ```powershell
   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" packaging\windows\v2a_setup.iss
   ```
Output artifact: `dist\V2A-Setup-1.2.0-x64.exe`

---

### C. WiX MSI Installer (`V2A-1.2.0-x64.msi`)
For enterprise deployment via Active Directory Group Policy (GPO) or Microsoft Intune:

1. Install [WiX Toolset v3.14+](https://wixtoolset.org/).
2. Compile the installer:
   ```powershell
   candle -arch x64 -dSourceDir=build\windows\x64\runner\Release -out dist\v2a.wixobj packaging\windows\v2a_installer.wxs
   light -out dist\V2A-1.2.0-x64.msi dist\v2a.wixobj
   ```
Output artifact: `dist\V2A-1.2.0-x64.msi`

---

## 4. Absolute Android Isolation Confirmation

Before releasing Windows builds, verify that no Android files were affected:
```powershell
git status android/
git diff android/
```
Output must be completely clean with zero modified Android files.
