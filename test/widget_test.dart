import 'package:flutter_test/flutter_test.dart';
import 'package:v2a/models/conversion_config.dart';
import 'package:v2a/models/media_file.dart';
import 'package:v2a/models/conversion_job.dart';

void main() {
  test('MediaFile formatting and properties test', () {
    final media = MediaFile(
      path: '/sdcard/Download/sample_movie.mp4',
      fileName: 'sample_movie.mp4',
      sizeBytes: 104857600, // 100 MB
      duration: const Duration(hours: 3, minutes: 15, seconds: 42),
      extension: '.mp4',
      videoWidth: 1920,
      videoHeight: 1080,
      videoCodec: 'h264',
      audioTracks: [
        AudioTrackInfo(
          index: 1,
          codec: 'aac',
          language: 'eng',
          title: 'English Stereo',
          channels: 2,
          sampleRate: 48000,
          bitrateKbps: 192,
        ),
      ],
    );

    expect(media.hasAudio, isTrue);
    expect(media.formattedDuration, equals('03:15:42'));
    expect(media.formattedSize, equals('100.0 MB'));
    expect(media.resolutionString, equals('1920x1080'));
    expect(media.primaryAudioTrack?.codec, equals('aac'));
  });

  test('ConversionJob model serialization test', () {
    final job = ConversionJob(
      id: 'test-job-uuid-1',
      sourcePath: '/path/video.mp4',
      sourceFileName: 'video.mp4',
      sourceSizeBytes: 50000000,
      sourceDurationMs: 120000,
      format: AudioFormat.mp3,
      mode: ConversionMode.reEncode,
      preset: ConversionPreset.bestQuality,
      bitrateKbps: 320,
      sampleRateHz: 44100,
      requestedFileName: 'video.mp3',
      outputDirectory: '/output/V2A_Audio',
    );

    final map = job.toMap();
    final reconstructed = ConversionJob.fromMap(map);

    expect(reconstructed.id, equals(job.id));
    expect(reconstructed.format, equals(AudioFormat.mp3));
    expect(reconstructed.bitrateKbps, equals(320));
    expect(reconstructed.status, equals(JobStatus.queued));
  });
}
