import 'package:flutter_test/flutter_test.dart';
import 'package:v2a/models/conversion_config.dart';
import 'package:v2a/models/conversion_job.dart';
import 'package:v2a/services/conversion_engine.dart';

ConversionJob createTestJob({
  required String id,
  required AudioFormat format,
  required ConversionMode mode,
  ConversionPreset preset = ConversionPreset.bestQuality,
  String selectedAudioCodec = '',
  int bitrateKbps = 192,
  int sampleRateHz = 44100,
  ChannelMode channelMode = ChannelMode.stereo,
  int trimStartMs = 0,
  int trimEndMs = 0,
  double volumeGainDb = 0.0,
  bool normalizeLoudness = false,
}) {
  return ConversionJob(
    id: id,
    sourcePath: '/path/to/test_video.mp4',
    sourceFileName: 'test_video.mp4',
    sourceSizeBytes: 50 * 1024 * 1024,
    sourceDurationMs: 120000,
    requestedFileName: 'output_audio',
    outputDirectory: '/output',
    format: format,
    mode: mode,
    preset: preset,
    selectedAudioCodec: selectedAudioCodec,
    bitrateKbps: bitrateKbps,
    sampleRateHz: sampleRateHz,
    channelMode: channelMode,
    trimStartMs: trimStartMs,
    trimEndMs: trimEndMs,
    volumeGainDb: volumeGainDb,
    normalizeLoudness: normalizeLoudness,
  );
}

void main() {
  group('FFmpeg Preset and Argument Verification Tests', () {
    final engine = ConversionEngine();

    test('Fastest Compatibility Preset - Stream Copy when source matches target format', () {
      final job = createTestJob(
        id: 'job_fast_copy',
        format: AudioFormat.aac,
        mode: ConversionMode.fastestCompatible,
        preset: ConversionPreset.fastestCompatible,
        selectedAudioCodec: 'aac',
        bitrateKbps: 0,
        sampleRateHz: 0,
        channelMode: ChannelMode.keepOriginal,
      );

      final args = engine.buildCommandArgumentsForTesting(
        job: job,
        tempOutputPath: '/output/temp.m4a',
      );

      expect(args.contains('-c:a'), isTrue);
      final cIdx = args.indexOf('-c:a');
      expect(args[cIdx + 1], 'copy');
      expect(args.contains('-vn'), isTrue);
      expect(args.last, '/output/temp.m4a');
    });

    test('Fastest Compatibility Preset - Safe Transcoding Fallback when source is incompatible', () {
      final job = createTestJob(
        id: 'job_fast_fallback',
        format: AudioFormat.aac,
        mode: ConversionMode.fastestCompatible,
        preset: ConversionPreset.fastestCompatible,
        selectedAudioCodec: 'vorbis', // incompatible with AAC container stream copy!
        bitrateKbps: 192,
        sampleRateHz: 44100,
        channelMode: ChannelMode.keepOriginal,
      );

      final args = engine.buildCommandArgumentsForTesting(
        job: job,
        tempOutputPath: '/output/temp.m4a',
      );

      expect(args.contains('-c:a'), isTrue);
      final cIdx = args.indexOf('-c:a');
      expect(args[cIdx + 1], 'aac'); // Safely fell back to re-encoding!
      expect(args.contains('copy'), isFalse);
    });

    test('Balanced Preset generates MP3, 192k, 44100Hz stereo', () {
      final job = createTestJob(
        id: 'job_balanced',
        format: ConversionPreset.balanced.format,
        mode: ConversionPreset.balanced.mode,
        preset: ConversionPreset.balanced,
        bitrateKbps: ConversionPreset.balanced.bitrate,
        sampleRateHz: ConversionPreset.balanced.sampleRate,
        channelMode: ConversionPreset.balanced.channelMode,
      );

      final args = engine.buildCommandArgumentsForTesting(
        job: job,
        tempOutputPath: '/output/temp.mp3',
      );

      final cIdx = args.indexOf('-c:a');
      expect(args[cIdx + 1], 'libmp3lame');
      final bIdx = args.indexOf('-b:a');
      expect(args[bIdx + 1], '192k');
      final arIdx = args.indexOf('-ar');
      expect(args[arIdx + 1], '44100');
      final acIdx = args.indexOf('-ac');
      expect(args[acIdx + 1], '2');
    });

    test('Best Quality Preset generates MP3, 320k, 48000Hz stereo', () {
      final job = createTestJob(
        id: 'job_best_quality',
        format: ConversionPreset.bestQuality.format,
        mode: ConversionPreset.bestQuality.mode,
        preset: ConversionPreset.bestQuality,
        bitrateKbps: ConversionPreset.bestQuality.bitrate,
        sampleRateHz: ConversionPreset.bestQuality.sampleRate,
        channelMode: ConversionPreset.bestQuality.channelMode,
      );

      final args = engine.buildCommandArgumentsForTesting(
        job: job,
        tempOutputPath: '/output/temp.mp3',
      );

      final cIdx = args.indexOf('-c:a');
      expect(args[cIdx + 1], 'libmp3lame');
      final bIdx = args.indexOf('-b:a');
      expect(args[bIdx + 1], '320k');
      final arIdx = args.indexOf('-ar');
      expect(args[arIdx + 1], '48000');
      final acIdx = args.indexOf('-ac');
      expect(args[acIdx + 1], '2');
    });

    test('Smallest Practical File Preset generates Opus, 48k, 24000Hz mono', () {
      final job = createTestJob(
        id: 'job_smallest',
        format: ConversionPreset.smallestPractical.format,
        mode: ConversionPreset.smallestPractical.mode,
        preset: ConversionPreset.smallestPractical,
        bitrateKbps: ConversionPreset.smallestPractical.bitrate,
        sampleRateHz: ConversionPreset.smallestPractical.sampleRate,
        channelMode: ConversionPreset.smallestPractical.channelMode,
      );

      final args = engine.buildCommandArgumentsForTesting(
        job: job,
        tempOutputPath: '/output/temp.opus',
      );

      final cIdx = args.indexOf('-c:a');
      expect(args[cIdx + 1], 'libopus');
      final bIdx = args.indexOf('-b:a');
      expect(args[bIdx + 1], '48k');
      final arIdx = args.indexOf('-ar');
      expect(args[arIdx + 1], '24000');
      final acIdx = args.indexOf('-ac');
      expect(args[acIdx + 1], '1');
    });

    test('Voice / Speech Preset generates Opus, 64k, 24000Hz mono', () {
      final job = createTestJob(
        id: 'job_voice',
        format: ConversionPreset.voiceSpeech.format,
        mode: ConversionPreset.voiceSpeech.mode,
        preset: ConversionPreset.voiceSpeech,
        bitrateKbps: ConversionPreset.voiceSpeech.bitrate,
        sampleRateHz: ConversionPreset.voiceSpeech.sampleRate,
        channelMode: ConversionPreset.voiceSpeech.channelMode,
      );

      final args = engine.buildCommandArgumentsForTesting(
        job: job,
        tempOutputPath: '/output/temp.opus',
      );

      final cIdx = args.indexOf('-c:a');
      expect(args[cIdx + 1], 'libopus');
      final bIdx = args.indexOf('-b:a');
      expect(args[bIdx + 1], '64k');
      final arIdx = args.indexOf('-ar');
      expect(args[arIdx + 1], '24000');
      final acIdx = args.indexOf('-ac');
      expect(args[acIdx + 1], '1');
    });

    test('Music Preset generates AAC, 256k, 48000Hz stereo', () {
      final job = createTestJob(
        id: 'job_music',
        format: ConversionPreset.music.format,
        mode: ConversionPreset.music.mode,
        preset: ConversionPreset.music,
        bitrateKbps: ConversionPreset.music.bitrate,
        sampleRateHz: ConversionPreset.music.sampleRate,
        channelMode: ConversionPreset.music.channelMode,
      );

      final args = engine.buildCommandArgumentsForTesting(
        job: job,
        tempOutputPath: '/output/temp.m4a',
      );

      final cIdx = args.indexOf('-c:a');
      expect(args[cIdx + 1], 'aac');
      final bIdx = args.indexOf('-b:a');
      expect(args[bIdx + 1], '256k');
      final arIdx = args.indexOf('-ar');
      expect(args[arIdx + 1], '48000');
      final acIdx = args.indexOf('-ac');
      expect(args[acIdx + 1], '2');
    });

    test('Lossless Master Preset generates FLAC with compression level 5', () {
      final job = createTestJob(
        id: 'job_lossless',
        format: ConversionPreset.losslessMaster.format,
        mode: ConversionPreset.losslessMaster.mode,
        preset: ConversionPreset.losslessMaster,
        bitrateKbps: ConversionPreset.losslessMaster.bitrate,
        sampleRateHz: ConversionPreset.losslessMaster.sampleRate,
        channelMode: ConversionPreset.losslessMaster.channelMode,
      );

      final args = engine.buildCommandArgumentsForTesting(
        job: job,
        tempOutputPath: '/output/temp.flac',
      );

      final cIdx = args.indexOf('-c:a');
      expect(args[cIdx + 1], 'flac');
      final compIdx = args.indexOf('-compression_level');
      expect(args[compIdx + 1], '5');
    });

    test('Maximum Compression Preset generates Opus, 32k, 16000Hz mono', () {
      final job = createTestJob(
        id: 'job_max_compression',
        format: ConversionPreset.maxCompression.format,
        mode: ConversionPreset.maxCompression.mode,
        preset: ConversionPreset.maxCompression,
        bitrateKbps: ConversionPreset.maxCompression.bitrate,
        sampleRateHz: ConversionPreset.maxCompression.sampleRate,
        channelMode: ConversionPreset.maxCompression.channelMode,
      );

      final args = engine.buildCommandArgumentsForTesting(
        job: job,
        tempOutputPath: '/output/temp.opus',
      );

      final cIdx = args.indexOf('-c:a');
      expect(args[cIdx + 1], 'libopus');
      final bIdx = args.indexOf('-b:a');
      expect(args[bIdx + 1], '32k');
      final arIdx = args.indexOf('-ar');
      expect(args[arIdx + 1], '16000');
      final acIdx = args.indexOf('-ac');
      expect(args[acIdx + 1], '1');
    });

    test('Full Format Matrix Verification - WAV (PCM 16-bit) and OGG (Vorbis)', () {
      final wavJob = createTestJob(
        id: 'job_wav',
        format: AudioFormat.wav,
        mode: ConversionMode.reEncode,
        bitrateKbps: 1411,
        sampleRateHz: 44100,
        channelMode: ChannelMode.stereo,
      );

      final wavArgs = engine.buildCommandArgumentsForTesting(
        job: wavJob,
        tempOutputPath: '/output/temp.wav',
      );
      final wavCIdx = wavArgs.indexOf('-c:a');
      expect(wavArgs[wavCIdx + 1], 'pcm_s16le');

      final oggJob = createTestJob(
        id: 'job_ogg',
        format: AudioFormat.ogg,
        mode: ConversionMode.reEncode,
        bitrateKbps: 160,
        sampleRateHz: 44100,
        channelMode: ChannelMode.stereo,
      );

      final oggArgs = engine.buildCommandArgumentsForTesting(
        job: oggJob,
        tempOutputPath: '/output/temp.ogg',
      );
      final oggCIdx = oggArgs.indexOf('-c:a');
      expect(oggArgs[oggCIdx + 1], 'libvorbis');
      final oggBIdx = oggArgs.indexOf('-b:a');
      expect(oggArgs[oggBIdx + 1], '160k');
    });

    test('Trimming and Audio Filters arguments', () {
      final trimmedJob = createTestJob(
        id: 'job_trimmed',
        format: AudioFormat.mp3,
        mode: ConversionMode.reEncode,
        bitrateKbps: 192,
        trimStartMs: 5000,
        trimEndMs: 15000,
        volumeGainDb: 3.5,
        normalizeLoudness: true,
      );

      final args = engine.buildCommandArgumentsForTesting(
        job: trimmedJob,
        tempOutputPath: '/output/temp.mp3',
      );

      expect(args.contains('-ss'), isTrue);
      final ssIdx = args.indexOf('-ss');
      expect(args[ssIdx + 1], '5.000');

      expect(args.contains('-t'), isTrue);
      final tIdx = args.indexOf('-t');
      expect(args[tIdx + 1], '10.000');

      expect(args.contains('-af'), isTrue);
      final afIdx = args.indexOf('-af');
      expect(args[afIdx + 1], contains('volume=3.5dB'));
      expect(args[afIdx + 1], contains('loudnorm=I=-16:TP=-1.5:LRA=11'));
    });
  });
}
