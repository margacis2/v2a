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

  String? _selectedFilePath;
  MediaFile? _inspectedMedia;
  bool _isProbing = false;

  // Conversion Settings
  ConversionPreset _selectedPreset = ConversionPreset.balanced;
  AudioFormat _selectedFormat = AudioFormat.mp3;
  ConversionMode _selectedMode = ConversionMode.reEncode;
  int _selectedAudioTrackIndex = 0;

  int _bitrateKbps = 192;
  int _sampleRateHz = 44100;
  ChannelMode _channelMode = ChannelMode.stereo;
  bool _vbrEnabled = false;
  final int _vbrQuality = 2;

  double _volumeGainDb = 0.0;
  bool _normalizeLoudness = false;
  bool _trimSilence = false;
  final double _fadeInSec = 0.0;
  final double _fadeOutSec = 0.0;

  final TextEditingController _fileNameController = TextEditingController();
  String _outputDirectory = '';

  @override
  void initState() {
    super.initState();
    _loadDefaultDirectory();
    if (widget.initialFilePath != null) {
      _loadFile(widget.initialFilePath!);
    }
  }

  @override
  void didUpdateWidget(DesktopConvertScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilePath != null && widget.initialFilePath != oldWidget.initialFilePath) {
      _loadFile(widget.initialFilePath!);
    }
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultDirectory() async {
    final dir = await _outputManager.getActiveOutputDirectory();
    if (mounted) {
      setState(() {
        _outputDirectory = dir.path;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4', 'mkv', 'mov', 'avi', 'flv', 'wmv', 'webm', '3gp', 'm4v', 'ts', 'mts',
        'mp3', 'aac', 'm4a', 'wav', 'flac', 'ogg', 'opus',
      ],
    );

    if (result.isNotEmpty) {
      final path = result.first.path;
      if (path != null) {
        _loadFile(path);
      }
    }
  }

  Future<void> _loadFile(String path) async {
    setState(() {
      _selectedFilePath = path;
      _isProbing = true;
      _inspectedMedia = null;
    });

    final inspected = await _engine.inspectMedia(path);
    final baseName = p.basenameWithoutExtension(path);

    if (mounted) {
      setState(() {
        _inspectedMedia = inspected;
        _isProbing = false;
        _fileNameController.text = baseName;
        _selectedAudioTrackIndex = inspected.audioTracks.isNotEmpty
            ? inspected.audioTracks.first.index
            : 0;
      });
    }
  }

  void _applyPreset(ConversionPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _selectedFormat = preset.format;
      _bitrateKbps = preset.bitrate;
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

  Future<void> _pickOutputDirectory() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Destination Folder for Converted Audio',
      initialDirectory: _outputDirectory.isNotEmpty ? _outputDirectory : null,
    );
    if (path != null && mounted) {
      setState(() {
        _outputDirectory = path;
      });
      await _outputManager.setCustomOutputDirectory(path);
    }
  }

  Future<void> _enqueueConversion({bool startImmediately = true}) async {
    if (_selectedFilePath == null || _inspectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a media file first')),
      );
      return;
    }

    if (_outputDirectory.isEmpty) {
      final defaultDir = await _outputManager.getActiveOutputDirectory();
      _outputDirectory = defaultDir.path;
    }

    final requestedName = _fileNameController.text.trim().isNotEmpty
        ? _fileNameController.text.trim()
        : p.basenameWithoutExtension(_selectedFilePath!);

    final selectedCodec = _inspectedMedia!.audioTracks.isNotEmpty
        ? _inspectedMedia!.audioTracks.firstWhere(
            (t) => t.index == _selectedAudioTrackIndex,
            orElse: () => _inspectedMedia!.audioTracks.first,
          ).codec
        : '';

    final job = ConversionJob(
      id: 'job_${DateTime.now().millisecondsSinceEpoch}',
      sourcePath: _selectedFilePath!,
      sourceFileName: _inspectedMedia!.fileName,
      sourceSizeBytes: _inspectedMedia!.sizeBytes,
      sourceDurationMs: _inspectedMedia!.duration.inMilliseconds,
      requestedFileName: requestedName,
      outputDirectory: _outputDirectory,
      format: _selectedFormat,
      mode: _selectedMode,
      preset: _selectedPreset,
      selectedAudioCodec: selectedCodec,
      selectedAudioTrackIndex: _selectedAudioTrackIndex,
      bitrateKbps: _bitrateKbps,
      sampleRateHz: _sampleRateHz,
      channelMode: _channelMode,
      vbrEnabled: _vbrEnabled,
      vbrQuality: _vbrQuality,
      volumeGainDb: _volumeGainDb,
      normalizeLoudness: _normalizeLoudness,
      trimSilence: _trimSilence,
      fadeInSec: _fadeInSec,
      fadeOutSec: _fadeOutSec,
    );

    if (!mounted) return;
    final queue = Provider.of<JobQueueService>(context, listen: false);
    await queue.enqueueJob(job);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${job.requestedFileName}.${job.format.extension}" to conversion queue'),
          action: SnackBarAction(
            label: 'View Queue',
            onPressed: () => widget.onNavigate(2),
          ),
        ),
      );
      widget.onNavigate(2); // Jump to Queue screen
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                      'Extract and transcode high-fidelity audio streams',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Change File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Source File Card
            if (_selectedFilePath == null)
              _buildEmptyFilePrompt(context)
            else if (_isProbing)
              _buildProbingCard(context)
            else if (_inspectedMedia != null)
              _buildMediaInfoCard(context, _inspectedMedia!),

            const SizedBox(height: 28),

            // Conversion Presets Grid (8 Presets)
            Text(
              'Conversion Presets',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPresetGrid(context),

            const SizedBox(height: 28),

            // Format & Quality Controls
            Text(
              'Output Parameters',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildFormatOptionsCard(context),

            const SizedBox(height: 28),

            // Audio Filters Pipeline
            Text(
              'Audio Filters & Processing',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildAudioFiltersCard(context),

            const SizedBox(height: 28),

            // Output Filename & Destination Card
            Text(
              'Output Destination',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDestinationCard(context),

            const SizedBox(height: 36),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedFilePath != null ? () => _enqueueConversion(startImmediately: false) : null,
                    icon: const Icon(Icons.playlist_add_rounded),
                    label: const Text('Add to Queue'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _selectedFilePath != null ? () => _enqueueConversion(startImmediately: true) : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Convert Now (Ctrl + Enter)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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

  Widget _buildEmptyFilePrompt(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
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
            Icon(Icons.video_file_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'No Media File Selected',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick a video or audio file to start customizing export settings',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Select File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
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
            'Probing container metadata with FFprobe...',
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  file.videoCodec != null ? Icons.videocam_rounded : Icons.audiotrack_rounded,
                  color: const Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${file.formattedDuration} • ${(file.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB • ${file.extension.toUpperCase()}',
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
          if (file.audioTracks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Audio Stream: ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isDense: true,
                      value: _selectedAudioTrackIndex,
                      items: file.audioTracks.map((t) {
                        return DropdownMenuItem<int>(
                          value: t.index,
                          child: Text(
                            'Track ${t.index + 1}: ${t.codec.toUpperCase()} • ${t.channels} ch • ${t.sampleRate} Hz ${t.language != null ? "(${t.language})" : ""}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedAudioTrackIndex = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
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
                    const Text('Bitrate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: [64, 96, 128, 160, 192, 256, 320].contains(_bitrateKbps) ? _bitrateKbps : 192,
                      decoration: _inputDecoration(isDark),
                      items: const [
                        DropdownMenuItem(value: 64, child: Text('64 kbps (Voice)')),
                        DropdownMenuItem(value: 96, child: Text('96 kbps')),
                        DropdownMenuItem(value: 128, child: Text('128 kbps (Standard)')),
                        DropdownMenuItem(value: 160, child: Text('160 kbps')),
                        DropdownMenuItem(value: 192, child: Text('192 kbps (High Quality)')),
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
                      initialValue: [16000, 24000, 44100, 48000].contains(_sampleRateHz) ? _sampleRateHz : 44100,
                      decoration: _inputDecoration(isDark),
                      items: const [
                        DropdownMenuItem(value: 16000, child: Text('16,000 Hz (Speech)')),
                        DropdownMenuItem(value: 24000, child: Text('24,000 Hz')),
                        DropdownMenuItem(value: 44100, child: Text('44,100 Hz (CD)')),
                        DropdownMenuItem(value: 48000, child: Text('48,000 Hz (Studio Pro)')),
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
                    const Text('Channels', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ChannelMode>(
                      initialValue: _channelMode,
                      decoration: _inputDecoration(isDark),
                      items: const [
                        DropdownMenuItem(value: ChannelMode.keepOriginal, child: Text('Original')),
                        DropdownMenuItem(value: ChannelMode.stereo, child: Text('Stereo (2 ch)')),
                        DropdownMenuItem(value: ChannelMode.mono, child: Text('Mono (1 ch)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _channelMode = val);
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
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Volume Gain', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('${_volumeGainDb > 0 ? "+" : ""}${_volumeGainDb.toStringAsFixed(1)} dB', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _volumeGainDb,
                      min: -12.0,
                      max: 12.0,
                      divisions: 24,
                      label: '${_volumeGainDb.toStringAsFixed(1)} dB',
                      activeColor: const Color(0xFF2563EB),
                      onChanged: (val) => setState(() => _volumeGainDb = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('EBU R128 Loudness', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Normalize volume across tracks', style: TextStyle(fontSize: 11)),
                  value: _normalizeLoudness,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (val) => setState(() => _normalizeLoudness = val ?? false),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Trim Silence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Remove lead/trailing dead air', style: TextStyle(fontSize: 11)),
                  value: _trimSilence,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (val) => setState(() => _trimSilence = val ?? false),
                ),
              ),
            ],
          ),
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
                    const Text('Output File Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                    const Text('Destination Folder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickOutputDirectory,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF13151B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_open_rounded, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _outputDirectory.isNotEmpty ? _outputDirectory : 'Choose folder...',
                                style: const TextStyle(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Text(
                              'Browse',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
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
