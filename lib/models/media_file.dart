class AudioTrackInfo {
  final int index;
  final String codec;
  final String? language;
  final String? title;
  final int channels;
  final int sampleRate;
  final int bitrateKbps;
  final bool isDefault;

  AudioTrackInfo({
    required this.index,
    required this.codec,
    this.language,
    this.title,
    this.channels = 2,
    this.sampleRate = 44100,
    this.bitrateKbps = 0,
    this.isDefault = false,
  });

  String get displayName {
    final parts = <String>[];
    if (title != null && title!.isNotEmpty) {
      parts.add(title!);
    } else {
      parts.add('Track #$index');
    }
    if (language != null && language!.isNotEmpty && language != 'und') {
      parts.add('(${language!.toUpperCase()})');
    }
    parts.add('• ${codec.toUpperCase()}');
    if (channels > 0) {
      parts.add(channels == 1 ? 'Mono' : channels == 2 ? 'Stereo' : '${channels}ch');
    }
    if (sampleRate > 0) {
      parts.add('${(sampleRate / 1000).toStringAsFixed(1)}kHz');
    }
    if (bitrateKbps > 0) {
      parts.add('${bitrateKbps}kbps');
    }
    return parts.join(' ');
  }

  bool get isLossless {
    final c = codec.toLowerCase();
    return c.contains('flac') || c.contains('pcm') || c.contains('wav') || c.contains('alac');
  }

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'codec': codec,
      'language': language,
      'title': title,
      'channels': channels,
      'sampleRate': sampleRate,
      'bitrateKbps': bitrateKbps,
      'isDefault': isDefault ? 1 : 0,
    };
  }

  factory AudioTrackInfo.fromMap(Map<String, dynamic> map) {
    return AudioTrackInfo(
      index: map['index'] as int? ?? 0,
      codec: map['codec'] as String? ?? 'unknown',
      language: map['language'] as String?,
      title: map['title'] as String?,
      channels: map['channels'] as int? ?? 2,
      sampleRate: map['sampleRate'] as int? ?? 44100,
      bitrateKbps: map['bitrateKbps'] as int? ?? 0,
      isDefault: (map['isDefault'] as int? ?? 0) == 1,
    );
  }
}

class MediaFile {
  final String path;
  final String fileName;
  final int sizeBytes;
  final Duration duration;
  final String extension;
  final int? videoWidth;
  final int? videoHeight;
  final String? videoCodec;
  final List<AudioTrackInfo> audioTracks;
  final String? thumbnailPath;
  final bool isCorrupted;
  final String? validationError;

  MediaFile({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.duration,
    required this.extension,
    this.videoWidth,
    this.videoHeight,
    this.videoCodec,
    this.audioTracks = const [],
    this.thumbnailPath,
    this.isCorrupted = false,
    this.validationError,
  });

  bool get hasAudio => audioTracks.isNotEmpty;
  bool get hasMultipleAudioTracks => audioTracks.length > 1;

  AudioTrackInfo? get primaryAudioTrack =>
      audioTracks.isNotEmpty ? audioTracks.first : null;

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  String get resolutionString {
    if (videoWidth != null && videoHeight != null) {
      return '${videoWidth}x$videoHeight';
    }
    return '';
  }

  MediaFile copyWith({
    String? thumbnailPath,
    List<AudioTrackInfo>? audioTracks,
    bool? isCorrupted,
    String? validationError,
  }) {
    return MediaFile(
      path: path,
      fileName: fileName,
      sizeBytes: sizeBytes,
      duration: duration,
      extension: extension,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      videoCodec: videoCodec,
      audioTracks: audioTracks ?? this.audioTracks,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isCorrupted: isCorrupted ?? this.isCorrupted,
      validationError: validationError ?? this.validationError,
    );
  }
}

