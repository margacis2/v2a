import 'conversion_config.dart';

enum JobStatus {
  queued('Queued'),
  preparing('Preparing'),
  running('Running'),
  finalizing('Finalizing'),
  completed('Completed'),
  paused('Paused'),
  cancelling('Cancelling'),
  cancelled('Cancelled'),
  failed('Failed'),
  interrupted('Interrupted'),
  waitingForStorage('Waiting for Storage');

  final String label;
  const JobStatus(this.label);

  bool get isActive => this == JobStatus.queued || this == JobStatus.preparing || this == JobStatus.running || this == JobStatus.finalizing;
  bool get isFinished => this == JobStatus.completed || this == JobStatus.failed || this == JobStatus.cancelled || this == JobStatus.interrupted;
}

enum DestinationMode {
  configuredDirectory,
  besideOriginalFile,
  customFolder,
}

enum SilenceTrimMode {
  none,
  leadingOnly,
  trailingOnly,
  leadingAndTrailing,
}

class AudioMetadataTags {
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? year;
  final String? genre;
  final String? trackNumber;
  final String? discNumber;
  final String? composer;
  final String? copyright;
  final String? comment;
  final String? lyrics;
  final String? language;
  final String? artworkPath;
  final bool stripMetadata;
  final bool preserveMetadata;
  final Map<String, String> customTags;

  const AudioMetadataTags({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.year,
    this.genre,
    this.trackNumber,
    this.discNumber,
    this.composer,
    this.copyright,
    this.comment,
    this.lyrics,
    this.language,
    this.artworkPath,
    this.stripMetadata = false,
    this.preserveMetadata = true,
    this.customTags = const {},
  });

  AudioMetadataTags copyWith({
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? year,
    String? genre,
    String? trackNumber,
    String? discNumber,
    String? composer,
    String? copyright,
    String? comment,
    String? lyrics,
    String? language,
    String? artworkPath,
    bool? stripMetadata,
    bool? preserveMetadata,
    Map<String, String>? customTags,
  }) {
    return AudioMetadataTags(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      composer: composer ?? this.composer,
      copyright: copyright ?? this.copyright,
      comment: comment ?? this.comment,
      lyrics: lyrics ?? this.lyrics,
      language: language ?? this.language,
      artworkPath: artworkPath ?? this.artworkPath,
      stripMetadata: stripMetadata ?? this.stripMetadata,
      preserveMetadata: preserveMetadata ?? this.preserveMetadata,
      customTags: customTags ?? this.customTags,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtist': albumArtist,
      'year': year,
      'genre': genre,
      'trackNumber': trackNumber,
      'discNumber': discNumber,
      'composer': composer,
      'copyright': copyright,
      'comment': comment,
      'lyrics': lyrics,
      'language': language,
      'artworkPath': artworkPath,
      'stripMetadata': stripMetadata ? 1 : 0,
      'preserveMetadata': preserveMetadata ? 1 : 0,
      'customTags': customTags,
    };
  }

  factory AudioMetadataTags.fromMap(Map<String, dynamic> map) {
    Map<String, String> parsedCustomTags = {};
    if (map['customTags'] is Map) {
      (map['customTags'] as Map).forEach((k, v) {
        parsedCustomTags[k.toString()] = v.toString();
      });
    }

    return AudioMetadataTags(
      title: map['title'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      albumArtist: map['albumArtist'] as String?,
      year: map['year'] as String?,
      genre: map['genre'] as String?,
      trackNumber: map['trackNumber'] as String?,
      discNumber: map['discNumber'] as String?,
      composer: map['composer'] as String?,
      copyright: map['copyright'] as String?,
      comment: map['comment'] as String?,
      lyrics: map['lyrics'] as String?,
      language: map['language'] as String?,
      artworkPath: map['artworkPath'] as String?,
      stripMetadata: (map['stripMetadata'] as int? ?? 0) == 1,
      preserveMetadata: (map['preserveMetadata'] as int? ?? 1) == 1,
      customTags: parsedCustomTags,
    );
  }
}

class ConversionJob {
  final String id;
  final String sourcePath;
  final String sourceFileName;
  final int sourceSizeBytes;
  final int sourceDurationMs;
  final int selectedAudioTrackIndex; // Container stream index
  final int audioStreamIndex; // Relative audio stream index (0:a:N)
  final List<int> selectedAudioTrackIndexes; // Multiple tracks if requested
  final String selectedAudioCodec;

  // Settings
  final AudioFormat format;
  final ConversionMode mode;
  final ConversionPreset preset;
  final int bitrateKbps;
  final int sampleRateHz;
  final ChannelMode channelMode;
  final bool vbrEnabled;
  final int vbrQuality; // 0 (best) to 9 for MP3/Vorbis
  final double volumeGainDb; // -24 to +24 dB
  final bool normalizeLoudness;
  final int trimStartMs;
  final int trimEndMs; // 0 means end of source
  final double fadeInSec;
  final double fadeOutSec;
  final bool trimSilence;
  final double silenceThresholdDb;
  final double silenceMinDurationSec;
  final SilenceTrimMode silenceTrimMode;
  final AudioMetadataTags metadata;

  // Output details
  final String requestedFileName;
  final String outputDirectory;
  final DestinationMode destinationMode;
  final String finalOutputPath;

  // Runtime State
  final JobStatus status;
  final double progress; // 0.0 to 1.0
  final double speedRatio; // e.g. 15.2x
  final int currentTimeMs;
  final int elapsedSeconds;
  final int estimatedRemainingSeconds;
  int get etaSeconds => estimatedRemainingSeconds;
  final int outputSizeBytes;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  ConversionJob({
    required this.id,
    required this.sourcePath,
    required this.sourceFileName,
    required this.sourceSizeBytes,
    required this.sourceDurationMs,
    this.selectedAudioTrackIndex = 0,
    this.audioStreamIndex = 0,
    this.selectedAudioTrackIndexes = const [],
    this.selectedAudioCodec = '',
    required this.format,
    required this.mode,
    this.preset = ConversionPreset.bestQuality,
    this.bitrateKbps = 192,
    this.sampleRateHz = 44100,
    this.channelMode = ChannelMode.keepOriginal,
    this.vbrEnabled = false,
    this.vbrQuality = 2,
    this.volumeGainDb = 0.0,
    this.normalizeLoudness = false,
    this.trimStartMs = 0,
    this.trimEndMs = 0,
    this.fadeInSec = 0.0,
    this.fadeOutSec = 0.0,
    this.trimSilence = false,
    this.silenceThresholdDb = -50.0,
    this.silenceMinDurationSec = 0.5,
    this.silenceTrimMode = SilenceTrimMode.leadingAndTrailing,
    this.metadata = const AudioMetadataTags(),
    required this.requestedFileName,
    required this.outputDirectory,
    this.destinationMode = DestinationMode.configuredDirectory,
    this.finalOutputPath = '',
    this.status = JobStatus.queued,
    this.progress = 0.0,
    this.speedRatio = 0.0,
    this.currentTimeMs = 0,
    this.elapsedSeconds = 0,
    this.estimatedRemainingSeconds = 0,
    this.outputSizeBytes = 0,
    this.errorMessage,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  ConversionJob copyWith({
    JobStatus? status,
    double? progress,
    double? speedRatio,
    int? currentTimeMs,
    int? elapsedSeconds,
    int? estimatedRemainingSeconds,
    int? outputSizeBytes,
    String? finalOutputPath,
    String? errorMessage,
    DateTime? completedAt,
    int? selectedAudioTrackIndex,
    int? audioStreamIndex,
    List<int>? selectedAudioTrackIndexes,
    DestinationMode? destinationMode,
    String? outputDirectory,
    AudioMetadataTags? metadata,
  }) {
    return ConversionJob(
      id: id,
      sourcePath: sourcePath,
      sourceFileName: sourceFileName,
      sourceSizeBytes: sourceSizeBytes,
      sourceDurationMs: sourceDurationMs,
      selectedAudioTrackIndex: selectedAudioTrackIndex ?? this.selectedAudioTrackIndex,
      audioStreamIndex: audioStreamIndex ?? this.audioStreamIndex,
      selectedAudioTrackIndexes: selectedAudioTrackIndexes ?? this.selectedAudioTrackIndexes,
      selectedAudioCodec: selectedAudioCodec,
      format: format,
      mode: mode,
      preset: preset,
      bitrateKbps: bitrateKbps,
      sampleRateHz: sampleRateHz,
      channelMode: channelMode,
      vbrEnabled: vbrEnabled,
      vbrQuality: vbrQuality,
      volumeGainDb: volumeGainDb,
      normalizeLoudness: normalizeLoudness,
      trimStartMs: trimStartMs,
      trimEndMs: trimEndMs,
      fadeInSec: fadeInSec,
      fadeOutSec: fadeOutSec,
      trimSilence: trimSilence,
      silenceThresholdDb: silenceThresholdDb,
      silenceMinDurationSec: silenceMinDurationSec,
      silenceTrimMode: silenceTrimMode,
      metadata: metadata ?? this.metadata,
      requestedFileName: requestedFileName,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      destinationMode: destinationMode ?? this.destinationMode,
      finalOutputPath: finalOutputPath ?? this.finalOutputPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speedRatio: speedRatio ?? this.speedRatio,
      currentTimeMs: currentTimeMs ?? this.currentTimeMs,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      estimatedRemainingSeconds: estimatedRemainingSeconds ?? this.estimatedRemainingSeconds,
      outputSizeBytes: outputSizeBytes ?? this.outputSizeBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  String get formattedOutputSize {
    if (outputSizeBytes <= 0) return '0 B';
    final kb = outputSizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sourcePath': sourcePath,
      'sourceFileName': sourceFileName,
      'sourceSizeBytes': sourceSizeBytes,
      'sourceDurationMs': sourceDurationMs,
      'selectedAudioTrackIndex': selectedAudioTrackIndex,
      'audioStreamIndex': audioStreamIndex,
      'selectedAudioTrackIndexes': selectedAudioTrackIndexes.join(','),
      'selectedAudioCodec': selectedAudioCodec,
      'format': format.name,
      'mode': mode.name,
      'preset': preset.name,
      'bitrateKbps': bitrateKbps,
      'sampleRateHz': sampleRateHz,
      'channelMode': channelMode.name,
      'vbrEnabled': vbrEnabled ? 1 : 0,
      'vbrQuality': vbrQuality,
      'volumeGainDb': volumeGainDb,
      'normalizeLoudness': normalizeLoudness ? 1 : 0,
      'trimStartMs': trimStartMs,
      'trimEndMs': trimEndMs,
      'fadeInSec': fadeInSec,
      'fadeOutSec': fadeOutSec,
      'trimSilence': trimSilence ? 1 : 0,
      'silenceThresholdDb': silenceThresholdDb,
      'silenceMinDurationSec': silenceMinDurationSec,
      'silenceTrimMode': silenceTrimMode.name,
      'destinationMode': destinationMode.name,
      'metaTitle': metadata.title,
      'metaArtist': metadata.artist,
      'metaAlbum': metadata.album,
      'metaAlbumArtist': metadata.albumArtist,
      'metaYear': metadata.year,
      'metaGenre': metadata.genre,
      'metaTrackNumber': metadata.trackNumber,
      'metaDiscNumber': metadata.discNumber,
      'metaComposer': metadata.composer,
      'metaCopyright': metadata.copyright,
      'metaComment': metadata.comment,
      'metaLyrics': metadata.lyrics,
      'metaLanguage': metadata.language,
      'metaArtwork': metadata.artworkPath,
      'metaStrip': metadata.stripMetadata ? 1 : 0,
      'metaPreserve': metadata.preserveMetadata ? 1 : 0,
      'requestedFileName': requestedFileName,
      'outputDirectory': outputDirectory,
      'finalOutputPath': finalOutputPath,
      'status': status.name,
      'progress': progress,
      'speedRatio': speedRatio,
      'currentTimeMs': currentTimeMs,
      'elapsedSeconds': elapsedSeconds,
      'estimatedRemainingSeconds': estimatedRemainingSeconds,
      'outputSizeBytes': outputSizeBytes,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory ConversionJob.fromMap(Map<String, dynamic> map) {
    List<int> parsedTrackIndexes = [];
    final rawTrackIndexes = map['selectedAudioTrackIndexes'];
    if (rawTrackIndexes is String && rawTrackIndexes.isNotEmpty) {
      parsedTrackIndexes = rawTrackIndexes
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
    }

    return ConversionJob(
      id: map['id'] as String,
      sourcePath: map['sourcePath'] as String,
      sourceFileName: map['sourceFileName'] as String,
      sourceSizeBytes: map['sourceSizeBytes'] as int? ?? 0,
      sourceDurationMs: map['sourceDurationMs'] as int? ?? 0,
      selectedAudioTrackIndex: map['selectedAudioTrackIndex'] as int? ?? 0,
      audioStreamIndex: map['audioStreamIndex'] as int? ?? (map['selectedAudioTrackIndex'] as int? ?? 0),
      selectedAudioTrackIndexes: parsedTrackIndexes,
      selectedAudioCodec: map['selectedAudioCodec'] as String? ?? '',
      format: AudioFormat.values.firstWhere(
        (f) => f.name == map['format'],
        orElse: () => AudioFormat.mp3,
      ),
      mode: ConversionMode.values.firstWhere(
        (m) => m.name == map['mode'],
        orElse: () => ConversionMode.reEncode,
      ),
      preset: ConversionPreset.fromValue(map['preset']),
      bitrateKbps: map['bitrateKbps'] as int? ?? 192,
      sampleRateHz: map['sampleRateHz'] as int? ?? 44100,
      channelMode: ChannelMode.values.firstWhere(
        (c) => c.name == map['channelMode'],
        orElse: () => ChannelMode.keepOriginal,
      ),
      vbrEnabled: (map['vbrEnabled'] as int? ?? 0) == 1,
      vbrQuality: map['vbrQuality'] as int? ?? 2,
      volumeGainDb: (map['volumeGainDb'] as num?)?.toDouble() ?? 0.0,
      normalizeLoudness: (map['normalizeLoudness'] as int? ?? 0) == 1,
      trimStartMs: map['trimStartMs'] as int? ?? 0,
      trimEndMs: map['trimEndMs'] as int? ?? 0,
      fadeInSec: (map['fadeInSec'] as num?)?.toDouble() ?? 0.0,
      fadeOutSec: (map['fadeOutSec'] as num?)?.toDouble() ?? 0.0,
      trimSilence: (map['trimSilence'] as int? ?? 0) == 1,
      silenceThresholdDb: (map['silenceThresholdDb'] as num?)?.toDouble() ?? -50.0,
      silenceMinDurationSec: (map['silenceMinDurationSec'] as num?)?.toDouble() ?? 0.5,
      silenceTrimMode: SilenceTrimMode.values.firstWhere(
        (s) => s.name == map['silenceTrimMode'],
        orElse: () => SilenceTrimMode.leadingAndTrailing,
      ),
      destinationMode: DestinationMode.values.firstWhere(
        (d) => d.name == map['destinationMode'],
        orElse: () => DestinationMode.configuredDirectory,
      ),
      metadata: AudioMetadataTags(
        title: map['metaTitle'] as String?,
        artist: map['metaArtist'] as String?,
        album: map['metaAlbum'] as String?,
        albumArtist: map['metaAlbumArtist'] as String?,
        year: map['metaYear'] as String?,
        genre: map['metaGenre'] as String?,
        trackNumber: map['metaTrackNumber'] as String?,
        discNumber: map['metaDiscNumber'] as String?,
        composer: map['metaComposer'] as String?,
        copyright: map['metaCopyright'] as String?,
        comment: map['metaComment'] as String?,
        lyrics: map['metaLyrics'] as String?,
        language: map['metaLanguage'] as String?,
        artworkPath: map['metaArtwork'] as String?,
        stripMetadata: (map['metaStrip'] as int? ?? 0) == 1,
        preserveMetadata: (map['metaPreserve'] as int? ?? 1) == 1,
      ),
      requestedFileName: map['requestedFileName'] as String,
      outputDirectory: map['outputDirectory'] as String,
      finalOutputPath: map['finalOutputPath'] as String? ?? '',
      status: JobStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => JobStatus.queued,
      ),
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      speedRatio: (map['speedRatio'] as num?)?.toDouble() ?? 0.0,
      currentTimeMs: map['currentTimeMs'] as int? ?? 0,
      elapsedSeconds: map['elapsedSeconds'] as int? ?? 0,
      estimatedRemainingSeconds: map['estimatedRemainingSeconds'] as int? ?? 0,
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      errorMessage: map['errorMessage'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt'] as String) : null,
    );
  }
}

