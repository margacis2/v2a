import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import '../models/conversion_config.dart';
import '../services/conversion_engine.dart';
import '../services/feedback_service.dart';
import '../services/output_manager.dart';
import '../utils/app_transitions.dart';
import 'audio_player_screen.dart';

class StandaloneTrimmerScreen extends StatefulWidget {
  final String? initialAudioPath;

  const StandaloneTrimmerScreen({super.key, this.initialAudioPath});

  @override
  State<StandaloneTrimmerScreen> createState() => _StandaloneTrimmerScreenState();
}

class _StandaloneTrimmerScreenState extends State<StandaloneTrimmerScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _audioPath;
  String _fileName = '';
  int _totalDurationMs = 1;
  int _startMs = 0;
  int _endMs = 1;

  bool _isLoadingFile = false;
  bool _isGeneratingWaveform = false;
  List<double> _waveformPeaks = [];
  bool _loopRegion = false;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  String? _validationError;

  bool _isExporting = false;
  double _exportProgress = 0.0;

  @override
  void initState() {
    super.initState();

    _player.positionStream.listen((pos) {
      if (mounted) {
        setState(() {});
        // If playing selected region and reached end
        if (_player.playing && pos.inMilliseconds >= _endMs) {
          if (_loopRegion) {
            _player.seek(Duration(milliseconds: _startMs));
          } else {
            _player.pause();
            _player.seek(Duration(milliseconds: _startMs));
          }
        }
      }
    });

    _player.playerStateStream.listen((state) {
      if (mounted) setState(() {});
    });

    if (widget.initialAudioPath != null && widget.initialAudioPath!.isNotEmpty) {
      _loadAudio(widget.initialAudioPath!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickAudioFile();
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    try {
      final single = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'aac', 'm4a', 'wav', 'flac', 'ogg', 'opus'],
      );

      if (single != null && single.path != null) {
        await _loadAudio(single.path!);
      } else if (_audioPath == null && mounted) {
        // User cancelled without picking a file initially
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e')),
        );
      }
    }
  }

  Future<void> _loadAudio(String path) async {
    setState(() {
      _isLoadingFile = true;
      _audioPath = path;
      _fileName = p.basename(path);
      _waveformPeaks = [];
    });

    try {
      await _player.setFilePath(path);
      final duration = _player.duration ?? const Duration(seconds: 1);
      final durMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 1000;

      setState(() {
        _totalDurationMs = durMs;
        _startMs = 0;
        _endMs = durMs;
        _syncControllers();
        _isLoadingFile = false;
        _isGeneratingWaveform = true;
      });

      // Generate genuine waveform peaks via FFmpeg
      final peaks = await ConversionEngine().extractWaveformPeaks(path, targetSampleCount: 100);
      if (mounted) {
        setState(() {
          _waveformPeaks = peaks;
          _isGeneratingWaveform = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFile = false;
          _isGeneratingWaveform = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audio: $e')),
        );
      }
    }
  }

  void _syncControllers() {
    _startController.text = _formatMsToTimestamp(_startMs);
    _endController.text = _formatMsToTimestamp(_endMs);
  }

  String _formatMsToTimestamp(int ms) {
    final d = Duration(milliseconds: ms);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final millis = d.inMilliseconds.remainder(1000);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
  }

  int? _parseTimestampToMs(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    final parts = clean.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final secParts = parts[2].split('.');
      final s = int.tryParse(secParts[0]) ?? 0;
      final ms = secParts.length > 1 ? (int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0) : 0;
      return (h * 3600000) + (m * 60000) + (s * 1000) + ms;
    } else if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final secParts = parts[1].split('.');
      final s = int.tryParse(secParts[0]) ?? 0;
      final ms = secParts.length > 1 ? (int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0) : 0;
      return (m * 60000) + (s * 1000) + ms;
    }
    return null;
  }

  void _adjustTime({required bool isStart, required int deltaMs}) {
    setState(() {
      _validationError = null;
      if (isStart) {
        _startMs = (_startMs + deltaMs).clamp(0, _endMs - 100);
      } else {
        _endMs = (_endMs + deltaMs).clamp(_startMs + 100, _totalDurationMs);
      }
      _syncControllers();
    });
  }

  void _onManualTimestampChanged() {
    final s = _parseTimestampToMs(_startController.text);
    final e = _parseTimestampToMs(_endController.text);

    if (s == null || e == null) {
      setState(() => _validationError = 'Invalid timestamp format (use MM:SS.mmm)');
      return;
    }

    if (s < 0 || e > _totalDurationMs || s >= e) {
      setState(() => _validationError = 'Start must be before End and within total duration');
      return;
    }

    setState(() {
      _validationError = null;
      _startMs = s;
      _endMs = e;
    });
  }

  void _playPauseToggle() {
    if (_player.playing) {
      _player.pause();
    } else {
      // If position is outside trim range, jump to start
      final pos = _player.position.inMilliseconds;
      if (pos < _startMs || pos >= _endMs) {
        _player.seek(Duration(milliseconds: _startMs));
      }
      _player.play();
    }
  }

  void _playSelectedRegion() {
    _player.seek(Duration(milliseconds: _startMs));
    _player.play();
  }

  // Export Dialog & Processing
  Future<void> _exportTrimmedAudio() async {
    if (_audioPath == null || _validationError != null) return;

    final outputDirObj = await OutputManager().getActiveOutputDirectory();
    final outputDir = outputDirObj.path;
    final defaultBaseName = '${p.basenameWithoutExtension(_fileName)}_trimmed';
    final nameController = TextEditingController(text: defaultBaseName);

    // Default to format matching input or MP3
    final ext = p.extension(_fileName).replaceAll('.', '').toLowerCase();
    AudioFormat selectedFormat = AudioFormat.values.firstWhere(
      (f) => f.extension == ext,
      orElse: () => AudioFormat.mp3,
    );

    if (!mounted) return;

    final shouldExport = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Export Trimmed Audio'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'File Name',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Output Format:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: AudioFormat.values.map((f) {
                        final isSel = selectedFormat == f;
                        return ChoiceChip(
                          label: Text(f.extension.toUpperCase()),
                          selected: isSel,
                          visualDensity: VisualDensity.compact,
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() => selectedFormat = f);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Duration: ${_formatMsToTimestamp(_endMs - _startMs)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text('Save Directory: $outputDir', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Trim & Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldExport != true) return;

    final baseName = nameController.text.trim().isNotEmpty ? nameController.text.trim() : defaultBaseName;

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    final result = await ConversionEngine().trimAudioFile(
      sourcePath: _audioPath!,
      outputDirectory: outputDir,
      baseName: baseName,
      format: selectedFormat,
      startMs: _startMs,
      endMs: _endMs,
      onProgress: (p) {
        if (mounted) setState(() => _exportProgress = p);
      },
    );

    if (!mounted) return;

    setState(() => _isExporting = false);

    if (result.success) {
      FeedbackService().notifyFileCreated(
        context,
        fileName: p.basename(result.outputPath),
        path: result.outputPath,
      );

      // Offer immediate playback or open
      showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                const SizedBox(height: 10),
                const Text('Trim Completed Successfully!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(p.basename(result.outputPath), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play Trimmed'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          AppTransitions.slideFadeRoute(AudioPlayerScreen(filePath: result.outputPath)),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Open Folder'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        OpenFilex.open(outputDir);
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trim failed: ${result.errorMessage}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentPosMs = _player.position.inMilliseconds;
    final segmentDurationMs = (_endMs - _startMs).clamp(0, _totalDurationMs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Trimmer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open_rounded),
            tooltip: 'Open Another Audio File',
            onPressed: _isExporting ? null : _pickAudioFile,
          ),
        ],
      ),
      body: _isLoadingFile
          ? const Center(child: CircularProgressIndicator())
          : _audioPath == null
              ? Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.audio_file_rounded),
                    label: const Text('Select Audio File'),
                    onPressed: _pickAudioFile,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // File Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.audiotrack_rounded, color: theme.colorScheme.primary, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _fileName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Duration: ${_formatMsToTimestamp(_totalDurationMs)}',
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Waveform Visualizer & Timeline Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.graphic_eq_rounded, color: theme.colorScheme.primary, size: 18),
                                      const SizedBox(width: 6),
                                      const Text('Waveform & Selection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  if (_isGeneratingWaveform)
                                    const Row(
                                      children: [
                                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                        SizedBox(width: 6),
                                        Text('Analyzing...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Interactive Waveform Box
                              Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E222A) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: theme.dividerColor),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return GestureDetector(
                                      onTapDown: (details) {
                                        final ratio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                                        final targetMs = (ratio * _totalDurationMs).round();
                                        _player.seek(Duration(milliseconds: targetMs));
                                      },
                                      child: CustomPaint(
                                        size: Size(constraints.maxWidth, 80),
                                        painter: _WaveformPainter(
                                          peaks: _waveformPeaks,
                                          totalDurationMs: _totalDurationMs,
                                          startMs: _startMs,
                                          endMs: _endMs,
                                          currentPositionMs: currentPosMs,
                                          primaryColor: theme.colorScheme.primary,
                                          isDark: isDark,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Timeline Range Slider for Start and End Boundaries
                              RangeSlider(
                                values: RangeValues(
                                  _startMs.toDouble().clamp(0.0, _totalDurationMs.toDouble()),
                                  _endMs.toDouble().clamp(_startMs.toDouble(), _totalDurationMs.toDouble()),
                                ),
                                min: 0.0,
                                max: _totalDurationMs.toDouble(),
                                onChanged: (RangeValues values) {
                                  setState(() {
                                    _validationError = null;
                                    _startMs = values.start.round();
                                    _endMs = values.end.round();
                                    _syncControllers();
                                  });
                                },
                              ),

                              // Segment Duration Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Trimmed Segment:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    Text(
                                      _formatMsToTimestamp(segmentDurationMs),
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Real Audio Player Controls
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatMsToTimestamp(currentPosMs),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    _formatMsToTimestamp(_totalDurationMs),
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  ),
                                ],
                              ),
                              Slider(
                                value: currentPosMs.toDouble().clamp(0.0, _totalDurationMs.toDouble()),
                                min: 0.0,
                                max: _totalDurationMs.toDouble(),
                                onChanged: (val) {
                                  _player.seek(Duration(milliseconds: val.round()));
                                },
                              ),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 14,
                                runSpacing: 8,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.replay_5_rounded),
                                    tooltip: '-5s',
                                    onPressed: () {
                                      final target = (currentPosMs - 5000).clamp(0, _totalDurationMs);
                                      _player.seek(Duration(milliseconds: target));
                                    },
                                  ),
                                  FloatingActionButton.small(
                                    elevation: 2,
                                    onPressed: _playPauseToggle,
                                    child: Icon(_player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.forward_5_rounded),
                                    tooltip: '+5s',
                                    onPressed: () {
                                      final target = (currentPosMs + 5000).clamp(0, _totalDurationMs);
                                      _player.seek(Duration(milliseconds: target));
                                    },
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    ),
                                    icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                                    label: const Text('Play Range', style: TextStyle(fontSize: 11)),
                                    onPressed: _playSelectedRegion,
                                  ),
                                  FilterChip(
                                    label: const Text('Loop Range', style: TextStyle(fontSize: 11)),
                                    selected: _loopRegion,
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (val) {
                                      setState(() => _loopRegion = val);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Manual Timestamps & Quick Minute Jump Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Timestamp Fine-Tuning', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _startController,
                                      decoration: const InputDecoration(labelText: 'Start Time', isDense: true),
                                      onChanged: (_) => _onManualTimestampChanged(),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: TextField(
                                      controller: _endController,
                                      decoration: const InputDecoration(labelText: 'End Time', isDense: true),
                                      onChanged: (_) => _onManualTimestampChanged(),
                                    ),
                                  ),
                                ],
                              ),
                              if (_validationError != null) ...[
                                const SizedBox(height: 6),
                                Text(_validationError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                              ],
                              const SizedBox(height: 14),
                              const Text('Quick Boundary Adjustments:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _quickChip('Start -1s', () => _adjustTime(isStart: true, deltaMs: -1000)),
                                  _quickChip('Start +1s', () => _adjustTime(isStart: true, deltaMs: 1000)),
                                  _quickChip('Start -1m', () => _adjustTime(isStart: true, deltaMs: -60000)),
                                  _quickChip('Start +1m', () => _adjustTime(isStart: true, deltaMs: 60000)),
                                  _quickChip('End -1m', () => _adjustTime(isStart: false, deltaMs: -60000)),
                                  _quickChip('End +1m', () => _adjustTime(isStart: false, deltaMs: 60000)),
                                  _quickChip('End -1s', () => _adjustTime(isStart: false, deltaMs: -1000)),
                                  _quickChip('End +1s', () => _adjustTime(isStart: false, deltaMs: 1000)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Export Progress indicator if running
                      if (_isExporting) ...[
                        Column(
                          children: [
                            LinearProgressIndicator(value: _exportProgress > 0 ? _exportProgress : null),
                            const SizedBox(height: 8),
                            Text('Exporting trimmed audio (${(_exportProgress * 100).toStringAsFixed(0)}%)...',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Big Trim & Save Action Button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isExporting || _validationError != null ? null : _exportTrimmedAudio,
                          icon: const Icon(Icons.content_cut_rounded),
                          label: const Text('Trim & Save Audio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return ActionChip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: onTap,
    );
  }
}

/// Custom painter for authentic audio waveform with region highlighting and playback needle
class _WaveformPainter extends CustomPainter {
  final List<double> peaks;
  final int totalDurationMs;
  final int startMs;
  final int endMs;
  final int currentPositionMs;
  final Color primaryColor;
  final bool isDark;

  _WaveformPainter({
    required this.peaks,
    required this.totalDurationMs,
    required this.startMs,
    required this.endMs,
    required this.currentPositionMs,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) {
      final centerPaint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.3)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), centerPaint);
      return;
    }

    final totalMs = totalDurationMs > 0 ? totalDurationMs : 1;
    final startX = (startMs / totalMs) * size.width;
    final endX = (endMs / totalMs) * size.width;
    final playX = (currentPositionMs / totalMs) * size.width;

    // Highlighted selected region background
    final regionPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(startX, 0, endX, size.height), regionPaint);

    // Region boundary lines
    final boundaryPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), boundaryPaint);
    canvas.drawLine(Offset(endX, 0), Offset(endX, size.height), boundaryPaint);

    // Draw waveform vertical bars
    final barCount = peaks.length;
    final barWidth = size.width / barCount;
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final x = (i + 0.5) * barWidth;
      final peakHeight = peaks[i] * (size.height * 0.42);
      final isInsideRegion = x >= startX && x <= endX;

      final barPaint = Paint()
        ..color = isInsideRegion
            ? primaryColor
            : (isDark ? Colors.grey[700]! : Colors.grey[400]!)
        ..strokeWidth = (barWidth * 0.7).clamp(1.5, 4.0)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x, centerY - peakHeight), Offset(x, centerY + peakHeight), barPaint);
    }

    // Playback needle indicator
    final needlePaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(playX, 0), Offset(playX, size.height), needlePaint);

    final needleHeadPaint = Paint()..color = Colors.redAccent;
    canvas.drawCircle(Offset(playX, 4), 3.5, needleHeadPaint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.currentPositionMs != currentPositionMs ||
        oldDelegate.startMs != startMs ||
        oldDelegate.endMs != endMs ||
        oldDelegate.peaks != peaks;
  }
}
