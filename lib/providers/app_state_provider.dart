import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversion_config.dart';
import '../models/media_file.dart';
import '../models/performance_stats.dart';
import '../services/performance_monitor_service.dart';

class AppStateProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'v2a_theme_mode';
  static const String _keyOnboardingDone = 'v2a_onboarding_completed';
  static const String _keyDefaultFormat = 'v2a_default_format';
  static const String _keyDefaultBitrate = 'v2a_default_bitrate';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _isOnboardingCompleted = false;
  bool get isOnboardingCompleted => _isOnboardingCompleted;

  AudioFormat _defaultFormat = AudioFormat.mp3;
  AudioFormat get defaultFormat => _defaultFormat;

  int _defaultBitrate = 192;
  int get defaultBitrate => _defaultBitrate;

  final List<MediaFile> _selectedFiles = [];
  List<MediaFile> get selectedFiles => List.unmodifiable(_selectedFiles);

  PerformanceStats _performanceStats = const PerformanceStats();
  PerformanceStats get performanceStats => _performanceStats;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_keyThemeMode);
    if (themeStr == 'light') _themeMode = ThemeMode.light;
    if (themeStr == 'dark') _themeMode = ThemeMode.dark;

    _isOnboardingCompleted = prefs.getBool(_keyOnboardingDone) ?? false;

    final formatStr = prefs.getString(_keyDefaultFormat);
    if (formatStr != null) {
      _defaultFormat = AudioFormat.values.firstWhere(
        (f) => f.name == formatStr,
        orElse: () => AudioFormat.mp3,
      );
    }

    _defaultBitrate = prefs.getInt(_keyDefaultBitrate) ?? 192;
    notifyListeners();
  }

  void startPerformanceMonitoring() {
    final monitor = PerformanceMonitorService();
    monitor.startMonitoring();
    monitor.statsStream.listen((stats) {
      _performanceStats = stats;
      notifyListeners();
    });
  }

  void stopPerformanceMonitoring() {
    PerformanceMonitorService().stopMonitoring();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.name);
    notifyListeners();
  }

  Future<void> setOnboardingCompleted(bool value) async {
    _isOnboardingCompleted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingDone, value);
    notifyListeners();
  }

  Future<void> setDefaultFormat(AudioFormat format) async {
    _defaultFormat = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultFormat, format.name);
    notifyListeners();
  }

  Future<void> setDefaultBitrate(int bitrate) async {
    _defaultBitrate = bitrate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDefaultBitrate, bitrate);
    notifyListeners();
  }

  void setSelectedFiles(List<MediaFile> files) {
    _selectedFiles.clear();
    _selectedFiles.addAll(files);
    notifyListeners();
  }

  void addSelectedFile(MediaFile file) {
    _selectedFiles.add(file);
    notifyListeners();
  }

  void removeSelectedFile(String path) {
    _selectedFiles.removeWhere((f) => f.path == path);
    notifyListeners();
  }

  void clearSelectedFiles() {
    _selectedFiles.clear();
    notifyListeners();
  }
}

