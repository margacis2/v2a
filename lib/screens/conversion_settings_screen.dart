import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/conversion_config.dart';
import '../models/conversion_job.dart';
import '../models/media_file.dart';
import '../services/conversion_engine.dart';
import '../services/job_queue_service.dart';
import '../services/output_manager.dart';
import '../utils/app_transitions.dart';
import '../widgets/audio_trimmer_widget.dart';
import '../widgets/bitrate_selector_widget.dart';
import 'active_jobs_screen.dart';

class ConversionSettingsScreen extends StatefulWidget {
  final MediaFile? mediaFile;
  final List<MediaFile>? batchFiles;
  final int initialSelectedTrackIndex;

  const ConversionSettingsScreen({
    super.key,
    this.mediaFile,
    this.batchFiles,
    this.initialSelectedTrackIndex = 0,
  }) : assert(mediaFile != null || (batchFiles != null && batchFiles.length > 0));

  @override
  State<ConversionSettingsScreen> createState() => _ConversionSettingsScreenState();
}

class _ConversionSettingsScreenState extends State<ConversionSettingsScreen> {
  late AudioFormat _selectedFormat;
  late ConversionMode _selectedMode;
  late ConversionPreset _selectedPreset;
  late int _selectedTrackIndex;
  int _selectedBitrate = 192;
  int _selectedSampleRate = 44100;
  ChannelMode _selectedChannelMode = ChannelMode.stereo;
  final bool _vbrEnabled = false;
  double _volumeGainDb = 0.0;
  bool _normalizeLoudness = false;
  int _trimStartMs = 0;
  int _trimEndMs = 0;
  double _fadeInSec = 0.0;
  double _fadeOutSec = 0.0;
  bool _trimSilence = false;

  final TextEditingController _fileNameController = TextEditingController();
  final TextEditingController _metaTitleController = TextEditingController();
  final TextEditingController _metaArtistController = TextEditingController();
  final TextEditingController _metaAlbumController = TextEditingController();
  final TextEditingController _metaYearController = TextEditingController();
  final TextEditingController _metaGenreController = TextEditingController();

  String _outputDirectory = '';
  String _uniqueFileNamePreview = '';
  bool _isStreamCopyPossible = false;

  bool get isBatchMode => widget.batchFiles != null && widget.batchFiles!.isNotEmpty;
  List<MediaFile> get effectiveFiles =>
      isBatchMode ? widget.batchFiles! : [widget.mediaFile!];
  MediaFile get primaryFile => effectiveFiles.first;

  @override
  void initState() {
    super.initState();
    _selectedPreset = ConversionPreset.bestQuality;
    _selectedFormat = _selectedPreset.format;
    _selectedMode = _selectedPreset.mode;
    _selectedBitrate = _selectedPreset.bitrate;
    _selectedSampleRate = _selectedPreset.sampleRate;
    _selectedChannelMode = _selectedPreset.channelMode;
    _normalizeLoudness = _selectedPreset.normalizeLoudness;

    _selectedTrackIndex = widget.initialSelectedTrackIndex;
    _trimEndMs = primaryFile.duration.inMilliseconds;

    final baseName = p.basenameWithoutExtension(primaryFile.fileName);
    _fileNameController.text = baseName;
    _metaTitleController.text = baseName;

    _initOutputFolder();
  }

  Future<void> _initOutputFolder() async {
    final dir = await OutputManager().getActiveOutputDirectory();
    if (mounted) {
      setState(() {
        _outputDirectory = dir.path;
      });
      _updateStreamCopyCompatibility();
      _updateUniqueFileNamePreview();
    }
  }

  void _updateStreamCopyCompatibility() {
    final track = primaryFile.primaryAudioTrack;
    final codec = track?.codec ?? 'unknown';

    final isCompat = ConversionEngine().isStreamCopyCompatible(codec, _selectedFormat);
    setState(() {
      _isStreamCopyPossible = isCompat;
      if (_selectedPreset == ConversionPreset.fastestCompatible) {
        _selectedMode = isCompat ? ConversionMode.fastestCompatible : ConversionMode.reEncode;
      }
    });
  }

  Future<void> _updateUniqueFileNamePreview() async {
    if (_outputDirectory.isEmpty) return;
    final proposed = await OutputManager().resolveUniqueFileName(
      directoryPath: _outputDirectory,
      baseName: _fileNameController.text.trim().isNotEmpty
          ? _fileNameController.text.trim()
          : p.basenameWithoutExtension(primaryFile.fileName),
      extension: _selectedFormat.extension,
    );
    if (mounted) {
      setState(() {
        _uniqueFileNamePreview = proposed;
      });
    }
  }

  void _applyPreset(ConversionPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _selectedMode = preset.mode;
      _selectedFormat = preset.format;

      if (preset.bitrate > 0) {
        _selectedBitrate = preset.bitrate;
      } else if (preset.format.supportedBitrates.isNotEmpty) {
        _selectedBitrate = preset.format.defaultBitrate;
      }
      _selectedSampleRate = preset.sampleRate;
      _selectedChannelMode = preset.channelMode;
      _normalizeLoudness = preset.normalizeLoudness;

      if (preset == ConversionPreset.fastestCompatible) {
        _updateStreamCopyCompatibility();
      }
    });

    _updateStreamCopyCompatibility();
    _updateUniqueFileNamePreview();
  }

  void _markCustom() {
    if (_selectedPreset != ConversionPreset.custom) {
      setState(() {
        _selectedPreset = ConversionPreset.custom;
      });
    }
  }

  void _openTrimmerDialog() async {
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => AudioTrimmerDialog(
        totalDurationMs: primaryFile.duration.inMilliseconds,
        initialStartMs: _trimStartMs,
        initialEndMs: _trimEndMs,
      ),
    );

    if (result != null) {
      setState(() {
        _trimStartMs = result['startMs'] ?? 0;
        _trimEndMs = result['endMs'] ?? primaryFile.duration.inMilliseconds;
        _markCustom();
      });
    }
  }

  String _formatMs(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _estimateOutputSize() {
    final durationSec = ((_trimEndMs > _trimStartMs ? (_trimEndMs - _trimStartMs) : primaryFile.duration.inMilliseconds) / 1000).clamp(1.0, 1000000.0);
    if (_selectedFormat == AudioFormat.wav) {
      final bytes = durationSec * 176400;
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (_selectedFormat == AudioFormat.flac) {
      final bytes = durationSec * 90000;
      return '~${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      final kbps = _selectedMode == ConversionMode.fastestCompatible ? 128 : _selectedBitrate;
      final bytes = (durationSec * kbps * 1000) / 8;
      return '~${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  void _startConversion() async {
    final queueService = Provider.of<JobQueueService>(context, listen: false);

    if (isBatchMode) {
      // Create a separate, valid ConversionJob for EVERY file in the batch
      final batchJobs = <ConversionJob>[];

      for (int i = 0; i < effectiveFiles.length; i++) {
        final file = effectiveFiles[i];
        final track = file.primaryAudioTrack;
        final codec = track?.codec ?? '';
        final baseName = p.basenameWithoutExtension(file.fileName);

        // Individual unique target filename per batch file
        final uniqueName = await OutputManager().resolveUniqueFileName(
          directoryPath: _outputDirectory,
          baseName: baseName,
          extension: _selectedFormat.extension,
        );

        // Individual trim validation (don't apply trim if file is shorter than trim range)
        int trimStart = _trimStartMs;
        int trimEnd = _trimEndMs;
        if (trimEnd > file.duration.inMilliseconds || trimStart >= file.duration.inMilliseconds) {
          trimStart = 0;
          trimEnd = file.duration.inMilliseconds;
        }

        final job = ConversionJob(
          id: const Uuid().v4(),
          sourcePath: file.path,
          sourceFileName: file.fileName,
          sourceSizeBytes: file.sizeBytes,
          sourceDurationMs: file.duration.inMilliseconds,
          selectedAudioTrackIndex: file.audioTracks.isNotEmpty ? file.audioTracks.first.index : 0,
          selectedAudioCodec: codec,
          format: _selectedFormat,
          mode: _selectedMode,
          preset: _selectedPreset,
          bitrateKbps: _selectedBitrate,
          sampleRateHz: _selectedSampleRate,
          channelMode: _selectedChannelMode,
          vbrEnabled: _vbrEnabled,
          volumeGainDb: _volumeGainDb,
          normalizeLoudness: _normalizeLoudness,
          trimStartMs: trimStart,
          trimEndMs: trimEnd,
          fadeInSec: _fadeInSec,
          fadeOutSec: _fadeOutSec,
          trimSilence: _trimSilence,
          metadata: AudioMetadataTags(
            title: baseName,
            artist: _metaArtistController.text.trim().isNotEmpty ? _metaArtistController.text.trim() : null,
            album: _metaAlbumController.text.trim().isNotEmpty ? _metaAlbumController.text.trim() : null,
            year: _metaYearController.text.trim().isNotEmpty ? _metaYearController.text.trim() : null,
            genre: _metaGenreController.text.trim().isNotEmpty ? _metaGenreController.text.trim() : null,
          ),
          requestedFileName: uniqueName,
          outputDirectory: _outputDirectory,
          status: JobStatus.queued,
        );

        batchJobs.add(job);
      }

      await queueService.enqueueBatch(batchJobs);
    } else {
      // Single conversion job
      final track = primaryFile.primaryAudioTrack;
      final codec = track?.codec ?? '';

      final job = ConversionJob(
        id: const Uuid().v4(),
        sourcePath: primaryFile.path,
        sourceFileName: primaryFile.fileName,
        sourceSizeBytes: primaryFile.sizeBytes,
        sourceDurationMs: primaryFile.duration.inMilliseconds,
        selectedAudioTrackIndex: _selectedTrackIndex,
        selectedAudioCodec: codec,
        format: _selectedFormat,
        mode: _selectedMode,
        preset: _selectedPreset,
        bitrateKbps: _selectedBitrate,
        sampleRateHz: _selectedSampleRate,
        channelMode: _selectedChannelMode,
        vbrEnabled: _vbrEnabled,
        volumeGainDb: _volumeGainDb,
        normalizeLoudness: _normalizeLoudness,
        trimStartMs: _trimStartMs,
        trimEndMs: _trimEndMs,
        fadeInSec: _fadeInSec,
        fadeOutSec: _fadeOutSec,
        trimSilence: _trimSilence,
        metadata: AudioMetadataTags(
          title: _metaTitleController.text.trim().isNotEmpty ? _metaTitleController.text.trim() : null,
          artist: _metaArtistController.text.trim().isNotEmpty ? _metaArtistController.text.trim() : null,
          album: _metaAlbumController.text.trim().isNotEmpty ? _metaAlbumController.text.trim() : null,
          year: _metaYearController.text.trim().isNotEmpty ? _metaYearController.text.trim() : null,
          genre: _metaGenreController.text.trim().isNotEmpty ? _metaGenreController.text.trim() : null,
        ),
        requestedFileName: _uniqueFileNamePreview.isNotEmpty ? _uniqueFileNamePreview : '${_fileNameController.text.trim()}.${_selectedFormat.extension}',
        outputDirectory: _outputDirectory,
        status: JobStatus.queued,
      );

      await queueService.enqueueJob(job);
    }

    if (!mounted) return;

    // Navigate to Active Jobs Screen using smooth fade-slide transition
    Navigator.of(context).pushReplacement(
      AppTransitions.slideFadeRoute(const ActiveJobsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(isBatchMode ? 'Batch Settings (${effectiveFiles.length} files)' : 'Conversion Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Batch Mode Info Banner (Priority 2)
            if (isBatchMode) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF00ACC1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00ACC1).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_motion_rounded, color: Color(0xFF00ACC1), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Batch Conversion: ${effectiveFiles.length} Videos',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Settings configured below will be applied cleanly to all ${effectiveFiles.length} files.',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Conversion Presets Card & Dropdown (Phase 1 Fix: Crash-Proof & Full Presets)
            _buildPresetSelectorCard(theme),
            const SizedBox(height: 14),

            // Format Selection Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Output Audio Format',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          'Est: ${_estimateOutputSize()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AudioFormat.values.map((fmt) {
                        final isSelected = _selectedFormat == fmt;
                        return ChoiceChip(
                          label: Text(fmt.label),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedFormat = fmt;
                                if (fmt.supportedBitrates.isNotEmpty && !fmt.supportedBitrates.contains(_selectedBitrate)) {
                                  _selectedBitrate = fmt.defaultBitrate;
                                }
                                _markCustom();
                              });
                              _updateStreamCopyCompatibility();
                              _updateUniqueFileNamePreview();
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Mode notification banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isStreamCopyPossible ? Icons.flash_on_rounded : Icons.tune_rounded,
                                color: theme.colorScheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _isStreamCopyPossible
                                      ? 'Fastest Compatible Copy Available!'
                                      : 'High-Quality Re-encoding Active',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isStreamCopyPossible
                                ? 'Source audio stream matches ${_selectedFormat.label}. Direct stream-copy avoids re-encoding and runs with 0% quality loss.'
                                : 'Audio stream will be decoded and re-encoded to ${_selectedFormat.label} with the selected bitrate and channel layout.',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),

                    // Priority 4: Lossless Conversion from Lossy Source Notice
                    if ((_selectedFormat == AudioFormat.flac || _selectedFormat == AudioFormat.wav) &&
                        primaryFile.primaryAudioTrack != null &&
                        !primaryFile.primaryAudioTrack!.isLossless) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Source audio is lossy (${primaryFile.primaryAudioTrack!.codec.toUpperCase()}). Converting to ${_selectedFormat.label} preserves current fidelity without additional compression degradation, but cannot recreate frequencies discarded during original encoding.',
                                style: const TextStyle(fontSize: 11, color: Colors.amber, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Redesigned Bitrate & Sample Rate Card (Priority 4)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BitrateSelectorWidget(
                      format: _selectedFormat,
                      selectedBitrate: _selectedBitrate,
                      onBitrateChanged: (val) {
                        setState(() {
                          _selectedBitrate = val;
                          _markCustom();
                        });
                      },
                    ),
                    const Divider(height: 24),

                    // Sample Rate Row (Responsive & Crash-Proof)
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text('Sample Rate:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        _buildSampleRateDropdown(),
                      ],
                    ),

                    // Channels Row (Responsive & Crash-Proof)
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text('Channels:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        _buildChannelsDropdown(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Precise Audio Trimming & Filters Card (Priority 5)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              Icon(Icons.content_cut_rounded, color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              const Text('Audio Trimming', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.timer_outlined, size: 16),
                          label: Text(
                            _trimStartMs > 0 || _trimEndMs < primaryFile.duration.inMilliseconds
                                ? '${_formatMs(_trimStartMs)} - ${_formatMs(_trimEndMs)}'
                                : 'Set Trim',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: _openTrimmerDialog,
                        ),
                      ],
                    ),
                    if (_trimStartMs > 0 || _trimEndMs < primaryFile.duration.inMilliseconds) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Active Trim: ${_formatMs(_trimStartMs)} to ${_formatMs(_trimEndMs)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _trimStartMs = 0;
                                  _trimEndMs = primaryFile.duration.inMilliseconds;
                                });
                              },
                              child: const Text('Reset', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Divider(height: 20),

                    // Audio Enhancements (Volume boost & Loudness Normalization)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Volume Adjustment:', style: TextStyle(fontSize: 13)),
                        Text('${_volumeGainDb >= 0 ? "+" : ""}${_volumeGainDb.toStringAsFixed(1)} dB',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _volumeGainDb,
                      min: -12.0,
                      max: 12.0,
                      divisions: 24,
                      onChanged: (val) {
                        setState(() {
                          _volumeGainDb = val;
                          _markCustom();
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Loudness Normalization (EBU R128)', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('Balancing dynamic peaks and quiet dialogue', style: TextStyle(fontSize: 11)),
                      value: _normalizeLoudness,
                      onChanged: (val) {
                        setState(() {
                          _normalizeLoudness = val;
                          _markCustom();
                        });
                      },
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fade In:', style: TextStyle(fontSize: 13)),
                        Text('${_fadeInSec.toStringAsFixed(1)} s', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _fadeInSec,
                      min: 0.0,
                      max: 10.0,
                      divisions: 20,
                      onChanged: (val) {
                        setState(() {
                          _fadeInSec = val;
                          _markCustom();
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fade Out:', style: TextStyle(fontSize: 13)),
                        Text('${_fadeOutSec.toStringAsFixed(1)} s', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _fadeOutSec,
                      min: 0.0,
                      max: 10.0,
                      divisions: 20,
                      onChanged: (val) {
                        setState(() {
                          _fadeOutSec = val;
                          _markCustom();
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Trim Silence', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('Automatically remove leading & trailing silence', style: TextStyle(fontSize: 11)),
                      value: _trimSilence,
                      onChanged: (val) {
                        setState(() {
                          _trimSilence = val;
                          _markCustom();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Metadata Tags (Single File or Batch Author)
            Card(
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: Icon(Icons.label_outline_rounded, color: theme.colorScheme.primary),
                  title: const Text('ID3 Tags & Metadata', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    isBatchMode ? 'Set artist/album tags for entire batch' : 'Track title, artist, album, genre',
                    style: const TextStyle(fontSize: 11),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                      child: Column(
                        children: [
                          if (!isBatchMode) ...[
                            TextField(
                              controller: _metaTitleController,
                              decoration: const InputDecoration(labelText: 'Track Title', isDense: true),
                            ),
                            const SizedBox(height: 8),
                          ],
                          TextField(
                            controller: _metaArtistController,
                            decoration: const InputDecoration(labelText: 'Artist / Author', isDense: true),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _metaAlbumController,
                            decoration: const InputDecoration(labelText: 'Album', isDense: true),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _metaYearController,
                                  decoration: const InputDecoration(labelText: 'Year', isDense: true),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _metaGenreController,
                                  decoration: const InputDecoration(labelText: 'Genre', isDense: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Central Duplicate-Safe Output Manager Preview (Priority 6)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Save Destination & Duplicate Safety',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (!isBatchMode) ...[
                      TextField(
                        controller: _fileNameController,
                        decoration: InputDecoration(
                          labelText: 'Desired Output File Name',
                          suffixText: '.${_selectedFormat.extension}',
                          isDense: true,
                        ),
                        onChanged: (_) => _updateUniqueFileNamePreview(),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222A) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.folder_special_rounded, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _outputDirectory,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isBatchMode
                                ? 'Files will be saved with safe collision-free numbering in your V2A directory.'
                                : 'Destination preview: $_uniqueFileNamePreview (Auto-numbered if duplicate exists).',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Start Conversion Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _startConversion,
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: Text(
                  isBatchMode ? 'Start Batch Conversion (${effectiveFiles.length} files)' : 'Start Conversion',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetSelectorCard(ThemeData theme) {
    final activePreset = ConversionPreset.values.contains(_selectedPreset)
        ? _selectedPreset
        : ConversionPreset.bestQuality;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Conversion Preset',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (_selectedPreset == ConversionPreset.custom)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Custom Config', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Dedicated Preset Dropdown (Crash-proof, stable ID mapping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ConversionPreset>(
                  isExpanded: true,
                  value: activePreset,
                  items: ConversionPreset.values.map((preset) {
                    return DropdownMenuItem<ConversionPreset>(
                      value: preset,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            preset.label,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            preset.description,
                            style: TextStyle(fontSize: 10, color: theme.hintColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (preset) {
                    if (preset != null) {
                      _applyPreset(preset);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Quick preset chips for rapid selection
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ConversionPreset.values.where((p) => p != ConversionPreset.custom).map((preset) {
                  final isSelected = _selectedPreset == preset;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(preset.label, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      onSelected: (_) => _applyPreset(preset),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleRateDropdown() {
    final Map<int, String> sampleRateMap = {
      0: 'Auto (Source Sample Rate)',
      48000: '48.0 kHz (Studio)',
      44100: '44.1 kHz (CD Quality)',
      32000: '32.0 kHz (Broadcast)',
      24000: '24.0 kHz (Speech)',
      22050: '22.05 kHz (Compact)',
      16000: '16.0 kHz (Low Bandwidth)',
      12000: '12.0 kHz',
      8000: '8.0 kHz (Telephone)',
    };

    if (!sampleRateMap.containsKey(_selectedSampleRate)) {
      sampleRateMap[_selectedSampleRate] = ' kHz';
    }

    return DropdownButton<int>(
      value: _selectedSampleRate,
      underline: const SizedBox(),
      items: sampleRateMap.entries.map((entry) {
        return DropdownMenuItem<int>(
          value: entry.key,
          child: Text(entry.value, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedSampleRate = val;
            _markCustom();
          });
        }
      },
    );
  }

  Widget _buildChannelsDropdown() {
    final validMode = ChannelMode.values.contains(_selectedChannelMode)
        ? _selectedChannelMode
        : ChannelMode.keepOriginal;

    return DropdownButton<ChannelMode>(
      value: validMode,
      underline: const SizedBox(),
      items: ChannelMode.values.map((mode) {
        return DropdownMenuItem<ChannelMode>(
          value: mode,
          child: Text(mode.label, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedChannelMode = val;
            _markCustom();
          });
        }
      },
    );
  }
}
