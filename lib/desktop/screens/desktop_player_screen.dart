import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import '../../services/database_service.dart';

class DesktopPlayerScreen extends StatefulWidget {
  final String? initialFilePath;

  const DesktopPlayerScreen({super.key, this.initialFilePath});

  @override
  State<DesktopPlayerScreen> createState() => _DesktopPlayerScreenState();
}

class _DesktopPlayerScreenState extends State<DesktopPlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  final DatabaseService _db = DatabaseService();

  String? _currentPath;
  String _currentTitle = 'No Track Loaded';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  List<String> _recentConversions = [];

  @override
  void initState() {
    super.initState();
    _loadRecentAudio();
    if (widget.initialFilePath != null) {
      _loadTrack(widget.initialFilePath!);
    }

    _player.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });

    _player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });

    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadRecentAudio() async {
    final jobs = await _db.getAllJobs();
    final audioPaths = <String>[];
    for (final j in jobs) {
      if (j.finalOutputPath.isNotEmpty && await File(j.finalOutputPath).exists()) {
        audioPaths.add(j.finalOutputPath);
      }
    }
    if (mounted) {
      setState(() => _recentConversions = audioPaths);
    }
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'aac', 'm4a', 'wav', 'flac', 'ogg', 'opus'],
    );
    if (result.isNotEmpty) {
      final path = result.first.path;
      if (path != null) _loadTrack(path);
    }
  }

  Future<void> _loadTrack(String path) async {
    try {
      await _player.setFilePath(path);
      if (mounted) {
        setState(() {
          _currentPath = path;
          _currentTitle = p.basename(path);
          _position = Duration.zero;
        });
      }
      await _player.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load audio: $e')),
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _seekRelative(int seconds) async {
    final maxMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1000;
    final newMs = (_position.inMilliseconds + seconds * 1000).clamp(0, maxMs);
    await _player.seek(Duration(milliseconds: newMs));
  }

  Future<void> _setSpeed(double speed) async {
    await _player.setSpeed(speed);
    setState(() => _playbackSpeed = speed);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _revealInExplorer(String path) {
    if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', path]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13151B) : const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Main Player Panel
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Studio Player',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'High-resolution desktop audio monitor and playback',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickAudioFile,
                        icon: const Icon(Icons.file_upload_outlined),
                        label: const Text('Open Audio (Ctrl + O)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Player Hero Card
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1E27) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Vinyl / Waveform visualizer circle
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isPlaying
                                    ? [const Color(0xFF2563EB), const Color(0xFF06B6D4)]
                                    : [Colors.grey[700]!, Colors.grey[800]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isPlaying ? const Color(0xFF2563EB) : Colors.black)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            _currentTitle,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          if (_currentPath != null)
                            InkWell(
                              onTap: () => _revealInExplorer(_currentPath!),
                              child: const Text(
                                'Show in File Explorer',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2563EB),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          const SizedBox(height: 28),

                          // Seek Slider
                          Slider(
                            value: _position.inMilliseconds
                                .clamp(0, _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1000)
                                .toDouble(),
                            min: 0,
                            max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1000,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (val) {
                              _player.seek(Duration(milliseconds: val.round()));
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(_position), style: const TextStyle(fontSize: 12)),
                                Text(_formatDuration(_duration), style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Playback Controls Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.replay_10_rounded),
                                iconSize: 32,
                                tooltip: 'Back 10s',
                                onPressed: _currentPath != null ? () => _seekRelative(-10) : null,
                              ),
                              const SizedBox(width: 16),
                              FloatingActionButton.large(
                                onPressed: _currentPath != null ? _togglePlayPause : null,
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 3,
                                child: Icon(
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 44,
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.forward_10_rounded),
                                iconSize: 32,
                                tooltip: 'Forward 10s',
                                onPressed: _currentPath != null ? () => _seekRelative(10) : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Playback Speed Chips
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Speed: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                                final isSelected = _playbackSpeed == s;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: ChoiceChip(
                                    label: Text('${s}x', style: const TextStyle(fontSize: 11)),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                    onSelected: (_) => _setSpeed(s),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),

            // Right Playlist / Recents Panel
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1E27) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                          'Recent Exports',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          onPressed: _loadRecentAudio,
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _recentConversions.isEmpty
                          ? Center(
                              child: Text(
                                'No recent converted audio found',
                                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _recentConversions.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final filePath = _recentConversions[index];
                                final name = p.basename(filePath);
                                final isCurrent = _currentPath == filePath;

                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    isCurrent && _isPlaying
                                        ? Icons.equalizer_rounded
                                        : Icons.audiotrack_rounded,
                                    color: isCurrent ? const Color(0xFF2563EB) : null,
                                  ),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                      color: isCurrent ? const Color(0xFF2563EB) : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.play_circle_outline_rounded, size: 22),
                                    onPressed: () => _loadTrack(filePath),
                                  ),
                                  onTap: () => _loadTrack(filePath),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
