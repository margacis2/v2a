import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v2a/models/conversion_config.dart';
import 'package:v2a/models/conversion_job.dart';
import 'package:v2a/services/job_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Enqueue job into JobQueueService and observe state lifecycle transitions', () async {
    final queue = JobQueueService();
    await queue.init();

    final currentDir = Directory.current.path;
    final testFile = '$currentDir/test_input_queue.wav';
    
    // Dynamically generate test fixture
    await Process.run('ffmpeg', [
      '-f', 'lavfi', '-i', 'sine=frequency=1000:duration=2',
      '-y', testFile,
    ]);
    expect(File(testFile).existsSync(), isTrue);

    final job = ConversionJob(
      id: 'queue_sim_${DateTime.now().millisecondsSinceEpoch}',
      sourcePath: testFile,
      sourceFileName: 'test_input.wav',
      sourceSizeBytes: File(testFile).lengthSync(),
      sourceDurationMs: 3000,
      selectedAudioTrackIndex: 0,
      audioStreamIndex: 0,
      selectedAudioCodec: 'pcm_s16le',
      requestedFileName: 'queue_sim_output',
      outputDirectory: currentDir,
      format: AudioFormat.mp3,
      mode: ConversionMode.reEncode,
      preset: ConversionPreset.balanced,
      bitrateKbps: 192,
      sampleRateHz: 44100,
      channelMode: ChannelMode.stereo,
    );

    final statuses = <JobStatus>[];
    queue.addListener(() {
      final current = queue.jobs.firstWhere((j) => j.id == job.id, orElse: () => job);
      statuses.add(current.status);
      print('Queue listener update: job status=${current.status}, progress=${current.progress}');
    });

    print('Enqueuing batch...');
    await queue.enqueueBatch([job]);
    print('Enqueued batch. Initial queue job status: ${queue.jobs.firstWhere((j) => j.id == job.id).status}');

    // Wait for conversion to finish
    int attempts = 0;
    while (attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 200));
      final j = queue.jobs.firstWhere((j) => j.id == job.id);
      if (j.status == JobStatus.completed || j.status == JobStatus.failed) {
        break;
      }
      attempts++;
    }

    final finishedJob = queue.jobs.firstWhere((j) => j.id == job.id);
    print('Finished job status: ${finishedJob.status}');
    print('Finished job finalOutputPath: ${finishedJob.finalOutputPath}');
    print('Finished job error: ${finishedJob.errorMessage}');
    print('Recorded statuses: $statuses');

    expect(finishedJob.status, equals(JobStatus.completed));
    expect(File(finishedJob.finalOutputPath).existsSync(), isTrue);

    // Cleanup
    if (File(testFile).existsSync()) {
      File(testFile).deleteSync();
    }
    if (File(finishedJob.finalOutputPath).existsSync()) {
      File(finishedJob.finalOutputPath).deleteSync();
    }
  });
}
