import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v2a/models/conversion_config.dart';
import 'package:v2a/models/conversion_job.dart';
import 'package:v2a/services/desktop_media_engine.dart';
import 'package:v2a/services/job_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Phase 8 Multi-track MKV E2E Scenario: Tamil 5.1 & English Stereo Extraction', () async {
    final engine = DesktopMediaEngine();
    final ok = await engine.initialize();
    if (!ok || !engine.isAvailable) {
      return;
    }
    final queue = JobQueueService();
    await queue.init();

    final currentDir = Directory.current.path;
    final mkvPath = '$currentDir/test_multitrack_e2e.mkv';

    // Generate real MKV test fixture with 1 video and 2 audio streams (Tamil 5.1 + English Stereo)
    final res = await Process.run('ffmpeg', [
      '-f', 'lavfi', '-i', 'testsrc=duration=2:size=320x240:rate=30',
      '-f', 'lavfi', '-i', 'sine=frequency=1000:duration=2',
      '-f', 'lavfi', '-i', 'sine=frequency=500:duration=2',
      '-filter_complex', '[1:a]pan=5.1|FL=c0|FR=c0|FC=c0|LFE=c0|BL=c0|BR=c0[a51];[2:a]pan=stereo|FL=c0|FR=c0[astereo]',
      '-map', '0:v:0', '-map', '[a51]', '-map', '[astereo]',
      '-metadata:s:a:0', 'language=tam', '-metadata:s:a:0', 'title=Tamil 5.1 Track',
      '-metadata:s:a:1', 'language=eng', '-metadata:s:a:1', 'title=English Stereo Track',
      '-c:v', 'mpeg4', '-c:a', 'aac',
      '-y', mkvPath,
    ]);
    expect(res.exitCode, 0, reason: 'Failed to create test MKV fixture: ${res.stderr}');
    expect(File(mkvPath).existsSync(), isTrue);

    // Step 1: Inspect media with FFprobe
    final media = await engine.inspectMedia(mkvPath);
    expect(media.audioTracks.length, 2);
    expect(media.audioTracks[0].language, 'tam');
    expect(media.audioTracks[0].channels, 6);
    expect(media.audioTracks[0].channelLayout, contains('5.1'));
    expect(media.audioTracks[1].language, 'eng');
    expect(media.audioTracks[1].channels, 2);
    expect(media.audioTracks[1].channelLayout, contains('stereo'));

    // Step 2: Convert Tamil track to stereo MP3 (downmix test)
    final tamilMp3Job = ConversionJob(
      id: 'e2e_tamil_mp3_${DateTime.now().millisecondsSinceEpoch}',
      sourcePath: mkvPath,
      sourceFileName: 'test_multitrack_e2e.mkv',
      sourceSizeBytes: File(mkvPath).lengthSync(),
      sourceDurationMs: media.duration.inMilliseconds,
      selectedAudioTrackIndex: media.audioTracks[0].index,
      audioStreamIndex: media.audioTracks[0].audioStreamIndex,
      selectedAudioCodec: media.audioTracks[0].codec,
      requestedFileName: 'e2e_tamil_output',
      outputDirectory: currentDir,
      format: AudioFormat.mp3,
      mode: ConversionMode.reEncode,
      preset: ConversionPreset.balanced,
      bitrateKbps: 192,
      sampleRateHz: 44100,
      channelMode: ChannelMode.keepOriginal, // Automatic clean stereo downmix for MP3
    );

    // Step 3: Convert English track to M4A stereo
    final englishM4aJob = ConversionJob(
      id: 'e2e_eng_m4a_${DateTime.now().millisecondsSinceEpoch}',
      sourcePath: mkvPath,
      sourceFileName: 'test_multitrack_e2e.mkv',
      sourceSizeBytes: File(mkvPath).lengthSync(),
      sourceDurationMs: media.duration.inMilliseconds,
      selectedAudioTrackIndex: media.audioTracks[1].index,
      audioStreamIndex: media.audioTracks[1].audioStreamIndex,
      selectedAudioCodec: media.audioTracks[1].codec,
      requestedFileName: 'e2e_english_output',
      outputDirectory: currentDir,
      format: AudioFormat.aac,
      mode: ConversionMode.reEncode,
      preset: ConversionPreset.music,
      bitrateKbps: 256,
      sampleRateHz: 48000,
      channelMode: ChannelMode.stereo,
    );

    print('Enqueueing batch of multi-track jobs...');
    await queue.enqueueBatch([tamilMp3Job, englishM4aJob]);

    // Await execution of both jobs
    int waitLoops = 0;
    while (waitLoops < 60) {
      await Future.delayed(const Duration(milliseconds: 250));
      final j1 = queue.jobs.firstWhere((j) => j.id == tamilMp3Job.id);
      final j2 = queue.jobs.firstWhere((j) => j.id == englishM4aJob.id);
      if (j1.status.isFinished && j2.status.isFinished) {
        break;
      }
      waitLoops++;
    }

    final finished1 = queue.jobs.firstWhere((j) => j.id == tamilMp3Job.id);
    final finished2 = queue.jobs.firstWhere((j) => j.id == englishM4aJob.id);

    print('Tamil job status: ${finished1.status}, error: ${finished1.errorMessage}');
    print('English job status: ${finished2.status}, error: ${finished2.errorMessage}');

    expect(finished1.status, JobStatus.completed);
    expect(finished2.status, JobStatus.completed);
    expect(File(finished1.finalOutputPath).existsSync(), isTrue);
    expect(File(finished2.finalOutputPath).existsSync(), isTrue);

    // Step 4: Verify output 1 (Tamil MP3) with FFprobe
    final outProbe1 = await engine.inspectMedia(finished1.finalOutputPath);
    expect(outProbe1.primaryAudioTrack?.channels, 2); // Correct stereo downmix
    expect(outProbe1.primaryAudioTrack?.codec, 'mp3');

    // Step 5: Verify output 2 (English M4A) with FFprobe
    final outProbe2 = await engine.inspectMedia(finished2.finalOutputPath);
    expect(outProbe2.primaryAudioTrack?.channels, 2);
    expect(outProbe2.primaryAudioTrack?.codec, 'aac');

    // Cleanup
    if (File(mkvPath).existsSync()) File(mkvPath).deleteSync();
    if (File(finished1.finalOutputPath).existsSync()) File(finished1.finalOutputPath).deleteSync();
    if (File(finished2.finalOutputPath).existsSync()) File(finished2.finalOutputPath).deleteSync();
  });
}
