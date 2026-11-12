import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/media_file.dart';
import 'desktop_media_engine.dart';

class MediaMetadataService {
  static final MediaMetadataService _instance = MediaMetadataService._internal();
  factory MediaMetadataService() => _instance;
  MediaMetadataService._internal();

  /// Inspects a video or audio file and extracts complete metadata without decoding the file
  Future<MediaFile> analyzeMediaFile(String filePath) async {
    // On Desktop platforms, delegate to native Process-based DesktopMediaEngine
    if (!Platform.isAndroid && !Platform.isIOS) {
      return DesktopMediaEngine().inspectMedia(filePath);
    }
    final file = File(filePath);
    if (!await file.exists()) {
      return MediaFile(
        path: filePath,
        fileName: p.basename(filePath),
        sizeBytes: 0,
        duration: Duration.zero,
        extension: p.extension(filePath),
        isCorrupted: true,
        validationError: 'File does not exist or access was revoked',
      );
    }

    final int sizeBytes = await file.length();
    final String fileName = p.basename(filePath);
    final String extension = p.extension(filePath).toLowerCase();

    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final mediaInfo = session.getMediaInformation();

      if (mediaInfo == null) {
        return MediaFile(
          path: filePath,
          fileName: fileName,
          sizeBytes: sizeBytes,
          duration: Duration.zero,
          extension: extension,
          isCorrupted: true,
          validationError: 'Unsupported or corrupted container format',
        );
      }

      // Extract duration
      Duration duration = Duration.zero;
      final durationStr = mediaInfo.getDuration();
      if (durationStr != null && durationStr.isNotEmpty) {
        final secDouble = double.tryParse(durationStr);
        if (secDouble != null && secDouble > 0) {
          duration = Duration(milliseconds: (secDouble * 1000).round());
        }
      }

      // Parse streams
      final streams = mediaInfo.getStreams();
      int? videoWidth;
      int? videoHeight;
      String? videoCodec;
      final audioTracks = <AudioTrackInfo>[];

      for (final s in streams) {
        final type = s.getType()?.toLowerCase();
        if (type == 'video' && videoCodec == null) {
          videoCodec = s.getCodec();
          videoWidth = s.getWidth()?.toInt();
          videoHeight = s.getHeight()?.toInt();
        } else if (type == 'audio') {
          final tags = s.getAllProperties()?['tags'] as Map<dynamic, dynamic>? ?? {};
          final language = tags['language']?.toString();
          final title = tags['title']?.toString();

          int channels = 2;
          final chProp = s.getAllProperties()?['channels'];
          if (chProp is num) {
            channels = chProp.toInt();
          } else if (chProp is String) {
            channels = int.tryParse(chProp) ?? 2;
          }

          int sampleRate = 44100;
          final srProp = s.getAllProperties()?['sample_rate'];
          if (srProp is num) {
            sampleRate = srProp.toInt();
          } else if (srProp is String) {
            sampleRate = int.tryParse(srProp) ?? 44100;
          }

          int bitrateKbps = 0;
          final brProp = s.getAllProperties()?['bit_rate'];
          if (brProp is num) {
            bitrateKbps = (brProp / 1000).round();
          } else if (brProp is String) {
            final br = int.tryParse(brProp);
            if (br != null) bitrateKbps = (br / 1000).round();
          }

          audioTracks.add(AudioTrackInfo(
            index: s.getIndex()?.toInt() ?? audioTracks.length,
            codec: s.getCodec() ?? 'unknown',
            language: language,
            title: title,
            channels: channels,
            sampleRate: sampleRate,
            bitrateKbps: bitrateKbps,
            isDefault: audioTracks.isEmpty,
          ));
        }
      }

      String? validationError;
      if (audioTracks.isEmpty) {
        validationError = 'This video does not contain any audio tracks';
      }

      // Generate thumbnail in background cache
      String? thumbnailPath;
      if (videoCodec != null) {
        thumbnailPath = await _generateThumbnail(filePath);
      }

      return MediaFile(
        path: filePath,
        fileName: fileName,
        sizeBytes: sizeBytes,
        duration: duration,
        extension: extension,
        videoWidth: videoWidth,
        videoHeight: videoHeight,
        videoCodec: videoCodec,
        audioTracks: audioTracks,
        thumbnailPath: thumbnailPath,
        isCorrupted: false,
        validationError: validationError,
      );
    } catch (e) {
      return MediaFile(
        path: filePath,
        fileName: fileName,
        sizeBytes: sizeBytes,
        duration: Duration.zero,
        extension: extension,
        isCorrupted: true,
        validationError: 'Failed to inspect media file: $e',
      );
    }
  }

  /// Generates a fast single-frame thumbnail without full decode
  Future<String?> _generateThumbnail(String videoPath) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final thumbDir = Directory(p.join(cacheDir.path, 'v2a_thumbnails'));
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }

      final fileName = '${p.basenameWithoutExtension(videoPath)}_${videoPath.hashCode.abs()}.jpg';
      final thumbFile = File(p.join(thumbDir.path, fileName));
      if (await thumbFile.exists()) {
        return thumbFile.path;
      }

      // Fast seek to 1 second (or 0s) and take 1 frame
      final cmd = '-y -ss 00:00:01 -i "$videoPath" -vframes 1 -q:v 3 -vf "scale=480:-1" "${thumbFile.path}"';
      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();

      if (returnCode?.isValueSuccess() == true && await thumbFile.exists()) {
        return thumbFile.path;
      }

      // Fallback to position 0
      final fallbackCmd = '-y -ss 00:00:00 -i "$videoPath" -vframes 1 -q:v 3 -vf "scale=480:-1" "${thumbFile.path}"';
      await FFmpegKit.execute(fallbackCmd);
      if (await thumbFile.exists()) {
        return thumbFile.path;
      }
    } catch (_) {}
    return null;
  }
}

