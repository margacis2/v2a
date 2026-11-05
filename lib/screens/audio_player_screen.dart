import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../services/audio_player_service.dart';
import '../services/output_manager.dart';
import '../widgets/audio_visualizer_widget.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String filePath;

  const AudioPlayerScreen({super.key, required this.filePath});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final AudioPlayerService _audioService = AudioPlayerService();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  late String _currentPath;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.filePath;
    _setupListeners();
  }

  void _setupListeners() {
    _audioService.player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _audioService.player.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    _audioService.player.durationStream.listen((dur) {
      if (mounted && dur != null) {
        setState(() {
          _duration = dur;
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Playback Speed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
              final isCurrent = _audioService.playbackSpeed == speed;
              return ListTile(
                title: Text('${speed}x', style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                trailing: isCurrent ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  _audioService.setSpeed(speed);
                  Navigator.of(context).pop();
                  setState(() {});
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showFileProperties() async {
    final file = File(_currentPath);
    if (!await file.exists()) return;
    final size = await file.length();
    final ext = p.extension(_currentPath).toUpperCase().replaceAll('.', '');

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('File Properties'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _propRow('File Name', p.basename(_currentPath)),
              _propRow('Format', ext),
              _propRow('Duration', _formatDuration(_duration)),
              _propRow('File Size', '${(size / (1024 * 1024)).toStringAsFixed(2)} MB'),
              _propRow('Path', _currentPath, isPath: true),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _currentPath));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File path copied to clipboard')),
                );
              },
              child: const Text('Copy Path'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _propRow(String label, String value, {bool isPath = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isPath ? FontWeight.normal : FontWeight.w600)),
        ],
      ),
    );
  }

  void _showRenameDialog() {
    final oldBase = p.basenameWithoutExtension(_currentPath);
    final ext = p.extension(_currentPath);
    final controller = TextEditingController(text: oldBase);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Audio File'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'New File Name',
              suffixText: ext,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newBase = controller.text.trim();
                if (newBase.isEmpty) return;

                final dir = p.dirname(_currentPath);
                final uniqueName = await OutputManager().resolveUniqueFileName(
                  directoryPath: dir,
                  baseName: newBase,
                  extension: ext,
                );

                final oldFile = File(_currentPath);
                if (await oldFile.exists()) {
                  await _audioService.stop();
                  final newFile = await oldFile.rename(p.join(dir, uniqueName));
                  setState(() {
                    _currentPath = newFile.path;
                  });
                  await _audioService.playSingleFile(newFile.path);
                }

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Renamed safely to $uniqueName')),
                  );
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Audio File?'),
          content: Text(
            'Are you sure you want to permanently delete "${p.basename(_currentPath)}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                await _audioService.stop();
                final file = File(_currentPath);
                if (await file.exists()) {
                  await file.delete();
                }
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Exit player screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Audio file deleted.')),
                  );
                }
              },
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fileName = p.basename(_currentPath);
    final ext = p.extension(_currentPath).toUpperCase().replaceAll('.', '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share',
            onPressed: () {
              SharePlus.instance.share(ShareParams(files: [XFile(_currentPath)], text: fileName));
            },
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'open') OpenFilex.open(_currentPath);
              if (val == 'rename') _showRenameDialog();
              if (val == 'properties') _showFileProperties();
              if (val == 'delete') _showDeleteConfirmation();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'open', child: Text('Open in external player')),
              PopupMenuItem(value: 'rename', child: Text('Rename file')),
              PopupMenuItem(value: 'properties', child: Text('View properties')),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete file', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Visual Album Art / Waveform Card
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.music_note_rounded, size: 80, color: Colors.white),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          ext,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Title and format badge
              Column(
                children: [
                  Text(
                    fileName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'V2A Converted Audio • $ext',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),

              // Animated Waveform Visualizer
              AudioVisualizerWidget(
                isPlaying: _isPlaying,
                color: theme.colorScheme.primary,
              ),

              // Position Slider and Duration
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: _duration.inMilliseconds > 0
                          ? _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble()
                          : 0.0,
                      min: 0.0,
                      max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                      onChanged: (val) {
                        _audioService.seek(Duration(milliseconds: val.round()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_position), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(_formatDuration(_duration), style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),

              // Player Controls (Previous, Seek -10, Play/Pause, Seek +10, Next)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _audioService.repeatMode == AudioRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : _audioService.repeatMode == AudioRepeatMode.all
                                ? Icons.repeat_on_rounded
                                : Icons.repeat_rounded,
                        color: _audioService.repeatMode != AudioRepeatMode.off ? theme.colorScheme.primary : Colors.grey,
                      ),
                      tooltip: 'Repeat mode',
                      onPressed: () {
                        _audioService.toggleRepeatMode();
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.replay_10_rounded, size: 30),
                      tooltip: 'Seek -10s',
                      onPressed: () => _audioService.seekRelative(-10),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.large(
                      heroTag: 'player_main_fab',
                      elevation: 3,
                      onPressed: () {
                        if (_isPlaying) {
                          _audioService.pause();
                        } else {
                          _audioService.play();
                        }
                      },
                      child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 48),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.forward_10_rounded, size: 30),
                      tooltip: 'Seek +10s',
                      onPressed: () => _audioService.seekRelative(10),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _showSpeedDialog,
                      child: Text(
                        '${_audioService.playbackSpeed}x',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom secondary volume slider
              Row(
                children: [
                  const Icon(Icons.volume_down_rounded, size: 20, color: Colors.grey),
                  Expanded(
                    child: Slider(
                      value: _volume,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) {
                        setState(() => _volume = val);
                        _audioService.setVolume(val);
                      },
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, size: 20, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
