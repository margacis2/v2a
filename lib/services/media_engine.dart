import 'dart:io';
import '../models/conversion_config.dart';
import '../models/conversion_job.dart';
import '../models/media_file.dart';
import 'conversion_engine.dart';
import 'desktop_media_engine.dart';

/// Common interface for media operations across all platforms
abstract class MediaEngine {
  static MediaEngine? _instance;

  static MediaEngine get instance {
    if (_instance == null) {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        _instance = DesktopMediaEngine();
      } else {
        _instance = _AndroidMediaEngineAdapter();
      }
    }
    return _instance!;
  }

  /// Initialize engine and detect binary status
  Future<bool> initialize();

  /// Retrieve installed FFmpeg version description
  Future<String> getVersion();

  /// Probe and extract complete metadata for video or audio file
  Future<MediaFile> inspectMedia(String filePath);

  /// Convert or extract audio with streaming progress
  Future<ConversionResult> convertAudio({
    required ConversionJob job,
    required ProgressCallback onProgress,
  });

  /// Cancel an ongoing conversion
  Future<void> cancelJob(String jobId);

  /// Extract PCM waveform peak values for UI visualization
  Future<List<double>> extractWaveformPeaks(
    String audioPath, {
    int targetSampleCount = 100,
  });

  /// Trim audio file with precise timestamps
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
  });

  /// Extract a thumbnail frame from a video file
  Future<String?> extractThumbnail(
    String videoPath,
    String outputPath, {
    int timestampMs = 1000,
  });
}

/// Adapter that forwards calls on Android to existing ConversionEngine and MediaMetadataService
class _AndroidMediaEngineAdapter implements MediaEngine {
  @override
  Future<bool> initialize() async => true;

  @override
  Future<String> getVersion() async => 'FFmpeg Kit (Mobile Android)';

  @override
  Future<MediaFile> inspectMedia(String filePath) async {
    // Uses existing Android MediaMetadataService
    return ConversionEngine().analyzeMediaFileMobile(filePath);
  }

  @override
  Future<ConversionResult> convertAudio({
    required ConversionJob job,
    required ProgressCallback onProgress,
  }) {
    return ConversionEngine().executeConversion(job: job, onProgress: onProgress);
  }

  @override
  Future<void> cancelJob(String jobId) {
    return ConversionEngine().cancelJob(jobId);
  }

  @override
  Future<List<double>> extractWaveformPeaks(
    String audioPath, {
    int targetSampleCount = 100,
  }) {
    return ConversionEngine().extractWaveformPeaks(
      audioPath,
      targetSampleCount: targetSampleCount,
    );
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
  }) {
    return ConversionEngine().trimAudioFile(
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

  @override
  Future<String?> extractThumbnail(
    String videoPath,
    String outputPath, {
    int timestampMs = 1000,
  }) async {
    return null;
  }
}
