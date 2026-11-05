import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

enum AudioRepeatMode { off, one, all }

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  final List<String> _playlist = [];
  List<String> get playlist => List.unmodifiable(_playlist);

  int _currentIndex = -1;
  int get currentIndex => _currentIndex;
  String? get currentFilePath =>
      (_currentIndex >= 0 && _currentIndex < _playlist.length) ? _playlist[_currentIndex] : null;

  AudioRepeatMode _repeatMode = AudioRepeatMode.off;
  AudioRepeatMode get repeatMode => _repeatMode;

  bool _isShuffle = false;
  bool get isShuffle => _isShuffle;

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Configure system audio session for playback and audio-focus handling
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Listen to audio focus interruptions (calls, notifications)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(0.3);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            _player.pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });

    // Listen to becoming noisy (e.g. unplugging headphones, disconnecting Bluetooth)
    session.becomingNoisyEventStream.listen((_) {
      _player.pause();
    });

    // Track playback completion for playlist progression
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleTrackEnded();
      }
    });

    _isInitialized = true;
  }

  /// Sets up a new playlist and begins playing at initialIndex
  Future<bool> setPlaylist(List<String> paths, {int initialIndex = 0}) async {
    await init();
    _playlist.clear();
    _playlist.addAll(paths);

    if (_playlist.isEmpty) {
      await _player.stop();
      _currentIndex = -1;
      return false;
    }

    _currentIndex = initialIndex.clamp(0, _playlist.length - 1);
    return await playTrackAtIndex(_currentIndex);
  }

  /// Plays a single file immediately
  Future<bool> playSingleFile(String path) async {
    return await setPlaylist([path], initialIndex: 0);
  }

  /// Plays track at given playlist index with full file integrity verification
  Future<bool> playTrackAtIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return false;
    final path = _playlist[index];
    final file = File(path);

    if (!await file.exists() || await file.length() == 0) {
      debugPrint('[AudioPlayerService] File does not exist or is empty: $path');
      return false;
    }

    try {
      _currentIndex = index;
      await _player.setFilePath(path);
      await _player.setSpeed(_playbackSpeed);
      await _player.play();
      return true;
    } catch (e) {
      debugPrint('[AudioPlayerService] Error playing $path: $e');
      return false;
    }
  }

  Future<void> play() async => await _player.play();
  Future<void> pause() async => await _player.pause();

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> seekRelative(int seconds) async {
    final current = _player.position;
    final total = _player.duration ?? Duration.zero;
    final target = current + Duration(seconds: seconds);
    if (target < Duration.zero) {
      await _player.seek(Duration.zero);
    } else if (target > total) {
      await _player.seek(total);
    } else {
      await _player.seek(target);
    }
  }

  Future<void> setSpeed(double speed) async {
    _playbackSpeed = speed;
    await _player.setSpeed(speed);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  void toggleRepeatMode() {
    switch (_repeatMode) {
      case AudioRepeatMode.off:
        _repeatMode = AudioRepeatMode.all;
        _player.setLoopMode(LoopMode.off);
        break;
      case AudioRepeatMode.all:
        _repeatMode = AudioRepeatMode.one;
        _player.setLoopMode(LoopMode.one);
        break;
      case AudioRepeatMode.one:
        _repeatMode = AudioRepeatMode.off;
        _player.setLoopMode(LoopMode.off);
        break;
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
  }

  Future<void> nextTrack() async {
    if (_playlist.isEmpty) return;
    if (_isShuffle && _playlist.length > 1) {
      final randomIndex = (DateTime.now().millisecondsSinceEpoch % _playlist.length);
      await playTrackAtIndex(randomIndex);
    } else if (_currentIndex + 1 < _playlist.length) {
      await playTrackAtIndex(_currentIndex + 1);
    } else if (_repeatMode == AudioRepeatMode.all) {
      await playTrackAtIndex(0);
    }
  }

  Future<void> previousTrack() async {
    if (_playlist.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      await playTrackAtIndex(_currentIndex - 1);
    } else if (_repeatMode == AudioRepeatMode.all) {
      await playTrackAtIndex(_playlist.length - 1);
    }
  }

  void _handleTrackEnded() {
    if (_repeatMode == AudioRepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      nextTrack();
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
