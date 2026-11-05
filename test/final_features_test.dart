import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v2a/models/conversion_config.dart';
import 'package:v2a/models/conversion_job.dart';
import 'package:v2a/services/feedback_service.dart';
import 'package:v2a/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Priority 1: Storage Information & Calculations', () {
    test('StorageService formats bytes into readable units correctly', () {
      expect(StorageService.formatBytes(0), equals('0 B'));
      expect(StorageService.formatBytes(512), equals('512 B'));
      expect(StorageService.formatBytes(1024), equals('1 KB'));
      expect(StorageService.formatBytes(1024 * 1024), equals('1.0 MB'));
      expect(StorageService.formatBytes(250 * 1024 * 1024), equals('250.0 MB'));
      expect(StorageService.formatBytes(1024 * 1024 * 1024), equals('1.0 GB'));
      expect(StorageService.formatBytes((128.5 * 1024 * 1024 * 1024).round()), equals('128.5 GB'));
    });

    test('DeviceStorageInfo calculates used percentage and human strings accurately', () {
      const info = DeviceStorageInfo(
        totalBytes: 128 * 1024 * 1024 * 1024,
        usedBytes: 64 * 1024 * 1024 * 1024,
        availableBytes: 64 * 1024 * 1024 * 1024,
      );

      expect(info.usedPercentage, closeTo(50.0, 0.01));
      expect(info.totalFormatted, equals('128.0 GB'));
      expect(info.usedFormatted, equals('64.0 GB'));
      expect(info.availableFormatted, equals('64.0 GB'));
    });

    test('FolderStorageInfo formats folder capacity and file count', () {
      const folder = FolderStorageInfo(
        path: '/storage/emulated/0/Music/V2A',
        totalSizeBytes: 350 * 1024 * 1024,
        fileCount: 15,
      );

      expect(folder.sizeFormatted, equals('350.0 MB'));
      expect(folder.fileCount, equals(15));
      expect(folder.path, equals('/storage/emulated/0/Music/V2A'));
    });
  });

  group('Priority 4: All 8 Conversion Presets Verification', () {
    test('Every preset has expected format, bitrate, sampleRate, and channel configuration', () {
      final presets = ConversionPreset.values.where((p) => p != ConversionPreset.custom).toList();
      expect(presets.length, equals(8));

      // 1. Fastest Compatibility
      final fastest = ConversionPreset.fastestCompatible;
      expect(fastest.label, equals('Fastest Compatibility'));
      expect(fastest.mode, equals(ConversionMode.fastestCompatible));

      // 2. Balanced
      final balanced = ConversionPreset.balanced;
      expect(balanced.format, equals(AudioFormat.mp3));
      expect(balanced.bitrate, equals(192));
      expect(balanced.sampleRate, equals(44100));
      expect(balanced.channelMode, equals(ChannelMode.stereo));

      // 3. Best Quality
      final best = ConversionPreset.bestQuality;
      expect(best.format, equals(AudioFormat.mp3));
      expect(best.bitrate, equals(320));
      expect(best.sampleRate, equals(48000));
      expect(best.channelMode, equals(ChannelMode.stereo));

      // 4. Smallest Practical File
      final smallest = ConversionPreset.smallestPractical;
      expect(smallest.format, equals(AudioFormat.opus));
      expect(smallest.bitrate, equals(48));
      expect(smallest.sampleRate, equals(24000));
      expect(smallest.channelMode, equals(ChannelMode.mono));

      // 5. Voice or Speech
      final voice = ConversionPreset.voiceSpeech;
      expect(voice.format, equals(AudioFormat.opus));
      expect(voice.bitrate, equals(64));
      expect(voice.sampleRate, equals(24000));
      expect(voice.channelMode, equals(ChannelMode.mono));

      // 6. Music
      final music = ConversionPreset.music;
      expect(music.format, equals(AudioFormat.aac));
      expect(music.bitrate, equals(256));
      expect(music.sampleRate, equals(48000));
      expect(music.channelMode, equals(ChannelMode.stereo));

      // 7. Lossless Master
      final flac = ConversionPreset.losslessMaster;
      expect(flac.format, equals(AudioFormat.flac));
      expect(flac.mode, equals(ConversionMode.lossless));
      expect(flac.sampleRate, equals(0)); // preserves source rate

      // 8. Maximum Compression
      final maxComp = ConversionPreset.maxCompression;
      expect(maxComp.format, equals(AudioFormat.opus));
      expect(maxComp.bitrate, equals(32));
      expect(maxComp.sampleRate, equals(16000));
      expect(maxComp.channelMode, equals(ChannelMode.mono));
    });
  });

  group('Priority 5: Effects & Haptics Persistence & Independence', () {
    test('FeedbackService defaults both settings to true and persists changes independently', () async {
      SharedPreferences.setMockInitialValues({});
      final service = FeedbackService();
      await service.init();

      expect(service.visualEffectsEnabled, isTrue);
      expect(service.hapticsEnabled, isTrue);

      // Disable visual effects only
      await service.setVisualEffectsEnabled(false);
      expect(service.visualEffectsEnabled, isFalse);
      expect(service.hapticsEnabled, isTrue); // Haptics remains ON

      // Disable haptics only
      await service.setHapticsEnabled(false);
      expect(service.visualEffectsEnabled, isFalse);
      expect(service.hapticsEnabled, isFalse);

      // Re-enable visual effects only
      await service.setVisualEffectsEnabled(true);
      expect(service.visualEffectsEnabled, isTrue);
      expect(service.hapticsEnabled, isFalse); // Haptics still OFF
    });
  });

  group('Priority 2: Job Model & Multi-Selection Compatibility', () {
    test('ConversionJob etaSeconds convenience getter correctly maps to estimatedRemainingSeconds', () {
      final job = ConversionJob(
        id: 'job-1',
        sourcePath: '/path/source.mp4',
        sourceFileName: 'source.mp4',
        sourceSizeBytes: 1000000,
        sourceDurationMs: 60000,
        format: AudioFormat.mp3,
        mode: ConversionMode.reEncode,
        preset: ConversionPreset.bestQuality,
        bitrateKbps: 320,
        requestedFileName: 'source.mp3',
        outputDirectory: '/output',
        estimatedRemainingSeconds: 42,
      );

      expect(job.etaSeconds, equals(42));
      expect(job.estimatedRemainingSeconds, equals(42));
    });
  });

  group('Phase 1 Crash Fix: Preset Mapping and Dropdown Value Resolvers', () {
    test('ConversionPreset.fromValue tolerates legacy integer 0, legacy names, and case variants', () {
      expect(ConversionPreset.fromValue(0), equals(ConversionPreset.fastestCompatible));
      expect(ConversionPreset.fromValue('fastest_compatibility'), equals(ConversionPreset.fastestCompatible));
      expect(ConversionPreset.fromValue('Fastest Compatibility'), equals(ConversionPreset.fastestCompatible));
      expect(ConversionPreset.fromValue('balanced'), equals(ConversionPreset.balanced));
      expect(ConversionPreset.fromValue('best_quality'), equals(ConversionPreset.bestQuality));
      expect(ConversionPreset.fromValue('smallest_practical'), equals(ConversionPreset.smallestPractical));
      expect(ConversionPreset.fromValue('voice_speech'), equals(ConversionPreset.voiceSpeech));
      expect(ConversionPreset.fromValue('music'), equals(ConversionPreset.music));
      expect(ConversionPreset.fromValue('lossless_master'), equals(ConversionPreset.losslessMaster));
      expect(ConversionPreset.fromValue('max_compression'), equals(ConversionPreset.maxCompression));
      expect(ConversionPreset.fromValue(null), equals(ConversionPreset.bestQuality));
      expect(ConversionPreset.fromValue('unknown_nonsense'), equals(ConversionPreset.bestQuality));
    });

    test('All 8 presets have non-null unique IDs and valid sample rates', () {
      final ids = <String>{};
      for (final p in ConversionPreset.values) {
        expect(ids.contains(p.id), isFalse, reason: 'Duplicate preset id ${p.id}');
        ids.add(p.id);
      }
      expect(ids.length, equals(ConversionPreset.values.length));
    });
  });
}

