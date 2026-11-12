import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/conversion_config.dart';
import '../models/conversion_job.dart';
import '../models/media_file.dart';
import 'desktop_media_engine.dart';
import 'media_metadata_service.dart';
import 'output_manager.dart';

typedef ProgressCallback = void Function({
  required double progress,
  required double speedRatio,
  required int currentTimeMs,
  required int elapsedSeconds,
  required int estimatedRemainingSeconds,
});

class ConversionResult {
  final bool success;
  final String outputPath;
  final int outputSizeBytes;
  final double averageSpeed;
  final String? errorMessage;

  ConversionResult({
    required this.success,
    required this.outputPath,
    this.outputSizeBytes = 0,
    this.averageSpeed = 0.0,
    this.errorMessage,
  });
}

class ConversionEngine {
  static final ConversionEngine _instance = ConversionEngine._internal();
  factory ConversionEngine() => _instance;
  ConversionEngine._internal();

  final Map<String, int> _activeSessionIds = {};

  /// Checks if a source audio codec is directly stream-copy compatible with the destination format
  bool isStreamCopyCompatible(String sourceCodec, AudioFormat targetFormat) {
    final src = sourceCodec.toLowerCase();
    switch (targetFormat) {
      case AudioFormat.aac:
        return src == 'aac';
      case AudioFormat.mp3:
        return src == 'mp3';
      case AudioFormat.opus:
        return src == 'opus';
      case AudioFormat.ogg:
        return src == 'vorbis' || src == 'opus';
      case AudioFormat.flac:
        return src == 'flac';
      case AudioFormat.wav:
        return src.startsWith('pcm');
    }
  }

  /// Cancels an active conversion job immediately
  Future<void> cancelJob(String jobId) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return DesktopMediaEngine().cancelJob(jobId);
    }
    final sessionId = _activeSessionIds[jobId];
    if (sessionId != null) {
      debugPrint('[ConversionEngine] Cancelling FFmpeg session $sessionId for job $jobId');
      await FFmpegKit.cancel(sessionId);
      _activeSessionIds.remove(jobId);
    }
  }

  /// Alias for cancelling a conversion session by job ID
  Future<void> cancelSession(String jobId) => cancelJob(jobId);

  /// Builds argument list for conversion
  List<String> buildCommandArguments({
    required ConversionJob job,
    required String tempOutputPath,
  }) => _buildCommandArguments(job: job, tempOutputPath: tempOutputPath);

  @visibleForTesting
  List<String> buildCommandArgumentsForTesting({
    required ConversionJob job,
    required String tempOutputPath,
  }) => buildCommandArguments(job: job, tempOutputPath: tempOutputPath);

  /// Analyzes media file on mobile
  Future<MediaFile> analyzeMediaFileMobile(String filePath) {
    return MediaMetadataService().analyzeMediaFile(filePath);
  }

  /// Executes conversion for the given job.
  /// Follows Section 8 duplicate-safe rules, temporary atomic staging, and full progress callbacks.
  Future<ConversionResult> executeConversion({
    required ConversionJob job,
    required ProgressCallback onProgress,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return DesktopMediaEngine().convertAudio(job: job, onProgress: onProgress);
    }
    final outputManager = OutputManager();

    // 1. Storage validation
    final hasStorage = await outputManager.checkStorageSpace(
      directoryPath: job.outputDirectory,
      estimatedBytes: 100 * 1024 * 1024,
    );
    if (!hasStorage) {
      return ConversionResult(
        success: false,
        outputPath: '',
        errorMessage: 'Destination folder is not writable or storage is full: ${job.outputDirectory}',
      );
    }

    // 2. Reserve atomic temporary processing file
    final tempFile = await outputManager.createTemporaryProcessingFile(
      directoryPath: job.outputDirectory,
      extension: job.format.extension,
    );

    // 3. Resolve target filename uniquely (Never Overwrite guarantee)
    final resolvedTargetName = await outputManager.resolveUniqueFileName(
      directoryPath: job.outputDirectory,
      baseName: p.basenameWithoutExtension(job.requestedFileName),
      extension: job.format.extension,
    );

    // 4. Build argument list
    final List<String> args = _buildCommandArguments(
      job: job,
      tempOutputPath: tempFile.path,
    );

    debugPrint('[ConversionEngine] Executing arguments: ${args.join(" ")}');

    final stopwatch = Stopwatch()..start();
    final totalDurationMs = job.trimEndMs > job.trimStartMs
        ? (job.trimEndMs - job.trimStartMs)
        : (job.sourceDurationMs > 0 ? job.sourceDurationMs : 1);

    double latestSpeed = 1.0;
    int latestTimeMs = 0;

    final completer = Completer<ConversionResult>();

    // 5. Execute with native argument list (safe against space splitting and quoting issues)
    final session = await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        stopwatch.stop();
        _activeSessionIds.remove(job.id);

        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          // Verify temporary file integrity
          if (await tempFile.exists() && await tempFile.length() > 0) {
            try {
              // Atomically finalize output file
              final finalizedFile = await outputManager.finalizeOutputFile(
                tempFile: tempFile,
                directoryPath: job.outputDirectory,
                targetFileName: resolvedTargetName,
                extension: job.format.extension,
              );
              final outputSize = await finalizedFile.length();

              completer.complete(ConversionResult(
                success: true,
                outputPath: finalizedFile.path,
                outputSizeBytes: outputSize,
                averageSpeed: latestSpeed,
              ));
            } catch (e) {
              completer.complete(ConversionResult(
                success: false,
                outputPath: '',
                errorMessage: 'Failed to finalize output file: $e',
              ));
            }
          } else {
            completer.complete(ConversionResult(
              success: false,
              outputPath: '',
              errorMessage: 'Conversion finished but generated an empty or missing output',
            ));
          }
        } else if (ReturnCode.isCancel(returnCode)) {
          // Clean up temporary file
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          completer.complete(ConversionResult(
            success: false,
            outputPath: '',
            errorMessage: 'Conversion was cancelled by user',
          ));
        } else {
          // Failed
          final failStackTrace = await session.getFailStackTrace();
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          completer.complete(ConversionResult(
            success: false,
            outputPath: '',
            errorMessage: failStackTrace ?? 'FFmpeg process returned error code ${returnCode?.getValue()}',
          ));
        }
      },
      (log) {
        // Debug logging if needed
      },
      (Statistics stats) {
        final timeMs = stats.getTime();
        final speed = stats.getSpeed();

        if (speed > 0) latestSpeed = speed;
        if (timeMs > 0) latestTimeMs = timeMs;

        double progress = (latestTimeMs / totalDurationMs).clamp(0.0, 0.99);
        final elapsed = stopwatch.elapsed.inSeconds;
        int remaining = 0;
        if (progress > 0.05 && speed > 0) {
          final remainingMs = (totalDurationMs - latestTimeMs).clamp(0, totalDurationMs);
          remaining = (remainingMs / (speed * 1000)).round();
        }

        onProgress(
          progress: progress,
          speedRatio: latestSpeed,
          currentTimeMs: latestTimeMs,
          elapsedSeconds: elapsed,
          estimatedRemainingSeconds: remaining,
        );
      },
    );

    final sessionId = session.getSessionId();
    if (sessionId != null) {
      _activeSessionIds[job.id] = sessionId;
    }

    return completer.future;
  }

  /// Builds optimized, streaming FFmpeg arguments for Mode A, Mode B, and Mode C
  List<String> _buildCommandArguments({
    required ConversionJob job,
    required String tempOutputPath,
  }) {
    final List<String> args = ['-y'];

    // Fast seeking before input if trimming is requested
    if (job.trimStartMs > 0) {
      final startSec = job.trimStartMs / 1000.0;
      args.addAll(['-ss', startSec.toStringAsFixed(3)]);
    }

    if (job.trimEndMs > 0 && job.trimEndMs > job.trimStartMs) {
      final durationSec = (job.trimEndMs - job.trimStartMs) / 1000.0;
      args.addAll(['-t', durationSec.toStringAsFixed(3)]);
    }

    // Input file (streaming reading)
    args.addAll(['-i', job.sourcePath]);

    // Map specific audio track and drop video
    if (job.selectedAudioTrackIndex >= 0) {
      args.addAll(['-vn', '-map', '0:${job.selectedAudioTrackIndex}']);
    } else {
      args.addAll(['-vn', '-map', '0:a:0?']);
    }

    // Check if Mode A (Fastest Compatible Stream Copy) is applicable
    final canStreamCopy = job.mode == ConversionMode.fastestCompatible &&
        isStreamCopyCompatible(job.selectedAudioCodec, job.format) &&
        job.volumeGainDb == 0.0 &&
        !job.normalizeLoudness &&
        job.fadeInSec == 0.0 &&
        job.fadeOutSec == 0.0 &&
        !job.trimSilence &&
        job.channelMode == ChannelMode.keepOriginal;

    if (canStreamCopy) {
      // Direct packet stream copy: maximum speed, zero CPU re-encoding overhead
      args.addAll(['-c:a', 'copy']);
    } else {
      // Mode B or Mode C: Re-encode with requested codecs and audio filter pipeline
      args.addAll(_buildEncodingArguments(job));
    }

    // Metadata preservation and custom tags
    args.addAll(_buildMetadataArguments(job));

    // Force output container format and destination
    args.add(tempOutputPath);

    return args;
  }

  /// Builds encoding & audio filter parameters for Mode B and C
  List<String> _buildEncodingArguments(ConversionJob job) {
    final List<String> args = [];

    // Select audio encoder
    switch (job.format) {
      case AudioFormat.mp3:
        args.addAll(['-c:a', 'libmp3lame']);
        if (job.vbrEnabled) {
          args.addAll(['-q:a', '${job.vbrQuality}']);
        } else {
          args.addAll(['-b:a', '${job.bitrateKbps}k']);
        }
        break;
      case AudioFormat.aac:
        args.addAll(['-c:a', 'aac', '-b:a', '${job.bitrateKbps}k']);
        break;
      case AudioFormat.opus:
        args.addAll(['-c:a', 'libopus', '-b:a', '${job.bitrateKbps}k']);
        // Opus strictly requires 8000, 12000, 16000, 24000, or 48000 Hz
        const opusRates = [8000, 12000, 16000, 24000, 48000];
        if (job.sampleRateHz > 0 && !opusRates.contains(job.sampleRateHz)) {
          args.addAll(['-ar', '48000']);
        }
        break;
      case AudioFormat.ogg:
        args.addAll(['-c:a', 'libvorbis', '-b:a', '${job.bitrateKbps}k']);
        break;
      case AudioFormat.flac:
        args.addAll(['-c:a', 'flac', '-compression_level', '5']);
        break;
      case AudioFormat.wav:
        args.addAll(['-c:a', 'pcm_s16le']);
        break;
    }

    // Sample rate
    if (job.sampleRateHz > 0 && (job.format != AudioFormat.opus || [8000, 12000, 16000, 24000, 48000].contains(job.sampleRateHz))) {
      args.addAll(['-ar', '${job.sampleRateHz}']);
    }

    // Channels
    if (job.channelMode.channelCount != null) {
      args.addAll(['-ac', '${job.channelMode.channelCount}']);
    }

    // Audio Filters Pipeline
    final List<String> audioFilters = [];

    // Volume adjustment
    if (job.volumeGainDb != 0.0) {
      audioFilters.add('volume=${job.volumeGainDb.toStringAsFixed(1)}dB');
    }

    // Loudness normalization
    if (job.normalizeLoudness) {
      audioFilters.add('loudnorm=I=-16:TP=-1.5:LRA=11');
    }

    // Fade-in
    if (job.fadeInSec > 0) {
      audioFilters.add('afade=t=in:ss=0:d=${job.fadeInSec.toStringAsFixed(1)}');
    }

    // Fade-out
    if (job.fadeOutSec > 0 && job.sourceDurationMs > 0) {
      final totalSec = (job.trimEndMs > 0 ? job.trimEndMs : job.sourceDurationMs) / 1000.0;
      final fadeStart = (totalSec - job.fadeOutSec).clamp(0.0, totalSec);
      audioFilters.add('afade=t=out:st=${fadeStart.toStringAsFixed(1)}:d=${job.fadeOutSec.toStringAsFixed(1)}');
    }

    // Silence removal
    if (job.trimSilence) {
      audioFilters.add('silenceremove=stop_periods=-1:stop_duration=1:stop_threshold=-50dB');
    }

    if (audioFilters.isNotEmpty) {
      args.addAll(['-af', audioFilters.join(',')]);
    }

    return args;
  }

  /// Builds ID3 / container metadata tags
  List<String> _buildMetadataArguments(ConversionJob job) {
    final List<String> args = [];
    final meta = job.metadata;

    if (meta.title != null && meta.title!.trim().isNotEmpty) {
      args.addAll(['-metadata', 'title=${meta.title!.trim()}']);
    }
    if (meta.artist != null && meta.artist!.trim().isNotEmpty) {
      args.addAll(['-metadata', 'artist=${meta.artist!.trim()}']);
    }
    if (meta.album != null && meta.album!.trim().isNotEmpty) {
      args.addAll(['-metadata', 'album=${meta.album!.trim()}']);
    }
    if (meta.year != null && meta.year!.trim().isNotEmpty) {
      args.addAll(['-metadata', 'date=${meta.year!.trim()}']);
    }
    if (meta.genre != null && meta.genre!.trim().isNotEmpty) {
      args.addAll(['-metadata', 'genre=${meta.genre!.trim()}']);
    }

    return args;
  }

  /// Extracts genuine downsampled audio waveform amplitude peaks (0.0 to 1.0)
  Future<List<double>> extractWaveformPeaks(String audioPath, {int targetSampleCount = 120}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return DesktopMediaEngine().extractWaveformPeaks(audioPath, targetSampleCount: targetSampleCount);
    }
    final tempDir = await getTemporaryDirectory();
    final tempPcm = File('${tempDir.path}/waveform_${DateTime.now().millisecondsSinceEpoch}.raw');

    try {
      // Decode downsampled mono 16-bit PCM at 2000 Hz for swift analysis
      final args = [
        '-y',
        '-i', audioPath,
        '-vn',
        '-ac', '1',
        '-ar', '2000',
        '-f', 's16le',
        tempPcm.path,
      ];

      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode) && await tempPcm.exists()) {
        final bytes = await tempPcm.readAsBytes();
        await tempPcm.delete();

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
      debugPrint('[ConversionEngine] Error generating waveform: $e');
    } finally {
      if (await tempPcm.exists()) {
        try {
          await tempPcm.delete();
        } catch (_) {}
      }
    }

    // Fallback pseudo-peaks if decode is unavailable
    return List.generate(targetSampleCount, (i) => (0.1 + (i % 7) * 0.12).clamp(0.05, 1.0));
  }

  /// Trims an audio file directly with atomic staging and duplicate protection
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
    if (!Platform.isAndroid && !Platform.isIOS) {
      return DesktopMediaEngine().trimAudioFile(
        sourcePath: sourcePath,
        outputDirectory: outputDirectory,
        baseName: baseName,
        format: format,
        startMs: startMs,
        endMs: endMs,
        volumeGainDb: volumeGainDb,
        normalizeLoudness: normalizeLoudness,
        onProgress: onProgress,
      );
    }
    final outputManager = OutputManager();

    // 1. Storage check
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

    // 2. Reserve atomic temporary processing file
    final tempFile = await outputManager.createTemporaryProcessingFile(
      directoryPath: outputDirectory,
      extension: format.extension,
    );

    // 3. Resolve target filename uniquely (Never Overwrite guarantee)
    final resolvedTargetName = await outputManager.resolveUniqueFileName(
      directoryPath: outputDirectory,
      baseName: baseName,
      extension: format.extension,
    );

    final List<String> args = ['-y'];

    if (startMs > 0) {
      args.addAll(['-ss', (startMs / 1000.0).toStringAsFixed(3)]);
    }
    if (endMs > startMs) {
      args.addAll(['-to', (endMs / 1000.0).toStringAsFixed(3)]);
    }

    args.addAll(['-i', sourcePath, '-vn']);

    // Check if stream copy is possible
    final sourceExt = p.extension(sourcePath).replaceAll('.', '').toLowerCase();
    final canStreamCopy = sourceExt == format.extension && volumeGainDb == 0.0 && !normalizeLoudness;

    if (canStreamCopy) {
      args.addAll(['-c:a', 'copy']);
    } else {
      switch (format) {
        case AudioFormat.mp3:
          args.addAll(['-c:a', 'libmp3lame', '-b:a', '256k']);
          break;
        case AudioFormat.aac:
          args.addAll(['-c:a', 'aac', '-b:a', '256k']);
          break;
        case AudioFormat.opus:
          args.addAll(['-c:a', 'libopus', '-b:a', '128k', '-ar', '48000']);
          break;
        case AudioFormat.ogg:
          args.addAll(['-c:a', 'libvorbis', '-b:a', '192k']);
          break;
        case AudioFormat.flac:
          args.addAll(['-c:a', 'flac', '-compression_level', '5']);
          break;
        case AudioFormat.wav:
          args.addAll(['-c:a', 'pcm_s16le', '-ar', '48000']);
          break;
      }

      final filters = <String>[];
      if (volumeGainDb != 0.0) {
        filters.add('volume=${volumeGainDb.toStringAsFixed(1)}dB');
      }
      if (normalizeLoudness) {
        filters.add('loudnorm=I=-16:TP=-1.5:LRA=11');
      }
      if (filters.isNotEmpty) {
        args.addAll(['-af', filters.join(',')]);
      }
    }

    args.add(tempFile.path);

    final durationMs = (endMs - startMs).clamp(1, 999999999);
    final completer = Completer<ConversionResult>();

    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          if (await tempFile.exists() && await tempFile.length() > 0) {
            final finalized = await outputManager.finalizeOutputFile(
              tempFile: tempFile,
              directoryPath: outputDirectory,
              targetFileName: resolvedTargetName,
              extension: format.extension,
            );
            final size = await finalized.length();
            completer.complete(ConversionResult(
              success: true,
              outputPath: finalized.path,
              outputSizeBytes: size,
            ));
          } else {
            completer.complete(ConversionResult(
              success: false,
              outputPath: '',
              errorMessage: 'Trim completed but generated an empty output file',
            ));
          }
        } else {
          if (await tempFile.exists()) await tempFile.delete();
          final failLog = await session.getFailStackTrace();
          completer.complete(ConversionResult(
            success: false,
            outputPath: '',
            errorMessage: failLog ?? 'FFmpeg trimming error',
          ));
        }
      },
      (log) {},
      (statistics) {
        if (onProgress != null) {
          final timeMs = statistics.getTime();
          if (timeMs > 0) {
            onProgress((timeMs / durationMs).clamp(0.0, 0.99));
          }
        }
      },
    );

    return completer.future;
  }
}
