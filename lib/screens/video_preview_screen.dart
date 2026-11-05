import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/media_file.dart';
import '../utils/app_transitions.dart';
import 'conversion_settings_screen.dart';

class VideoPreviewScreen extends StatefulWidget {
  final MediaFile mediaFile;

  const VideoPreviewScreen({
    super.key,
    required this.mediaFile,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isPlaying = false;
  bool _isMuted = false;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  bool _isFullScreen = false;
  bool _showControls = true;
  late int _selectedAudioTrackIndex;

  @override
  void initState() {
    super.initState();
    _selectedAudioTrackIndex = widget.mediaFile.audioTracks.isNotEmpty
        ? widget.mediaFile.audioTracks.first.index
        : 0;
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final file = File(widget.mediaFile.path);
      if (!await file.exists()) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Source video file not found';
        });
        return;
      }

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();

      _controller!.addListener(() {
        if (!mounted) return;
        final isPlayingNow = _controller!.value.isPlaying;
        if (isPlayingNow != _isPlaying) {
          setState(() {
            _isPlaying = isPlayingNow;
          });
        }
      });

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error initializing video preview: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _seekRelative(int seconds) {
    if (_controller == null || !_isInitialized) return;
    final current = _controller!.value.position;
    final total = _controller!.value.duration;
    final target = current + Duration(seconds: seconds);
    if (target < Duration.zero) {
      _controller!.seekTo(Duration.zero);
    } else if (target > total) {
      _controller!.seekTo(total);
    } else {
      _controller!.seekTo(target);
    }
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : _volume);
    });
  }

  void _setVolume(double val) {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _volume = val;
      _isMuted = val == 0.0;
      _controller!.setVolume(_volume);
    });
  }

  void _setPlaybackSpeed(double speed) {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _playbackSpeed = speed;
      _controller!.setPlaybackSpeed(speed);
    });
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _proceedToSettings() {
    _controller?.pause();

    Navigator.of(context).push(
      AppTransitions.slideFadeRoute(
        ConversionSettingsScreen(
          mediaFile: widget.mediaFile,
          initialSelectedTrackIndex: _selectedAudioTrackIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(child: _buildVideoPlayerSurface()),
              _buildVideoControlsOverlay(theme),
              Positioned(
                top: 12,
                left: 12,
                child: IconButton(
                  icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 28),
                  onPressed: _toggleFullScreen,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mediaFile.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Fullscreen',
            onPressed: _toggleFullScreen,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video Surface with controls overlay
            Container(
              color: Colors.black,
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildVideoPlayerSurface(),
                  _buildVideoControlsOverlay(theme),
                ],
              ),
            ),

            // Video Seek Bar & Timestamps
            if (_isInitialized && _controller != null)
              ValueListenableBuilder(
                valueListenable: _controller!,
                builder: (context, VideoPlayerValue value, child) {
                  final position = value.position;
                  final duration = value.duration;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          ),
                          child: Slider(
                            value: duration.inMilliseconds > 0
                                ? position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble()
                                : 0.0,
                            min: 0.0,
                            max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                            onChanged: (val) {
                              _controller!.seekTo(Duration(milliseconds: val.round()));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                _formatDuration(duration),
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
                  );
                },
              ),

            // Video Controls Row (Priority 1: Overflow proof with FittedBox & responsive spacing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10_rounded),
                      tooltip: 'Seek -10s',
                      onPressed: () => _seekRelative(-10),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'preview_play_fab',
                      elevation: 1,
                      onPressed: _togglePlayPause,
                      child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.forward_10_rounded),
                      tooltip: 'Seek +10s',
                      onPressed: () => _seekRelative(10),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<double>(
                      tooltip: 'Playback speed',
                      initialValue: _playbackSpeed,
                      onSelected: _setPlaybackSpeed,
                      itemBuilder: (context) => [
                        0.5,
                        0.75,
                        1.0,
                        1.25,
                        1.5,
                        2.0,
                      ].map((speed) => PopupMenuItem(value: speed, child: Text('${speed}x'))).toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_playbackSpeed}x',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                      tooltip: _isMuted ? 'Unmute' : 'Volume',
                      onPressed: _toggleMute,
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => StatefulBuilder(
                            builder: (ctx, setDialogState) => AlertDialog(
                              title: const Text('Volume Control'),
                              content: Slider(
                                value: _volume,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (val) {
                                  setDialogState(() {});
                                  _setVolume(val);
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 20),

            // Video Media Properties Card
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Media Properties',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildPropertyRow('Resolution', widget.mediaFile.resolutionString.isNotEmpty ? widget.mediaFile.resolutionString : 'Audio only'),
                    _buildPropertyRow('Video Codec', widget.mediaFile.videoCodec?.toUpperCase() ?? 'None'),
                    _buildPropertyRow('Duration', widget.mediaFile.formattedDuration),
                    _buildPropertyRow('File Size', widget.mediaFile.formattedSize),
                    _buildPropertyRow('Container', widget.mediaFile.extension.toUpperCase().replaceAll('.', '')),
                  ],
                ),
              ),
            ),

            // Audio Track Selector
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.audiotrack_rounded, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Audio Streams (${widget.mediaFile.audioTracks.length})',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (widget.mediaFile.audioTracks.isEmpty)
                      const Text(
                        'No audio streams detected in this file.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      )
                    else
                      Column(
                        children: widget.mediaFile.audioTracks.map((track) {
                          final isSelected = _selectedAudioTrackIndex == track.index;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedAudioTrackIndex = track.index;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    size: 18,
                                    color: isSelected ? theme.colorScheme.primary : Colors.grey,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      track.displayName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: widget.mediaFile.hasAudio ? _proceedToSettings : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Extract Audio & Configure Settings'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _controller?.pause();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Choose Another File'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerSurface() {
    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 10),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 10),
          Text('Loading video surface...', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio > 0 ? _controller!.value.aspectRatio : 16 / 9,
      child: VideoPlayer(_controller!),
    );
  }

  Widget _buildVideoControlsOverlay(ThemeData theme) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          color: Colors.black38,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10, color: Colors.white, size: 36),
                  onPressed: () => _seekRelative(-10),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: Colors.white,
                    size: 56,
                  ),
                  onPressed: _togglePlayPause,
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(Icons.forward_10, color: Colors.white, size: 36),
                  onPressed: () => _seekRelative(10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
