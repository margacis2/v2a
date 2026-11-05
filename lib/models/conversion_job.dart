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

class AudioMetadataTags {
  final String? title;
  final String? artist;
  final String? album;
  final String? year;
  final String? genre;
  final String? artworkPath;

  const AudioMetadataTags({
    this.title,
    this.artist,
    this.album,
    this.year,
    this.genre,
    this.artworkPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'year': year,
      'genre': genre,
      'artworkPath': artworkPath,
    };
  }

  factory AudioMetadataTags.fromMap(Map<String, dynamic> map) {
    return AudioMetadataTags(
      title: map['title'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      year: map['year'] as String?,
      genre: map['genre'] as String?,
      artworkPath: map['artworkPath'] as String?,
    );
  }
}

class ConversionJob {
  final String id;
  final String sourcePath;
  final String sourceFileName;
  final int sourceSizeBytes;
  final int sourceDurationMs;
  final int selectedAudioTrackIndex;
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
  final double volumeGainDb; // -12 to +12 dB
  final bool normalizeLoudness;
  final int trimStartMs;
  final int trimEndMs; // 0 means end of source
  final double fadeInSec;
  final double fadeOutSec;
  final bool trimSilence;
  final AudioMetadataTags metadata;

  // Output details
  final String requestedFileName;
  final String outputDirectory;
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
    this.metadata = const AudioMetadataTags(),
    required this.requestedFileName,
    required this.outputDirectory,
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
  }) {
    return ConversionJob(
      id: id,
      sourcePath: sourcePath,
      sourceFileName: sourceFileName,
      sourceSizeBytes: sourceSizeBytes,
      sourceDurationMs: sourceDurationMs,
      selectedAudioTrackIndex: selectedAudioTrackIndex,
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
      metadata: metadata,
      requestedFileName: requestedFileName,
      outputDirectory: outputDirectory,
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
      'metaTitle': metadata.title,
      'metaArtist': metadata.artist,
      'metaAlbum': metadata.album,
      'metaYear': metadata.year,
      'metaGenre': metadata.genre,
      'metaArtwork': metadata.artworkPath,
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
    return ConversionJob(
      id: map['id'] as String,
      sourcePath: map['sourcePath'] as String,
      sourceFileName: map['sourceFileName'] as String,
      sourceSizeBytes: map['sourceSizeBytes'] as int? ?? 0,
      sourceDurationMs: map['sourceDurationMs'] as int? ?? 0,
      selectedAudioTrackIndex: map['selectedAudioTrackIndex'] as int? ?? 0,
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
      metadata: AudioMetadataTags(
        title: map['metaTitle'] as String?,
        artist: map['metaArtist'] as String?,
        album: map['metaAlbum'] as String?,
        year: map['metaYear'] as String?,
        genre: map['metaGenre'] as String?,
        artworkPath: map['metaArtwork'] as String?,
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

