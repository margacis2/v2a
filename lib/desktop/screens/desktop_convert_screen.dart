import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../models/conversion_config.dart';
import '../../models/conversion_job.dart';
import '../../models/media_file.dart';
import '../../services/desktop_media_engine.dart';
import '../../services/job_queue_service.dart';
import '../../services/output_manager.dart';

class DesktopConvertScreen extends StatefulWidget {
  final String? initialFilePath;
  final ValueChanged<int> onNavigate;

  const DesktopConvertScreen({
    super.key,
    this.initialFilePath,
    required this.onNavigate,
  });

  @override
  State<DesktopConvertScreen> createState() => _DesktopConvertScreenState();
}

class _DesktopConvertScreenState extends State<DesktopConvertScreen> {
  final DesktopMediaEngine _engine = DesktopMediaEngine();
  final OutputManager _outputManager = OutputManager();

  // Multi-file selection & batch queue
  final List<String> _selectedFiles = [];
  int _activeFileIndex = 0;
  final Map<String, MediaFile> _inspectedMediaCache = {};
  bool _isProbing = false;

  // Multi-stream selection
  final Set<int> _selectedAudioStreamIndexes = {};
  bool _convertAllAudioTracks = false;

  // Conversion Settings
  ConversionPreset _selectedPreset = ConversionPreset.balanced;
  AudioFormat _selectedFormat = AudioFormat.mp3;
  ConversionMode _selectedMode = ConversionMode.reEncode;

  // Audio Configuration
  int _bitrateKbps = 192;
  bool _isCustomBitrate = false;
  final TextEditingController _customBitrateController = TextEditingController();

  int _sampleRateHz = 44100;
  ChannelMode _channelMode = ChannelMode.stereo;
  bool _vbrEnabled = false;
  final int _vbrQuality = 2;

  // Volume & Filters
  double _volumeGainDb = 0.0;
  final TextEditingController _volumeTextController = TextEditingController(text: '0.0');
  bool _normalizeLoudness = false;
  bool _trimSilence = false;
  final double _silenceThresholdDb = -50.0;
  final double _silenceMinDurationSec = 0.5;
  SilenceTrimMode _silenceTrimMode = SilenceTrimMode.leadingAndTrailing;

  double _fadeInSec = 0.0;
  double _fadeOutSec = 0.0;

  // Metadata Tags & Artwork
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _albumController = TextEditingController();
  final TextEditingController _albumArtistController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _genreController = TextEditingController();
  final TextEditingController _trackNumberController = TextEditingController();
  final TextEditingController _discNumberController = TextEditingController();
  final TextEditingController _composerController = TextEditingController();
  final TextEditingController _copyrightController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _lyricsController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();
  String? _artworkPath;
  bool _stripMetadata = false;
  bool _preserveMetadata = true;
  bool _metadataAccordionExpanded = false;

  // Output destination & filename
  final TextEditingController _fileNameController = TextEditingController();
  DestinationMode _destinationMode = DestinationMode.configuredDirectory;
  String _configuredOutputDirectory = '';
  String _customOutputDirectory = '';

  @override
  void initState() {
    super.initState();
    _loadDefaultDirectory();
    if (widget.initialFilePath != null) {
      _loadFiles([widget.initialFilePath!]);
    }
  }

  @override
  void didUpdateWidget(DesktopConvertScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilePath != null && widget.initialFilePath != oldWidget.initialFilePath) {
      _loadFiles([widget.initialFilePath!]);
    }
  }

  @override
  void dispose() {
    _customBitrateController.dispose();
    _volumeTextController.dispose();
    _fileNameController.dispose();
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _albumArtistController.dispose();
    _yearController.dispose();
    _genreController.dispose();
    _trackNumberController.dispose();
    _discNumberController.dispose();
    _composerController.dispose();
    _copyrightController.dispose();
    _commentController.dispose();
    _lyricsController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultDirectory() async {
    final dir = await _outputManager.getActiveOutputDirectory();
    if (mounted) {
      setState(() {
        _configuredOutputDirectory = dir.path;
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
                  type: FileType.custom,
      allowedExtensions: [
        'mp4', 'mkv', 'mov', 'avi', 'flv', 'wmv', 'webm', '3gp', 'm4v', 'ts', 'mts',
        'mp3', 'aac', 'm4a', 'wav', 'flac', 'ogg', 'opus',
      ],
    );

    if (result.isNotEmpty) {
      final paths = result.map((f) => f.path).whereType<String>().toList();
      if (paths.isNotEmpty) {
        _loadFiles(paths);
      }
    }
  }

  Future<void> _loadFiles(List<String> paths) async {
    setState(() {
      _selectedFiles.clear();
      _selectedFiles.addAll(paths);
      _activeFileIndex = 0;
      _isProbing = true;
    });

    for (final path in paths) {
      if (!_inspectedMediaCache.containsKey(path)) {
        final inspected = await _engine.inspectMedia(path);
        _inspectedMediaCache[path] = inspected;
      }
    }

    if (mounted && _selectedFiles.isNotEmpty) {
      final activePath = _selectedFiles[_activeFileIndex];
      final activeMedia = _inspectedMediaCache[activePath];

      setState(() {
        _isProbing = false;
        _initFileSelection(activePath, activeMedia);
      });
    }
  }

  void _initFileSelection(String path, MediaFile? media) {
    _fileNameController.text = p.basenameWithoutExtension(path);
    _titleController.text = p.basenameWithoutExtension(path);
    _selectedAudioStreamIndexes.clear();
    _convertAllAudioTracks = false;

    if (media != null && media.audioTracks.isNotEmpty) {
      // Find default audio track, otherwise first audio stream
      final defTrack = media.audioTracks.firstWhere(
        (t) => t.isDefault,
        orElse: () => media.audioTracks.first,
      );
      _selectedAudioStreamIndexes.add(defTrack.audioStreamIndex);
    }
  }

  void _setActiveFile(int index) {
    if (index >= 0 && index < _selectedFiles.length) {
      setState(() {
        _activeFileIndex = index;
        final path = _selectedFiles[index];
        final media = _inspectedMediaCache[path];
        _initFileSelection(path, media);
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      if (_activeFileIndex >= _selectedFiles.length) {
        _activeFileIndex = _selectedFiles.length - 1;
      }
      if (_selectedFiles.isNotEmpty) {
        final path = _selectedFiles[_activeFileIndex];
        final media = _inspectedMediaCache[path];
        _initFileSelection(path, media);
      }
    });
  }

  void _applyPreset(ConversionPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _selectedFormat = preset.format;
      _bitrateKbps = preset.bitrate;
      _isCustomBitrate = false;
      _sampleRateHz = preset.sampleRate;
      _channelMode = preset.channelMode;
      _vbrEnabled = false;
      if (preset == ConversionPreset.fastestCompatible) {
        _selectedMode = ConversionMode.fastestCompatible;
      } else if (preset == ConversionPreset.losslessMaster) {
        _selectedMode = ConversionMode.lossless;
      } else {
        _selectedMode = ConversionMode.reEncode;
      }
    });
  }

  Future<void> _pickArtwork() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result.isNotEmpty && result.first.path != null) {
      setState(() {
        _artworkPath = result.first.path;
      });
    }
  }

  Future<void> _pickCustomOutputDirectory() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Custom Destination Folder',
      initialDirectory: _configuredOutputDirectory.isNotEmpty ? _configuredOutputDirectory : null,
    );
    if (path != null && mounted) {
      setState(() {
        _customOutputDirectory = path;
        _destinationMode = DestinationMode.customFolder;
      });
    }
  }

  Future<void> _enqueueConversion({bool startImmediately = true}) async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one media file first')),
      );
      return;
    }

    // Ensure all selected files have inspected metadata before enqueuing
    for (final filePath in _selectedFiles) {
      if (!_inspectedMediaCache.containsKey(filePath)) {
        try {
          final inspected = await _engine.inspectMedia(filePath);
          _inspectedMediaCache[filePath] = inspected;
        } catch (_) {}
      }
    }

    final queue = Provider.of<JobQueueService>(context, listen: false);
    final List<ConversionJob> batchJobs = [];

    for (int fileIdx = 0; fileIdx < _selectedFiles.length; fileIdx++) {
      final filePath = _selectedFiles[fileIdx];
      var media = _inspectedMediaCache[filePath];
      if (media == null) {
        // Fallback synthetic media object if ffprobe failed or was unavailable
        final file = File(filePath);
        final sizeBytes = file.existsSync() ? file.lengthSync() : 0;
        media = MediaFile(
          id: filePath,
          filePath: filePath,
          fileName: p.basename(filePath),
          sizeBytes: sizeBytes,
          duration: const Duration(seconds: 0),
          format: p.extension(filePath).replaceAll('.', ''),
          isVideo: true,
          audioTracks: [
            AudioTrackInfo(
              index: 0,
              audioStreamIndex: 0,
              codec: 'aac',
              channels: 2,
              channelLayout: 'stereo',
              sampleRate: 44100,
              isDefault: true,
            ),
          ],
        );
      }

      // Determine output directory based on destination mode
      String resolvedDirectory = _configuredOutputDirectory;
      if (_destinationMode == DestinationMode.besideOriginalFile) {
        resolvedDirectory = p.dirname(filePath);
      } else if (_destinationMode == DestinationMode.customFolder && _customOutputDirectory.isNotEmpty) {
        resolvedDirectory = _customOutputDirectory;
      }

      final requestedBase = fileIdx == _activeFileIndex && _fileNameController.text.trim().isNotEmpty
          ? _fileNameController.text.trim()
          : p.basenameWithoutExtension(filePath);

      // Determine audio streams to convert
      List<AudioTrackInfo> tracksToConvert = [];
      if (_convertAllAudioTracks) {
        tracksToConvert = media.audioTracks;
      } else if (_selectedAudioStreamIndexes.isNotEmpty) {
        tracksToConvert = media.audioTracks
            .where((t) => _selectedAudioStreamIndexes.contains(t.audioStreamIndex))
            .toList();
      }

      if (tracksToConvert.isEmpty && media.audioTracks.isNotEmpty) {
        tracksToConvert = [media.audioTracks.first];
      }

      final metadataTags = AudioMetadataTags(
        title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
        artist: _artistController.text.trim().isNotEmpty ? _artistController.text.trim() : null,
        album: _albumController.text.trim().isNotEmpty ? _albumController.text.trim() : null,
        albumArtist: _albumArtistController.text.trim().isNotEmpty ? _albumArtistController.text.trim() : null,
        year: _yearController.text.trim().isNotEmpty ? _yearController.text.trim() : null,
        genre: _genreController.text.trim().isNotEmpty ? _genreController.text.trim() : null,
        trackNumber: _trackNumberController.text.trim().isNotEmpty ? _trackNumberController.text.trim() : null,
        discNumber: _discNumberController.text.trim().isNotEmpty ? _discNumberController.text.trim() : null,
        composer: _composerController.text.trim().isNotEmpty ? _composerController.text.trim() : null,
        copyright: _copyrightController.text.trim().isNotEmpty ? _copyrightController.text.trim() : null,
        comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
        lyrics: _lyricsController.text.trim().isNotEmpty ? _lyricsController.text.trim() : null,
        language: _languageController.text.trim().isNotEmpty ? _languageController.text.trim() : null,
        artworkPath: _artworkPath,
        stripMetadata: _stripMetadata,
        preserveMetadata: _preserveMetadata,
      );

      final effectiveBitrate = _isCustomBitrate
          ? (int.tryParse(_customBitrateController.text.trim()) ?? _bitrateKbps)
          : _bitrateKbps;

      // If user selected multiple tracks from a single file, generate subjobs for each track
      if (tracksToConvert.length > 1) {
        for (final track in tracksToConvert) {
          final langSuffix = track.language != null ? '_${track.language}' : '';
          final trackName = '${requestedBase}_Track${track.audioStreamIndex + 1}$langSuffix';

          batchJobs.add(
            ConversionJob(
              id: 'job_${DateTime.now().millisecondsSinceEpoch}_${batchJobs.length}',
              sourcePath: filePath,
              sourceFileName: media.fileName,
              sourceSizeBytes: media.sizeBytes,
              sourceDurationMs: media.duration.inMilliseconds,
              selectedAudioTrackIndex: track.index,
              audioStreamIndex: track.audioStreamIndex,
              selectedAudioCodec: track.codec,
              requestedFileName: trackName,
              outputDirectory: resolvedDirectory,
              destinationMode: _destinationMode,
              format: _selectedFormat,
              mode: _selectedMode,
              preset: _selectedPreset,
              bitrateKbps: effectiveBitrate,
              sampleRateHz: _sampleRateHz,
              channelMode: _channelMode,
              vbrEnabled: _vbrEnabled,
              vbrQuality: _vbrQuality,
              volumeGainDb: _volumeGainDb,
              normalizeLoudness: _normalizeLoudness,
              trimSilence: _trimSilence,
              silenceThresholdDb: _silenceThresholdDb,
              silenceMinDurationSec: _silenceMinDurationSec,
              silenceTrimMode: _silenceTrimMode,
              fadeInSec: _fadeInSec,
              fadeOutSec: _fadeOutSec,
              metadata: metadataTags.copyWith(
                language: track.language ?? metadataTags.language,
                title: track.title ?? metadataTags.title,
              ),
            ),
          );
        }
      } else {
        final track = tracksToConvert.isNotEmpty ? tracksToConvert.first : null;
        batchJobs.add(
          ConversionJob(
            id: 'job_${DateTime.now().millisecondsSinceEpoch}_${batchJobs.length}',
            sourcePath: filePath,
            sourceFileName: media.fileName,
            sourceSizeBytes: media.sizeBytes,
            sourceDurationMs: media.duration.inMilliseconds,
            selectedAudioTrackIndex: track?.index ?? 0,
            audioStreamIndex: track?.audioStreamIndex ?? 0,
            selectedAudioCodec: track?.codec ?? '',
            requestedFileName: requestedBase,
            outputDirectory: resolvedDirectory,
            destinationMode: _destinationMode,
            format: _selectedFormat,
            mode: _selectedMode,
            preset: _selectedPreset,
            bitrateKbps: effectiveBitrate,
            sampleRateHz: _sampleRateHz,
            channelMode: _channelMode,
            vbrEnabled: _vbrEnabled,
            vbrQuality: _vbrQuality,
            volumeGainDb: _volumeGainDb,
            normalizeLoudness: _normalizeLoudness,
            trimSilence: _trimSilence,
            silenceThresholdDb: _silenceThresholdDb,
            silenceMinDurationSec: _silenceMinDurationSec,
            silenceTrimMode: _silenceTrimMode,
            fadeInSec: _fadeInSec,
            fadeOutSec: _fadeOutSec,
            metadata: metadataTags,
          ),
        );
      }
    }

    await queue.enqueueBatch(batchJobs);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${batchJobs.length} item(s) to conversion queue'),
          action: SnackBarAction(
            label: 'View Queue',
            onPressed: () => widget.onNavigate(2),
          ),
        ),
      );
      widget.onNavigate(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final MediaFile? currentMedia = _selectedFiles.isNotEmpty && _activeFileIndex < _selectedFiles.length
        ? _inspectedMediaCache[_selectedFiles[_activeFileIndex]]
        : null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13151B) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio Converter',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Professional audio extraction, batch transcode & multichannel routing',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: const Text('Add Files / Batch'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Select Input File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Source File Card & Multi-File Batch Strip
            if (_selectedFiles.isEmpty)
              _buildEmptyFilePrompt(context)
            else if (_isProbing)
              _buildProbingCard(context)
            else ...[
              if (_selectedFiles.length > 1) _buildBatchFileList(context),
              if (currentMedia != null) _buildMediaInfoCard(context, currentMedia),
            ],

            const SizedBox(height: 28),

            // Conversion Presets Grid (8 Presets)
            Text(
              'Conversion Presets',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildPresetGrid(context),

            const SizedBox(height: 28),

            // Audio Stream Selection (MKV / MP4 Multi-Stream)
            if (currentMedia != null && currentMedia.audioTracks.isNotEmpty) ...[
              Text(
                'Audio Stream Routing',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildAudioStreamSelectorCard(context, currentMedia),
              const SizedBox(height: 28),
            ],

            // Format & Advanced Quality Controls
            Text(
              'Output Parameters',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFormatOptionsCard(context),

            const SizedBox(height: 28),

            // Audio Filters Pipeline & Sound Effects
            Text(
              'Audio Enhancement & Processing',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildAudioFiltersCard(context),

            const SizedBox(height: 28),

            // Metadata & Tagging Accordion
            Text(
              'Metadata & Container Tags',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildMetadataAccordion(context),

            const SizedBox(height: 28),

            // Output Destination & Target Filename
            Text(
              'Output Destination',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDestinationCard(context),

            const SizedBox(height: 36),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedFiles.isNotEmpty ? () => _enqueueConversion(startImmediately: false) : null,
                    icon: const Icon(Icons.playlist_add_rounded),
                    label: Text(_selectedFiles.length > 1 ? 'Enqueue All Batch Items' : 'Add to Queue'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _selectedFiles.isNotEmpty ? () => _enqueueConversion(startImmediately: true) : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(_selectedFiles.length > 1 ? 'Convert All Batch Items Now' : 'Convert Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchFileList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E232F) : const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Batch Input Queue (${_selectedFiles.length} files selected)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'Click a file to inspect and customize',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_selectedFiles.length, (idx) {
              final isCurrent = idx == _activeFileIndex;
              final path = _selectedFiles[idx];
              final name = p.basename(path);

              return InputChip(
                label: Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? Colors.white : (isDark ? Colors.grey[300] : Colors.black87),
                  ),
                ),
                selected: isCurrent,
                selectedColor: const Color(0xFF2563EB),
                backgroundColor: isDark ? const Color(0xFF13151B) : Colors.white,
                onSelected: (_) => _setActiveFile(idx),
                onDeleted: () => _removeFile(idx),
                deleteIconColor: isCurrent ? Colors.white : Colors.grey,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilePrompt(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1E27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.video_file_outlined, size: 52, color: Colors.grey[400]),
            const SizedBox(height: 14),
            const Text(
              'No Media File Selected',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick a single video or select multiple files for high-speed batch audio extraction',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Select Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProbingCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1E27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 16),
          Text(
            'Probing container metadata and audio streams with FFprobe...',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaInfoCard(BuildContext context, MediaFile file) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1E27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  file.videoCodec != null ? Icons.videocam_rounded : Icons.audiotrack_rounded,
                  color: const Color(0xFF2563EB),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${file.formattedDuration} • ${(file.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB • Container: ${file.extension.toUpperCase()} • Video: ${file.videoCodec ?? "None"} • ${file.audioTracks.length} Audio Stream(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioStreamSelectorCard(BuildContext context, MediaFile media) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1E27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Audio Tracks in Container',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Row(
                children: [
                  Checkbox(
                    value: _convertAllAudioTracks,
                    activeColor: const Color(0xFF2563EB),
                    onChanged: (val) {
                      setState(() {
                        _convertAllAudioTracks = val ?? false;
                      });
                    },
                  ),
                  const Text('Convert all audio tracks into separate files', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: media.audioTracks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final track = media.audioTracks[idx];
              final isSelected = _convertAllAudioTracks || _selectedAudioStreamIndexes.contains(track.audioStreamIndex);

              return InkWell(
                onTap: _convertAllAudioTracks
                    ? null
                    : () {
                        setState(() {
                          if (_selectedAudioStreamIndexes.contains(track.audioStreamIndex)) {
                            if (_selectedAudioStreamIndexes.length > 1) {
                              _selectedAudioStreamIndexes.remove(track.audioStreamIndex);
                            }
                          } else {
                            _selectedAudioStreamIndexes.add(track.audioStreamIndex);
                          }
                        });
                      },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.08)
                        : (isDark ? const Color(0xFF13151B) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        color: isSelected ? const Color(0xFF2563EB) : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          track.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (track.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DEFAULT',
                            style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPresetGrid(BuildContext context) {
    final presets = ConversionPreset.values;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.85,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        final isSelected = _selectedPreset == preset;

        return InkWell(
          onTap: () => _applyPreset(preset),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12)
                  : (isDark ? const Color(0xFF1A1E27) : Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0)),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        preset.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2563EB),
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${preset.format.label} • ${preset.bitrate}k • ${preset.sampleRate}Hz',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormatOptionsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isLossless = _selectedFormat == AudioFormat.flac || _selectedFormat == AudioFormat.wav;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1E27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Target Format
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Format Container', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<AudioFormat>(
                      initialValue: _selectedFormat,
                      decoration: _inputDecoration(isDark),
                      items: AudioFormat.values.map((f) {
                        return DropdownMenuItem(value: f, child: Text(f.label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedFormat = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Bitrate
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bitrate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        if (!isLossless)
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isCustomBitrate = !_isCustomBitrate;
                              });
                            },
                            child: Text(
                              _isCustomBitrate ? 'Preset list' : 'Custom kbps',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (isLossless)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF13151B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        child: const Text('Lossless (Auto)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      )
                    else if (_isCustomBitrate)
                      TextField(
                        controller: _customBitrateController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(isDark).copyWith(
                          hintText: 'e.g. 224',
                          suffixText: 'kbps',
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        initialValue: [64, 96, 128, 160, 192, 224, 256, 320].contains(_bitrateKbps) ? _bitrateKbps : 192,
                        decoration: _inputDecoration(isDark),
                        items: const [
                          DropdownMenuItem(value: 64, child: Text('64 kbps (Voice)')),
                          DropdownMenuItem(value: 96, child: Text('96 kbps')),
                          DropdownMenuItem(value: 128, child: Text('128 kbps (Standard)')),
                          DropdownMenuItem(value: 160, child: Text('160 kbps')),
                          DropdownMenuItem(value: 192, child: Text('192 kbps (High Quality)')),
                          DropdownMenuItem(value: 224, child: Text('224 kbps')),
                          DropdownMenuItem(value: 256, child: Text('256 kbps (Studio)')),
                          DropdownMenuItem(value: 320, child: Text('320 kbps (Maximum)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _bitrateKbps = val);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Sample Rate
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sample Rate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: [0, 8000, 11025, 16000, 22050, 24000, 32000, 44100, 48000, 88200, 96000, 192000].contains(_sampleRateHz)
                          ? _sampleRateHz
                          : 44100,
                      decoration: _inputDecoration(isDark),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Original Source Rate')),
                        DropdownMenuItem(value: 8000, child: Text('8,000 Hz')),
                        DropdownMenuItem(value: 11025, child: Text('11,025 Hz')),
                        DropdownMenuItem(value: 16000, child: Text('16,000 Hz (Speech)')),
                        DropdownMenuItem(value: 22050, child: Text('22,050 Hz')),
                        DropdownMenuItem(value: 24000, child: Text('24,000 Hz')),
                        DropdownMenuItem(value: 32000, child: Text('32,000 Hz')),
                        DropdownMenuItem(value: 44100, child: Text('44,100 Hz (CD)')),
                        DropdownMenuItem(value: 48000, child: Text('48,000 Hz (Studio Pro)')),
                        DropdownMenuItem(value: 88200, child: Text('88,200 Hz')),
                        DropdownMenuItem(value: 96000, child: Text('96,000 Hz (Hi-Res)')),
                        DropdownMenuItem(value: 192000, child: Text('192,000 Hz (Ultra Hi-Res)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _sampleRateHz = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Channels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Audio Channels', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ChannelMode>(
                      initialValue: _channelMode,
                      decoration: _inputDecoration(isDark),
                      items: [
                        const DropdownMenuItem(value: ChannelMode.keepOriginal, child: Text('Original Channel Layout (Auto)')),
                        const DropdownMenuItem(value: ChannelMode.mono, child: Text('Mono (1 ch)')),
                        const DropdownMenuItem(value: ChannelMode.stereo, child: Text('Stereo (2 ch)')),
                        if (_selectedFormat != AudioFormat.mp3) ...[
                          const DropdownMenuItem(value: ChannelMode.surround2_1, child: Text('2.1 Surround (3 ch)')),
                          const DropdownMenuItem(value: ChannelMode.quad, child: Text('4.0 Quadraphonic (4 ch)')),
                          const DropdownMenuItem(value: ChannelMode.surround5_1, child: Text('5.1 Surround (6 ch)')),
                          const DropdownMenuItem(value: ChannelMode.surround7_1, child: Text('7.1 Surround (8 ch)')),
                        ],
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _channelMode = val);
                      },
                    ),
                    if (_selectedFormat == AudioFormat.mp3 && currentMedia != null && (currentMedia.primaryAudioTrack?.channels ?? 2) > 2 && _channelMode == ChannelMode.keepOriginal) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Note: Source is multichannel. MP3 standard downmixes to clean Stereo (2.0).',
                        style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioFiltersCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1E27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          // Volume & Normalization
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Volume Adjustment (-24 dB to +24 dB)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Text(
                              '${_volumeGainDb > 0 ? "+" : ""}${_volumeGainDb.toStringAsFixed(1)} dB',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _volumeGainDb = 0.0;
                                  _volumeTextController.text = '0.0';
                                });
                              },
                              child: const Text('Reset', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Slider(
                      value: _volumeGainDb,
                      min: -24.0,
                      max: 24.0,
                      divisions: 48,
                      label: '${_volumeGainDb.toStringAsFixed(1)} dB',
                      activeColor: const Color(0xFF2563EB),
                      onChanged: (val) {
                        setState(() {
                          _volumeGainDb = val;
                          _volumeTextController.text = val.toStringAsFixed(1);
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('EBU R128 Normalization', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Auto-normalize broadcast loudness (-16 LUFS)', style: TextStyle(fontSize: 11)),
                  value: _normalizeLoudness,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (val) => setState(() => _normalizeLoudness = val ?? false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Fades & Silence Trimming
          Row(
            children: [
              // Fade In
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fade In (seconds)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<double>(
                      initialValue: _fadeInSec,
                      decoration: _inputDecoration(isDark),
                      items: const [
                        DropdownMenuItem(value: 0.0, child: Text('Disabled')),
                        DropdownMenuItem(value: 1.0, child: Text('1.0 second')),
                        DropdownMenuItem(value: 2.0, child: Text('2.0 seconds')),
                        DropdownMenuItem(value: 3.0, child: Text('3.0 seconds')),
                        DropdownMenuItem(value: 5.0, child: Text('5.0 seconds')),
                      ],
                      onChanged: (val) => setState(() => _fadeInSec = val ?? 0.0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Fade Out
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fade Out (seconds)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<double>(
                      initialValue: _fadeOutSec,
                      decoration: _inputDecoration(isDark),
                      items: const [
                        DropdownMenuItem(value: 0.0, child: Text('Disabled')),
                        DropdownMenuItem(value: 1.0, child: Text('1.0 second')),
                        DropdownMenuItem(value: 2.0, child: Text('2.0 seconds')),
                        DropdownMenuItem(value: 3.0, child: Text('3.0 seconds')),
                        DropdownMenuItem(value: 5.0, child: Text('5.0 seconds')),
                      ],
                      onChanged: (val) => setState(() => _fadeOutSec = val ?? 0.0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Silence Trimming Mode
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _trimSilence,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (val) => setState(() => _trimSilence = val ?? false),
                        ),
                        const Text('Silence Removal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (_trimSilence)
                      DropdownButtonFormField<SilenceTrimMode>(
                        initialValue: _silenceTrimMode,
                        decoration: _inputDecoration(isDark),
                        items: const [
                          DropdownMenuItem(value: SilenceTrimMode.leadingAndTrailing, child: Text('Lead & Trailing Dead Air')),
                          DropdownMenuItem(value: SilenceTrimMode.leadingOnly, child: Text('Leading Silence Only')),
                          DropdownMenuItem(value: SilenceTrimMode.trailingOnly, child: Text('Trailing Silence Only')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _silenceTrimMode = val);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataAccordion(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1E27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Audio Tags, Track Info & Album Artwork',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              _stripMetadata ? 'Metadata will be stripped' : 'Customize ID3v2, Vorbis & container tags',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Icon(
              _metadataAccordionExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                _metadataAccordionExpanded = !_metadataAccordionExpanded;
              });
            },
          ),
          if (_metadataAccordionExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _stripMetadata,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (val) => setState(() => _stripMetadata = val ?? false),
                      ),
                      const Text('Strip all existing metadata (-map_metadata -1)', style: TextStyle(fontSize: 12)),
                      const Spacer(),
                      Checkbox(
                        value: _preserveMetadata,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (val) => setState(() => _preserveMetadata = val ?? true),
                      ),
                      const Text('Preserve original stream tags by default', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          decoration: _inputDecoration(isDark).copyWith(labelText: 'Title'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _artistController,
                          decoration: _inputDecoration(isDark).copyWith(labelText: 'Artist'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _albumController,
                          decoration: _inputDecoration(isDark).copyWith(labelText: 'Album'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _albumArtistController,
                          decoration: _inputDecoration(isDark).copyWith(labelText: 'Album Artist'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _genreController,
                          decoration: _inputDecoration(isDark).copyWith(labelText: 'Genre'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _yearController,
                          decoration: _inputDecoration(isDark).copyWith(labelText: 'Year / Date'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _trackNumberController,
                          decoration: _inputDecoration(isDark).copyWith(labelText: 'Track #'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _composerController,
                          decoration: _inputDecoration(isDark).copyWith(labelText: 'Composer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _copyrightController,
                          decoration: _inputDecoration(isDark).copyWith(labelText: 'Copyright'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _languageController,
                          decoration: _inputDecoration(isDark).copyWith(labelText: 'Language (e.g. eng, tam)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickArtwork,
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: Text(_artworkPath != null ? 'Change Artwork' : 'Attach Album Artwork'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFF2563EB),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_artworkPath != null) ...[
                        Expanded(
                          child: Text(
                            p.basename(_artworkPath!),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _artworkPath = null),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDestinationCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1E27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Output Base Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _fileNameController,
                      decoration: _inputDecoration(isDark).copyWith(
                        hintText: 'Enter output file name',
                        suffixText: '.${_selectedFormat.extension}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Destination Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<DestinationMode>(
                      initialValue: _destinationMode,
                      decoration: _inputDecoration(isDark),
                      items: [
                        DropdownMenuItem(
                          value: DestinationMode.configuredDirectory,
                          child: Text('Default Folder (${p.basename(_configuredOutputDirectory)})'),
                        ),
                        const DropdownMenuItem(
                          value: DestinationMode.besideOriginalFile,
                          child: Text('Save beside original source file'),
                        ),
                        DropdownMenuItem(
                          value: DestinationMode.customFolder,
                          child: Text(_customOutputDirectory.isNotEmpty
                              ? 'Custom: ${p.basename(_customOutputDirectory)}'
                              : 'Select Custom Folder...'),
                        ),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          if (val == DestinationMode.customFolder && _customOutputDirectory.isEmpty) {
                            await _pickCustomOutputDirectory();
                          } else {
                            setState(() => _destinationMode = val);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: isDark ? const Color(0xFF13151B) : const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}
