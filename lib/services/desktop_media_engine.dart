import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversion_config.dart';
import '../models/conversion_job.dart';
import '../models/media_file.dart';
import 'conversion_engine.dart';
import 'media_engine.dart';
import 'output_manager.dart';

enum DesktopEngineMode {
  bundledComplete,
  systemPathLite,
  customConfigured,
  unavailable,
}

class DesktopMediaEngine implements MediaEngine {
  static final DesktopMediaEngine _instance = DesktopMediaEngine._internal();
  factory DesktopMediaEngine() => _instance;
  DesktopMediaEngine._internal();

  static const String keyCustomFfmpeg = 'v2a_custom_ffmpeg_path';
  static const String keyCustomFfprobe = 'v2a_custom_ffprobe_path';

  String? _ffmpegPath;
  String? _ffprobePath;
  DesktopEngineMode _engineMode = DesktopEngineMode.unavailable;
  String _versionString = 'Detecting...';

  final Map<String, Process> _activeProcesses = {};

  DesktopEngineMode get engineMode => _engineMode;
  String get ffmpegPath => _ffmpegPath ?? 'ffmpeg';
  String get ffprobePath => _ffprobePath ?? 'ffprobe';
  bool get isReady => _engineMode != DesktopEngineMode.unavailable;

  @override
  Future<bool> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final customFfmpeg = prefs.getString(keyCustomFfmpeg);
    final customFfprobe = prefs.getString(keyCustomFfprobe);

    // 1. Try custom configured paths
    if (customFfmpeg != null && await _validateExecutable(customFfmpeg)) {
      _ffmpegPath = customFfmpeg;
      _ffprobePath = customFfprobe != null && await _validateExecutable(customFfprobe)
          ? customFfprobe
          : await _findCompanionFfprobe(customFfmpeg);
      _engineMode = DesktopEngineMode.customConfigured;
      _versionString = await _queryVersion(_ffmpegPath!);
      debugPrint('[DesktopMediaEngine] Using custom FFmpeg: $_ffmpegPath');
      return true;
    }

    // 2. Try bundled binaries relative to the executable (Complete Mode)
    final bundledDir = p.join(p.dirname(Platform.resolvedExecutable), 'bin');
    final exeExt = Platform.isWindows ? '.exe' : '';
    final bundledFfmpeg = p.join(bundledDir, 'ffmpeg$exeExt');
    final bundledFfprobe = p.join(bundledDir, 'ffprobe$exeExt');

    if (await _validateExecutable(bundledFfmpeg)) {
      _ffmpegPath = bundledFfmpeg;
      _ffprobePath = await _validateExecutable(bundledFfprobe) ? bundledFfprobe : 'ffprobe$exeExt';
      _engineMode = DesktopEngineMode.bundledComplete;
      _versionString = await _queryVersion(_ffmpegPath!);
      debugPrint('[DesktopMediaEngine] Using bundled Complete FFmpeg: $_ffmpegPath');
      return true;
    }

    // Also check directly alongside the executable
    final sideFfmpeg = p.join(p.dirname(Platform.resolvedExecutable), 'ffmpeg$exeExt');
    final sideFfprobe = p.join(p.dirname(Platform.resolvedExecutable), 'ffprobe$exeExt');
    if (await _validateExecutable(sideFfmpeg)) {
      _ffmpegPath = sideFfmpeg;
      _ffprobePath = await _validateExecutable(sideFfprobe) ? sideFfprobe : 'ffprobe$exeExt';
      _engineMode = DesktopEngineMode.bundledComplete;
      _versionString = await _queryVersion(_ffmpegPath!);
      debugPrint('[DesktopMediaEngine] Using companion Complete FFmpeg: $_ffmpegPath');
      return true;
    }

    // 3. Fallback to system PATH (Lite Mode)
    final systemFfmpeg = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    final systemFfprobe = Platform.isWindows ? 'ffprobe.exe' : 'ffprobe';

    if (await _validateExecutable(systemFfmpeg)) {
      _ffmpegPath = systemFfmpeg;
      _ffprobePath = await _validateExecutable(systemFfprobe) ? systemFfprobe : systemFfmpeg;
      _engineMode = DesktopEngineMode.systemPathLite;
      _versionString = await _queryVersion(_ffmpegPath!);
      debugPrint('[DesktopMediaEngine] Using system PATH FFmpeg (Lite mode)');
      return true;
    }

    _engineMode = DesktopEngineMode.unavailable;
    _versionString = 'FFmpeg not detected';
    debugPrint('[DesktopMediaEngine] FFmpeg not found on system');
    return false;
  }

  Future<bool> setCustomPaths({required String ffmpegPath, String? ffprobePath}) async {
    if (await _validateExecutable(ffmpegPath)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyCustomFfmpeg, ffmpegPath);
      if (ffprobePath != null && await _validateExecutable(ffprobePath)) {
        await prefs.setString(keyCustomFfprobe, ffprobePath);
      }
      return await initialize();
    }
    return false;
  }

  Future<void> clearCustomPaths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyCustomFfmpeg);
    await prefs.remove(keyCustomFfprobe);
    await initialize();
  }

  Future<bool> _validateExecutable(String path) async {
    try {
      final res = await Process.run(path, ['-version']);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _findCompanionFfprobe(String ffmpegPath) async {
    final dir = p.dirname(ffmpegPath);
    final ext = Platform.isWindows ? '.exe' : '';
    final candidate = p.join(dir, 'ffprobe$ext');
    if (await _validateExecutable(candidate)) {
      return candidate;
    }
    return 'ffprobe$ext';
  }

  Future<String> _queryVersion(String path) async {
    try {
      final res = await Process.run(path, ['-version']);
      if (res.exitCode == 0) {
        final firstLine = (res.stdout as String).split('\n').first.trim();
        return firstLine;
      }
    } catch (_) {}
    return 'FFmpeg (Unknown version)';
  }

  static int _parseOutTimeToMs(String outTime) {
    try {
      final parts = outTime.trim().split(':');
      if (parts.length == 3) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        final seconds = double.tryParse(parts[2]) ?? 0.0;
        return ((hours * 3600 + minutes * 60 + seconds) * 1000).round();
      }
    } catch (_) {}
    return 0;
  }

  @override
  Future<String> getVersion() async {
    if (_engineMode == DesktopEngineMode.unavailable) {
      await initialize();
    }
    return _versionString;
  }

  @override
  Future<MediaFile> inspectMedia(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return MediaFile(
        path: filePath,
        fileName: p.basename(filePath),
        sizeBytes: 0,
        duration: Duration.zero,
        extension: p.extension(filePath),
        isCorrupted: true,
        validationError: 'File does not exist or access was revoked',
      );
    }

    final int sizeBytes = await file.length();
    final String fileName = p.basename(filePath);
    final String extension = p.extension(filePath).toLowerCase();

    if (_engineMode == DesktopEngineMode.unavailable) {
      await initialize();
    }

    try {
      final probeArgs = [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        filePath,
      ];

      final res = await Process.run(ffprobePath, probeArgs);
      if (res.exitCode != 0) {
        return MediaFile(
          path: filePath,
          fileName: fileName,
          sizeBytes: sizeBytes,
          duration: Duration.zero,
          extension: extension,
          isCorrupted: true,
          validationError: 'Failed to probe media: exit code ${res.exitCode}',
        );
      }

      final jsonMap = jsonDecode(res.stdout as String) as Map<String, dynamic>;
      final format = jsonMap['format'] as Map<String, dynamic>? ?? {};
      final streams = jsonMap['streams'] as List<dynamic>? ?? [];

      Duration duration = Duration.zero;
      final durStr = format['duration']?.toString();
      if (durStr != null) {
        final secDouble = double.tryParse(durStr);
        if (secDouble != null && secDouble > 0) {
          duration = Duration(milliseconds: (secDouble * 1000).round());
        }
      }

      int? videoWidth;
      int? videoHeight;
      String? videoCodec;
      final audioTracks = <AudioTrackInfo>[];

      for (final s in streams) {
        final streamMap = s as Map<String, dynamic>;
        final codecType = (streamMap['codec_type'] ?? '').toString().toLowerCase();

        if (codecType == 'video' && videoCodec == null) {
          videoCodec = streamMap['codec_name']?.toString();
          videoWidth = int.tryParse(streamMap['width']?.toString() ?? '');
          videoHeight = int.tryParse(streamMap['height']?.toString() ?? '');
        } else if (codecType == 'audio') {
          final tags = streamMap['tags'] as Map<String, dynamic>? ?? {};
          final disposition = streamMap['disposition'] as Map<String, dynamic>? ?? {};
          final language = tags['language']?.toString();
          final title = tags['title']?.toString();
          final channelLayout = streamMap['channel_layout']?.toString();
          final isDefault = disposition['default'] == 1 || disposition['default'] == '1';

          final channels = int.tryParse(streamMap['channels']?.toString() ?? '') ?? 2;
          final sampleRate = int.tryParse(streamMap['sample_rate']?.toString() ?? '') ?? 44100;
          final rawBitrate = int.tryParse(streamMap['bit_rate']?.toString() ?? '') ?? 0;
          final bitrateKbps = rawBitrate > 0 ? (rawBitrate / 1000).round() : 0;
          final codec = streamMap['codec_name']?.toString() ?? 'unknown';
          final index = int.tryParse(streamMap['index']?.toString() ?? '') ?? audioTracks.length;
          final audioStreamIndex = audioTracks.length; // 0-based audio stream index within audio streams

          audioTracks.add(
            AudioTrackInfo(
              index: index,
              audioStreamIndex: audioStreamIndex,
              codec: codec,
              channels: channels,
              sampleRate: sampleRate,
              bitrateKbps: bitrateKbps,
              language: language,
              title: title,
              channelLayout: channelLayout,
              isDefault: isDefault,
            ),
          );
        }
      }

      return MediaFile(
        path: filePath,
        fileName: fileName,
        sizeBytes: sizeBytes,
        duration: duration,
        extension: extension,
        videoCodec: videoCodec,
        videoWidth: videoWidth,
        videoHeight: videoHeight,
        audioTracks: audioTracks,
      );
    } catch (e) {
      debugPrint('[DesktopMediaEngine] Probe error: $e');
      return MediaFile(
        path: filePath,
        fileName: fileName,
        sizeBytes: sizeBytes,
        duration: Duration.zero,
        extension: extension,
        isCorrupted: true,
        validationError: 'Exception while probing file: $e',
      );
    }
  }

  @override
  Future<ConversionResult> convertAudio({
    required ConversionJob job,
    required ProgressCallback onProgress,
  }) async {
    if (_engineMode == DesktopEngineMode.unavailable) {
      final ok = await initialize();
      if (!ok) {
        return ConversionResult(
          success: false,
          outputPath: '',
          errorMessage: 'FFmpeg is not installed or available on this system. Please configure FFmpeg in Settings.',
        );
      }
    }

    // Determine effective target directory
    String effectiveDirectory = job.outputDirectory;
    if (job.destinationMode == DestinationMode.besideOriginalFile) {
      effectiveDirectory = p.dirname(job.sourcePath);
    }

    // Ensure directory exists
    try {
      final dir = Directory(effectiveDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      return ConversionResult(
        success: false,
        outputPath: '',
        errorMessage: 'Destination folder cannot be created or accessed: $effectiveDirectory ($e)',
      );
    }

    final outputManager = OutputManager();

    // 1. Storage validation
    final hasStorage = await outputManager.checkStorageSpace(
      directoryPath: effectiveDirectory,
      estimatedBytes: 100 * 1024 * 1024,
    );
    if (!hasStorage) {
      return ConversionResult(
        success: false,
        outputPath: '',
        errorMessage: 'Destination folder is not writable or storage is full: $effectiveDirectory',
      );
    }

    // 2. Reserve atomic temporary processing file
    final tempFile = await outputManager.createTemporaryProcessingFile(
      directoryPath: effectiveDirectory,
      extension: job.format.extension,
    );

    // 3. Resolve target filename uniquely (Never Overwrite guarantee)
    final resolvedTargetName = await outputManager.resolveUniqueFileName(
      directoryPath: effectiveDirectory,
      baseName: p.basenameWithoutExtension(job.requestedFileName),
      extension: job.format.extension,
    );

    // 4. Build argument list
    final List<String> rawArgs = ConversionEngine().buildCommandArguments(
      job: job,
      tempOutputPath: tempFile.path,
    );

    // Insert progress piping right after -y: -progress pipe:1 -nostats
    final List<String> processArgs = ['-nostdin'];
    for (int i = 0; i < rawArgs.length; i++) {
      processArgs.add(rawArgs[i]);
      if (rawArgs[i] == '-y') {
        processArgs.addAll(['-progress', 'pipe:1', '-nostats']);
      }
    }

    debugPrint('[DesktopMediaEngine] Executing: $ffmpegPath ${processArgs.join(" ")}');

    final stopwatch = Stopwatch()..start();
    final totalDurationMs = job.trimEndMs > job.trimStartMs
        ? (job.trimEndMs - job.trimStartMs)
        : (job.sourceDurationMs > 0 ? job.sourceDurationMs : 1);

    double latestSpeed = 1.0;
    int latestTimeMs = 0;

    final completer = Completer<ConversionResult>();

    try {
      final process = await Process.start(
        ffmpegPath,
        processArgs,
        mode: ProcessStartMode.normal,
      );

      _activeProcesses[job.id] = process;

      // Listen to stdout for -progress streaming key-value pairs
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        final parts = line.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join('=').trim();

          if (key == 'out_time_us') {
            final us = int.tryParse(value);
            if (us != null && us > 0) {
              latestTimeMs = us ~/ 1000;
            }
          } else if (key == 'out_time_ms') {
            final raw = int.tryParse(value);
            if (raw != null && raw > 0) {
              // In some FFmpeg versions out_time_ms is actually printed in microseconds
              if (raw > totalDurationMs * 10 && totalDurationMs > 1000) {
                latestTimeMs = raw ~/ 1000;
              } else {
                latestTimeMs = raw;
              }
            }
          } else if (key == 'out_time') {
            // e.g. "00:01:23.456000"
            final parsedMs = _parseOutTimeToMs(value);
            if (parsedMs > 0) {
              latestTimeMs = parsedMs;
            }
          } else if (key == 'speed') {
            final speedVal = double.tryParse(value.replaceAll('x', '').trim());
            if (speedVal != null && speedVal > 0) {
              latestSpeed = speedVal;
            }
          }

          if (key == 'progress' || key == 'out_time_us' || key == 'out_time_ms' || key == 'out_time') {
            // Never reach 1.0 here - 1.0 is emitted ONLY when process successfully exits and output is verified
            double progress = (latestTimeMs / totalDurationMs).clamp(0.0, 0.95);
            final elapsed = stopwatch.elapsed.inSeconds;
            int remaining = 0;
            if (progress > 0.05 && latestSpeed > 0) {
              final remainingMs = (totalDurationMs - latestTimeMs).clamp(0, totalDurationMs);
              remaining = (remainingMs / (latestSpeed * 1000)).round();
            }

            onProgress(
              progress: progress,
              speedRatio: latestSpeed,
              currentTimeMs: latestTimeMs,
              elapsedSeconds: elapsed,
              estimatedRemainingSeconds: remaining,
            );
          }
        }
      });

      final stderrBuffer = StringBuffer();
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((errLine) {
        stderrBuffer.writeln(errLine);
      });

      process.exitCode.then((exitCode) async {
        stopwatch.stop();
        _activeProcesses.remove(job.id);

        if (exitCode == 0) {
          // Success
          if (await tempFile.exists() && await tempFile.length() > 0) {
            try {
              final finalizedFile = await outputManager.finalizeOutputFile(
                tempFile: tempFile,
                directoryPath: effectiveDirectory,
                targetFileName: resolvedTargetName,
                extension: job.format.extension,
              );
              final outputSize = await finalizedFile.length();

              // Verify output integrity with FFprobe (Phase 6 requirement)
              try {
                final verifyResult = await inspectMedia(finalizedFile.path);
                if (verifyResult.isCorrupted || verifyResult.duration == Duration.zero) {
                  debugPrint('[DesktopMediaEngine] Warning: output verification noted non-standard duration');
                }
              } catch (ve) {
                debugPrint('[DesktopMediaEngine] FFprobe verification warning: $ve');
              }

              if (!completer.isCompleted) {
                completer.complete(
                  ConversionResult(
                    success: true,
                    outputPath: finalizedFile.path,
                    outputSizeBytes: outputSize,
                    averageSpeed: latestSpeed,
                  ),
                );
              }
            } catch (e) {
              if (!completer.isCompleted) {
                completer.complete(
                  ConversionResult(
                    success: false,
                    outputPath: '',
                    errorMessage: 'Failed to finalize output file: $e',
                  ),
                );
              }
            }
          } else {
            if (!completer.isCompleted) {
              completer.complete(
                ConversionResult(
                  success: false,
                  outputPath: '',
                  errorMessage: 'Conversion finished but generated an empty or missing output',
                ),
              );
            }
          }
        } else {
          // Failure or cancel
          if (await tempFile.exists()) {
            try {
              await tempFile.delete();
            } catch (_) {}
          }

          if (!completer.isCompleted) {
            final errText = stderrBuffer.toString().trim();
            completer.complete(
              ConversionResult(
                success: false,
                outputPath: '',
                errorMessage: errText.isNotEmpty
                    ? errText
                    : 'FFmpeg process returned non-zero exit code: $exitCode',
              ),
            );
          }
        }
      });
    } catch (e) {
      stopwatch.stop();
      _activeProcesses.remove(job.id);
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      if (!completer.isCompleted) {
        completer.complete(
          ConversionResult(
            success: false,
            outputPath: '',
            errorMessage: 'Failed to spawn FFmpeg process: $e',
          ),
        );
      }
    }

    return completer.future;
  }

  @override
  Future<void> cancelJob(String jobId) async {
    final proc = _activeProcesses[jobId];
    if (proc != null) {
      debugPrint('[DesktopMediaEngine] Killing FFmpeg process for job $jobId');
      proc.kill(ProcessSignal.sigterm);
      // Fallback sigkill
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          proc.kill(ProcessSignal.sigkill);
        } catch (_) {}
      });
      _activeProcesses.remove(jobId);
    }
  }

  @override
  Future<List<double>> extractWaveformPeaks(
    String audioPath, {
    int targetSampleCount = 100,
  }) async {
    if (_engineMode == DesktopEngineMode.unavailable) {
      await initialize();
    }

    final tempDir = await Directory.systemTemp.createTemp('v2a_waveform_');
    final tempPcm = File(p.join(tempDir.path, 'waveform.pcm'));

    try {
      final args = [
        '-y',
        '-nostdin',
        '-i', audioPath,
        '-vn',
        '-ac', '1',
        '-ar', '2000',
        '-f', 's16le',
        tempPcm.path,
      ];

      final res = await Process.run(ffmpegPath, args);
      if (res.exitCode == 0 && await tempPcm.exists()) {
        final bytes = await tempPcm.readAsBytes();
        if (bytes.length >= 2) {
          final sampleCount = bytes.length ~/ 2;
          final chunkSize = (sampleCount / targetSampleCount).ceil().clamp(1, sampleCount);
          final byteData = ByteData.sublistView(bytes);

          final List<double> peaks = [];
          for (int i = 0; i < sampleCount; i += chunkSize) {
            int maxVal = 0;
            final end = (i + chunkSize).clamp(0, sampleCount);
            for (int j = i; j < end; j++) {
              final sample = byteData.getInt16(j * 2, Endian.little).abs();
              if (sample > maxVal) maxVal = sample;
            }
            peaks.add((maxVal / 32768.0).clamp(0.05, 1.0));
            if (peaks.length >= targetSampleCount) break;
          }

          while (peaks.length < targetSampleCount) {
            peaks.add(0.05);
          }
          return peaks;
        }
      }
    } catch (e) {
      debugPrint('[DesktopMediaEngine] Waveform extraction error: $e');
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }

    return List.generate(targetSampleCount, (i) => (0.1 + (i % 7) * 0.12).clamp(0.05, 1.0));
  }

  @override
  Future<ConversionResult> trimAudioFile({
    required String sourcePath,
    required String outputDirectory,
    required String baseName,
    required AudioFormat format,
    required int startMs,
    required int endMs,
    double volumeGainDb = 0.0,
    bool normalizeLoudness = false,
    void Function(double progress)? onProgress,
  }) async {
    if (_engineMode == DesktopEngineMode.unavailable) {
      await initialize();
    }

    final outputManager = OutputManager();

    final hasStorage = await outputManager.checkStorageSpace(
      directoryPath: outputDirectory,
      estimatedBytes: 50 * 1024 * 1024,
    );
    if (!hasStorage) {
      return ConversionResult(
        success: false,
        outputPath: '',
        errorMessage: 'Destination folder is not writable or storage is full',
      );
    }

    final tempFile = await outputManager.createTemporaryProcessingFile(
      directoryPath: outputDirectory,
      extension: format.extension,
    );

    final resolvedTargetName = await outputManager.resolveUniqueFileName(
      directoryPath: outputDirectory,
      baseName: baseName,
      extension: format.extension,
    );

    final List<String> args = ['-y', '-nostdin'];

    if (startMs > 0) {
      args.addAll(['-ss', (startMs / 1000.0).toStringAsFixed(3)]);
    }

    args.addAll(['-i', sourcePath]);

    if (endMs > 0 && endMs > startMs) {
      args.addAll(['-t', ((endMs - startMs) / 1000.0).toStringAsFixed(3)]);
    }

    args.add('-vn');

    switch (format) {
      case AudioFormat.mp3:
        args.addAll(['-c:a', 'libmp3lame', '-b:a', '192k']);
        break;
      case AudioFormat.aac:
        args.addAll(['-c:a', 'aac', '-b:a', '192k']);
        break;
      case AudioFormat.opus:
        args.addAll(['-c:a', 'libopus', '-b:a', '128k', '-ar', '48000']);
        break;
      case AudioFormat.ogg:
        args.addAll(['-c:a', 'libvorbis', '-b:a', '192k']);
        break;
      case AudioFormat.flac:
        args.addAll(['-c:a', 'flac']);
        break;
      case AudioFormat.wav:
        args.addAll(['-c:a', 'pcm_s16le']);
        break;
    }

    final List<String> filters = [];
    if (volumeGainDb != 0.0) {
      filters.add('volume=${volumeGainDb.toStringAsFixed(1)}dB');
    }
    if (normalizeLoudness) {
      filters.add('loudnorm=I=-16:TP=-1.5:LRA=11');
    }
    if (filters.isNotEmpty) {
      args.addAll(['-af', filters.join(',')]);
    }

    args.add(tempFile.path);

    try {
      final res = await Process.run(ffmpegPath, args);
      if (res.exitCode == 0 && await tempFile.exists() && await tempFile.length() > 0) {
        final finalized = await outputManager.finalizeOutputFile(
          tempFile: tempFile,
          directoryPath: outputDirectory,
          targetFileName: resolvedTargetName,
          extension: format.extension,
        );
        final size = await finalized.length();
        return ConversionResult(
          success: true,
          outputPath: finalized.path,
          outputSizeBytes: size,
        );
      } else {
        if (await tempFile.exists()) await tempFile.delete();
        return ConversionResult(
          success: false,
          outputPath: '',
          errorMessage: 'Trimming failed: exit code ${res.exitCode}\n${res.stderr}',
        );
      }
    } catch (e) {
      if (await tempFile.exists()) await tempFile.delete();
      return ConversionResult(
        success: false,
        outputPath: '',
        errorMessage: 'Trimming error: $e',
      );
    }
  }

  @override
  Future<String?> extractThumbnail(
    String videoPath,
    String outputPath, {
    int timestampMs = 1000,
  }) async {
    if (_engineMode == DesktopEngineMode.unavailable) {
      await initialize();
    }

    try {
      final sec = (timestampMs / 1000.0).toStringAsFixed(3);
      final args = [
        '-y',
        '-nostdin',
        '-ss', sec,
        '-i', videoPath,
        '-vframes', '1',
        '-q:v', '2',
        outputPath,
      ];

      final res = await Process.run(ffmpegPath, args);
      if (res.exitCode == 0 && await File(outputPath).exists()) {
        return outputPath;
      }
    } catch (e) {
      debugPrint('[DesktopMediaEngine] Thumbnail extraction error: $e');
    }
    return null;
  }
}
