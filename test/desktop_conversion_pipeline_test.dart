import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v2a/models/conversion_config.dart';
import 'package:v2a/models/conversion_job.dart';
import 'package:v2a/services/desktop_media_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('DesktopMediaEngine converts WAV test file to MP3', () async {
    final engine = DesktopMediaEngine();
    final ok = await engine.initialize();
    if (!ok || !engine.isAvailable) {
      // FFmpeg not present on runner; skip test gracefully
      return;
    }

    final currentDir = Directory.current.path;
    final testFile = '$currentDir/test_input_pipeline.wav';
    
    // Dynamically generate test fixture
    await Process.run('ffmpeg', [
      '-f', 'lavfi', '-i', 'sine=frequency=1000:duration=2',
      '-y', testFile,
    ]);
    expect(File(testFile).existsSync(), isTrue);

    final inspected = await engine.inspectMedia(testFile);
    expect(inspected.duration.inMilliseconds, greaterThan(0));

    final job = ConversionJob(
      id: 'pipeline_test_job_1',
      sourcePath: testFile,
      sourceFileName: 'test_input.wav',
      sourceSizeBytes: File(testFile).lengthSync(),
      sourceDurationMs: inspected.duration.inMilliseconds,
      selectedAudioTrackIndex: 0,
      audioStreamIndex: 0,
      selectedAudioCodec: 'pcm_s16le',
      requestedFileName: 'pipeline_test_output',
      outputDirectory: currentDir,
      format: AudioFormat.mp3,
      mode: ConversionMode.reEncode,
      preset: ConversionPreset.balanced,
      bitrateKbps: 192,
      sampleRateHz: 44100,
      channelMode: ChannelMode.stereo,
    );

    double lastProgress = 0.0;
    final result = await engine.convertAudio(
      job: job,
      onProgress: ({
        required double progress,
        required double speedRatio,
        required int currentTimeMs,
        required int elapsedSeconds,
        required int estimatedRemainingSeconds,
      }) {
        lastProgress = progress;
      },
    );

    expect(result.success, isTrue);
    expect(lastProgress, greaterThan(0.0));
    print('Result path: ${result.outputPath}');
    print('Result error: ${result.errorMessage}');

    expect(result.success, isTrue);
    expect(File(result.outputPath).existsSync(), isTrue);
    expect(File(result.outputPath).lengthSync(), greaterThan(0));

    // Clean up
    if (File(testFile).existsSync()) {
      File(testFile).deleteSync();
    }
    if (File(result.outputPath).existsSync()) {
      File(result.outputPath).deleteSync();
    }
  });
}
