enum AudioFormat {
  mp3(
    'MP3',
    'mp3',
    'libmp3lame',
    true,
    [16, 32, 64, 96, 128, 160, 192, 224, 256, 320],
    192,
  ),
  aac(
    'AAC (M4A)',
    'm4a',
    'aac',
    true,
    [16, 32, 64, 96, 128, 160, 192, 224, 256, 320],
    192,
  ),
  wav(
    'WAV (Lossless PCM)',
    'wav',
    'pcm_s16le',
    false,
    [1411],
    1411,
  ),
  flac(
    'FLAC (Lossless)',
    'flac',
    'flac',
    false,
    [0],
    0,
  ),
  opus(
    'Opus (High Efficiency)',
    'opus',
    'libopus',
    true,
    [16, 32, 64, 96, 128, 160, 192, 224, 256, 320],
    128,
  ),
  ogg(
    'OGG Vorbis',
    'ogg',
    'libvorbis',
    true,
    [32, 64, 96, 128, 160, 192, 224, 256, 320],
    160,
  );

  final String label;
  final String extension;
  final String ffmpegCodec;
  final bool isLossy;
  final List<int> supportedBitrates; // in kbps
  final int defaultBitrate;

  const AudioFormat(
    this.label,
    this.extension,
    this.ffmpegCodec,
    this.isLossy,
    this.supportedBitrates,
    this.defaultBitrate,
  );

  static AudioFormat fromExtension(String ext) {
    final clean = ext.toLowerCase().replaceAll('.', '');
    if (clean == 'm4a' || clean == 'aac') return AudioFormat.aac;
    if (clean == 'wav') return AudioFormat.wav;
    if (clean == 'flac') return AudioFormat.flac;
    if (clean == 'opus') return AudioFormat.opus;
    if (clean == 'ogg') return AudioFormat.ogg;
    return AudioFormat.mp3;
  }
}

enum ConversionMode {
  fastestCompatible(
    'Fastest Compatible (Stream Copy)',
    'Extracts audio directly without re-encoding when source codec matches. Instantaneous, zero quality loss, lowest battery usage.',
  ),
  reEncode(
    'Re-encode & Compress',
    'Custom bitrate, sample rate, channels, volume boost, normalization, and filters.',
  ),
  lossless(
    'Lossless Audio',
    'Preserves maximum audio fidelity using FLAC or PCM WAV containers.',
  );

  final String title;
  final String description;
  const ConversionMode(this.title, this.description);
}

enum ConversionPreset {
  fastestCompatible(
    'fastest_compatibility',
    'Fastest Compatibility',
    'Direct stream-copy without transcoding when codecs match; instant and 0% quality loss',
    ConversionMode.fastestCompatible,
    AudioFormat.aac,
    0,
    0,
    ChannelMode.keepOriginal,
    false,
  ),
  balanced(
    'balanced',
    'Balanced',
    'Standard audio balance for everyday playback (MP3, 192 kbps, 44.1 kHz stereo)',
    ConversionMode.reEncode,
    AudioFormat.mp3,
    192,
    44100,
    ChannelMode.stereo,
    false,
  ),
  bestQuality(
    'best_quality',
    'Best Quality',
    'Maximum MP3 fidelity (320 kbps CBR, 48 kHz stereo)',
    ConversionMode.reEncode,
    AudioFormat.mp3,
    320,
    48000,
    ChannelMode.stereo,
    false,
  ),
  smallestPractical(
    'smallest_practical',
    'Smallest Practical File',
    'Compact high-efficiency audio (Opus, 48 kbps, 24 kHz mono)',
    ConversionMode.reEncode,
    AudioFormat.opus,
    48,
    24000,
    ChannelMode.mono,
    false,
  ),
  voiceSpeech(
    'voice_speech',
    'Voice or Speech',
    'Speech & dialogue clarity optimization (Opus, 64 kbps, 24 kHz mono)',
    ConversionMode.reEncode,
    AudioFormat.opus,
    64,
    24000,
    ChannelMode.mono,
    false,
  ),
  music(
    'music',
    'Music',
    'Optimized high-fidelity music (AAC, 256 kbps, 48 kHz stereo)',
    ConversionMode.reEncode,
    AudioFormat.aac,
    256,
    48000,
    ChannelMode.stereo,
    false,
  ),
  losslessMaster(
    'lossless_master',
    'Lossless Master',
    'Bit-perfect studio archival in FLAC container at source sample rate',
    ConversionMode.lossless,
    AudioFormat.flac,
    0,
    0,
    ChannelMode.keepOriginal,
    false,
  ),
  maxCompression(
    'max_compression',
    'Maximum Compression',
    'Ultra-compact file size for sharing (Opus, 32 kbps, 16 kHz mono)',
    ConversionMode.reEncode,
    AudioFormat.opus,
    32,
    16000,
    ChannelMode.mono,
    false,
  ),
  custom(
    'custom',
    'Custom',
    'User-defined custom audio parameters',
    ConversionMode.reEncode,
    AudioFormat.mp3,
    192,
    44100,
    ChannelMode.keepOriginal,
    false,
  );

  final String id;
  final String label;
  final String description;
  final ConversionMode mode;
  final AudioFormat format;
  final int bitrate;
  final int sampleRate;
  final ChannelMode channelMode;
  final bool normalizeLoudness;

  const ConversionPreset(
    this.id,
    this.label,
    this.description,
    this.mode,
    this.format,
    this.bitrate,
    this.sampleRate,
    this.channelMode,
    this.normalizeLoudness,
  );

  // Backward compatibility getters
  static ConversionPreset get highFidelityAac => music;
  static ConversionPreset get universalPodcast => balanced;
  static ConversionPreset get losslessWav => losslessMaster;

  /// Safe, tolerant resolver from any ID, string, name, or legacy integer
  static ConversionPreset fromValue(dynamic val) {
    if (val == null) return ConversionPreset.bestQuality;
    if (val is ConversionPreset) return val;
    if (val is int) {
      if (val >= 0 && val < ConversionPreset.values.length) {
        return ConversionPreset.values[val];
      }
      return ConversionPreset.bestQuality;
    }
    final raw = val.toString().trim();
    if (raw.isEmpty) return ConversionPreset.bestQuality;

    final lower = raw.toLowerCase();
    for (final p in ConversionPreset.values) {
      if (p.id.toLowerCase() == lower ||
          p.name.toLowerCase() == lower ||
          p.label.toLowerCase() == lower) {
        return p;
      }
    }

    // Heuristic fallbacks for legacy or display names
    if (lower.contains('fastest')) return ConversionPreset.fastestCompatible;
    if (lower.contains('balanced')) return ConversionPreset.balanced;
    if (lower.contains('best')) return ConversionPreset.bestQuality;
    if (lower.contains('smallest')) return ConversionPreset.smallestPractical;
    if (lower.contains('voice') || lower.contains('speech')) return ConversionPreset.voiceSpeech;
    if (lower.contains('music')) return ConversionPreset.music;
    if (lower.contains('flac') || lower.contains('lossless master')) return ConversionPreset.losslessMaster;
    if (lower.contains('wav')) return ConversionPreset.losslessWav;
    if (lower.contains('max') || lower.contains('compression')) return ConversionPreset.maxCompression;
    if (lower.contains('podcast')) return ConversionPreset.universalPodcast;
    if (lower.contains('custom')) return ConversionPreset.custom;

    return ConversionPreset.bestQuality;
  }
}

enum ChannelMode {
  keepOriginal('Keep Original', null),
  mono('Mono (1 ch)', 1),
  stereo('Stereo (2 ch)', 2);

  final String label;
  final int? channelCount;
  const ChannelMode(this.label, this.channelCount);
}
