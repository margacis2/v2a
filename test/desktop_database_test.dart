import 'package:flutter_test/flutter_test.dart';
import 'package:v2a/models/conversion_config.dart';
import 'package:v2a/models/conversion_job.dart';
import 'package:v2a/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DatabaseService initializes and inserts/retrieves job', () async {
    final dbService = DatabaseService();
    final db = await dbService.database;
    print('DB instance: $db');
    expect(db, isNotNull);

    final job = ConversionJob(
      id: 'db_test_1',
      sourcePath: 'C:/fake/path/video.mp4',
      sourceFileName: 'video.mp4',
      sourceSizeBytes: 1024,
      sourceDurationMs: 5000,
      selectedAudioTrackIndex: 0,
      audioStreamIndex: 0,
      selectedAudioCodec: 'aac',
      requestedFileName: 'video_audio',
      outputDirectory: 'C:/fake/output',
      format: AudioFormat.mp3,
      mode: ConversionMode.reEncode,
      preset: ConversionPreset.balanced,
      bitrateKbps: 192,
      sampleRateHz: 44100,
      channelMode: ChannelMode.stereo,
    );

    await dbService.insertJob(job);
    final allJobs = await dbService.getAllJobs();
    print('All jobs count: ${allJobs.length}');
    expect(allJobs.any((j) => j.id == 'db_test_1'), isTrue);

    await dbService.deleteJob('db_test_1');
    final afterDelete = await dbService.getAllJobs();
    expect(afterDelete.any((j) => j.id == 'db_test_1'), isFalse);
  });
}
