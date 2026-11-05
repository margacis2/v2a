import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2a/models/conversion_config.dart';
import 'package:v2a/services/conversion_engine.dart';
import 'package:v2a/services/output_manager.dart';

void main() {
  group('OutputManager Duplicate Protection Tests', () {
    late Directory tempDir;
    late OutputManager outputManager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('v2a_test_');
      outputManager = OutputManager();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Resolves unique filename when no file exists', () async {
      final name = await outputManager.resolveUniqueFileName(
        directoryPath: tempDir.path,
        baseName: 'Podcast_Episode_1',
        extension: 'mp3',
      );
      expect(name, equals('Podcast_Episode_1.mp3'));
    });

    test('Generates collision-free names (Never Overwrite Guarantee)', () async {
      // Create first file
      final file1 = File('${tempDir.path}/Podcast.mp3');
      await file1.writeAsString('audio 1');

      // Attempting to resolve same name
      final name2 = await outputManager.resolveUniqueFileName(
        directoryPath: tempDir.path,
        baseName: 'Podcast',
        extension: 'mp3',
      );
      expect(name2, equals('Podcast (1).mp3'));

      // Create file 2
      final file2 = File('${tempDir.path}/$name2');
      await file2.writeAsString('audio 2');

      // Attempting to resolve again
      final name3 = await outputManager.resolveUniqueFileName(
        directoryPath: tempDir.path,
        baseName: 'Podcast',
        extension: 'mp3',
      );
      expect(name3, equals('Podcast (2).mp3'));

      // Verify original file remained completely unchanged
      expect(await file1.readAsString(), equals('audio 1'));
    });

    test('Atomic temp file creation produces unique hidden file', () async {
      final tempFile = await outputManager.createTemporaryProcessingFile(
        directoryPath: tempDir.path,
        extension: 'm4a',
      );

      expect(tempFile.path.contains('.v2a_tmp_'), isTrue);
      expect(tempFile.path.endsWith('.m4a'), isTrue);
    });
  });

  group('ConversionEngine Stream-Copy Compatibility Matrix', () {
    final engine = ConversionEngine();

    test('AAC stream copy compatibility', () {
      expect(engine.isStreamCopyCompatible('aac', AudioFormat.aac), isTrue);
      expect(engine.isStreamCopyCompatible('mp3', AudioFormat.aac), isFalse);
    });

    test('MP3 stream copy compatibility', () {
      expect(engine.isStreamCopyCompatible('mp3', AudioFormat.mp3), isTrue);
      expect(engine.isStreamCopyCompatible('aac', AudioFormat.mp3), isFalse);
    });

    test('Opus stream copy compatibility', () {
      expect(engine.isStreamCopyCompatible('opus', AudioFormat.opus), isTrue);
      expect(engine.isStreamCopyCompatible('opus', AudioFormat.ogg), isTrue);
    });

    test('FLAC stream copy compatibility', () {
      expect(engine.isStreamCopyCompatible('flac', AudioFormat.flac), isTrue);
    });

    test('PCM WAV stream copy compatibility', () {
      expect(engine.isStreamCopyCompatible('pcm_s16le', AudioFormat.wav), isTrue);
      expect(engine.isStreamCopyCompatible('pcm_f32le', AudioFormat.wav), isTrue);
      expect(engine.isStreamCopyCompatible('aac', AudioFormat.wav), isFalse);
    });
  });
}

