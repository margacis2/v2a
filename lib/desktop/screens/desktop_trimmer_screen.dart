import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import '../../models/conversion_config.dart';
import '../../services/desktop_media_engine.dart';
import '../../services/output_manager.dart';

class DesktopTrimmerScreen extends StatefulWidget {
  final String? initialFilePath;

  const DesktopTrimmerScreen({super.key, this.initialFilePath});

  @override
  State<DesktopTrimmerScreen> createState() => _DesktopTrimmerScreenState();
}

class _DesktopTrimmerScreenState extends State<DesktopTrimmerScreen> {
  final DesktopMediaEngine _engine = DesktopMediaEngine();
  final OutputManager _outputManager = OutputManager();
  final AudioPlayer _player = AudioPlayer();

  String? _filePath;
  String _fileName = '';
  int _totalDurationMs = 0;
  List<double> _peaks = [];
  bool _isLoading = false;
  bool _isExporting = false;

  int _startMs = 0;
  int _endMs = 0;
  bool _isPlaying = false;

  AudioFormat _exportFormat = AudioFormat.mp3;
  final double _volumeGainDb = 0.0;
  bool _normalizeLoudness = false;
  String _outputDir = '';

  @override
  void initState() {
    super.initState();
    _loadOutputDir();
    if (widget.initialFilePath != null) {
      _loadFile(widget.initialFilePath!);
    }

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _player.positionStream.listen((pos) {
      if (_isPlaying && pos.inMilliseconds >= _endMs && _endMs > _startMs) {
        _player.pause();
        _player.seek(Duration(milliseconds: _startMs));
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadOutputDir() async {
    final dir = await _outputManager.getActiveOutputDirectory();
    if (mounted) {
      setState(() => _outputDir = dir.path);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp3', 'aac', 'm4a', 'wav', 'flac', 'ogg', 'opus',
        'mp4', 'mkv', 'mov', 'webm', 'avi',
      ],
    );
    if (result.isNotEmpty) {
      final path = result.first.path;
      if (path != null) _loadFile(path);
    }
  }

  Future<void> _loadFile(String path) async {
    setState(() {
      _filePath = path;
      _fileName = p.basename(path);
      _isLoading = true;
      _peaks = [];
    });

    final inspected = await _engine.inspectMedia(path);
    final durMs = inspected.duration.inMilliseconds;
    final peaks = await _engine.extractWaveformPeaks(path, targetSampleCount: 160);

    try {
      await _player.setFilePath(path);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _totalDurationMs = durMs > 0 ? durMs : 60000;
        _startMs = 0;
        _endMs = _totalDurationMs;
        _peaks = peaks;
        _isLoading = false;
      });
    }
  }

  void _nudgeStart(int deltaMs) {
    setState(() {
      _startMs = (_startMs + deltaMs).clamp(0, _endMs - 500);
    });
  }

  void _nudgeEnd(int deltaMs) {
    setState(() {
      _endMs = (_endMs + deltaMs).clamp(_startMs + 500, _totalDurationMs);
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.seek(Duration(milliseconds: _startMs));
      await _player.play();
    }
  }

  String _formatTime(int ms) {
    final totalSec = ms ~/ 1000;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    final millis = (ms % 1000) ~/ 100;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.$millis';
  }

  Future<void> _exportTrimmed() async {
    if (_filePath == null) return;

    setState(() => _isExporting = true);

    final baseName = '${p.basenameWithoutExtension(_filePath!)}_trimmed';
    final result = await _engine.trimAudioFile(
      sourcePath: _filePath!,
      outputDirectory: _outputDir,
      baseName: baseName,
      format: _exportFormat,
      startMs: _startMs,
      endMs: _endMs,
      volumeGainDb: _volumeGainDb,
      normalizeLoudness: _normalizeLoudness,
    );

    if (mounted) {
      setState(() => _isExporting = false);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trimmed audio exported: ${p.basename(result.outputPath)}'),
            backgroundColor: const Color(0xFF10B981),
            action: SnackBarAction(
              label: 'Show in Explorer',
              textColor: Colors.white,
              onPressed: () {
                if (Platform.isWindows) {
                  Process.run('explorer.exe', ['/select,', result.outputPath]);
                } else if (Platform.isMacOS) {
                  Process.run('open', ['-R', result.outputPath]);
                }
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${result.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                      'Audio Trimmer',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Waveform-guided precision non-destructive audio trimming',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Open File (Ctrl + O)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_filePath == null)
              _buildEmptyPrompt(isDark)
            else if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              // Active Waveform Card
              Container(
                padding: const EdgeInsets.all(24),
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
                        Text(
                          _fileName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Selection: ${_formatTime(_endMs - _startMs)} / ${_formatTime(_totalDurationMs)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Waveform visualization bars
                    SizedBox(
                      height: 100,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(_peaks.length, (i) {
                          final barMs = (i / _peaks.length) * _totalDurationMs;
                          final isInside = barMs >= _startMs && barMs <= _endMs;
                          final height = (_peaks[i] * 90).clamp(6.0, 90.0);

                          return Expanded(
                            child: Center(
                              child: Container(
                                width: 3,
                                height: height,
                                decoration: BoxDecoration(
                                  color: isInside
                                      ? const Color(0xFF2563EB)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Range Slider
                    RangeSlider(
                      values: RangeValues(
                        _startMs.toDouble(),
                        _endMs.toDouble().clamp(_startMs.toDouble() + 500, _totalDurationMs.toDouble()),
                      ),
                      min: 0,
                      max: _totalDurationMs.toDouble() > 0 ? _totalDurationMs.toDouble() : 1000,
                      activeColor: const Color(0xFF2563EB),
                      onChanged: (values) {
                        setState(() {
                          _startMs = values.start.round();
                          _endMs = values.end.round();
                        });
                      },
                    ),

                    // Time display & Preview Play Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Start: ${_formatTime(_startMs)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          onPressed: _togglePlayback,
                          icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          label: Text(_isPlaying ? 'Pause Preview' : 'Play Selection (Space)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        Text('End: ${_formatTime(_endMs)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Precision Nudge Controls Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1E27) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    // Start nudges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nudge Start Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              _nudgeBtn('-1m', () => _nudgeStart(-60000)),
                              _nudgeBtn('-5s', () => _nudgeStart(-5000)),
                              _nudgeBtn('-1s', () => _nudgeStart(-1000)),
                              _nudgeBtn('+1s', () => _nudgeStart(1000)),
                              _nudgeBtn('+5s', () => _nudgeStart(5000)),
                              _nudgeBtn('+1m', () => _nudgeStart(60000)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // End nudges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nudge End Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              _nudgeBtn('-1m', () => _nudgeEnd(-60000)),
                              _nudgeBtn('-5s', () => _nudgeEnd(-5000)),
                              _nudgeBtn('-1s', () => _nudgeEnd(-1000)),
                              _nudgeBtn('+1s', () => _nudgeEnd(1000)),
                              _nudgeBtn('+5s', () => _nudgeEnd(5000)),
                              _nudgeBtn('+1m', () => _nudgeEnd(60000)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Export Options Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1E27) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Export Format', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<AudioFormat>(
                            initialValue: _exportFormat,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: isDark ? const Color(0xFF13151B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: AudioFormat.values.map((f) => DropdownMenuItem(value: f, child: Text(f.label))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _exportFormat = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('EBU R128 Loudness', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Normalize output level', style: TextStyle(fontSize: 11)),
                        value: _normalizeLoudness,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (val) => setState(() => _normalizeLoudness = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : _exportTrimmed,
                        icon: _isExporting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.download_rounded),
                        label: Text(_isExporting ? 'Exporting...' : 'Export Trimmed Audio'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nudgeBtn(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildEmptyPrompt(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
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
            Icon(Icons.content_cut_rounded, size: 52, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Audio or Video File Loaded',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Open an audio or video file to visualize the waveform and perform non-destructive trimming',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Open Media File'),
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
}
