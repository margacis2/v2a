import 'dart:async';
import 'dart:io';
import '../models/performance_stats.dart';

class PerformanceMonitorService {
  static final PerformanceMonitorService _instance = PerformanceMonitorService._internal();
  factory PerformanceMonitorService() => _instance;
  PerformanceMonitorService._internal();

  PerformanceStats _latestStats = const PerformanceStats();
  PerformanceStats get latestStats => _latestStats;

  Timer? _pollingTimer;
  final _statsController = StreamController<PerformanceStats>.broadcast();
  Stream<PerformanceStats> get statsStream => _statsController.stream;

  void startMonitoring({Duration interval = const Duration(seconds: 2)}) {
    if (_pollingTimer != null) return;
    _updateStats();
    _pollingTimer = Timer.periodic(interval, (_) => _updateStats());
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _updateStats() async {
    try {
      // 1. App Process RSS memory
      final appRssBytes = ProcessInfo.currentRss;
      final appRamMb = appRssBytes / (1024 * 1024);

      // 2. System memory via /proc/meminfo (standard Linux/Android)
      double totalMemMb = 0.0;
      double availMemMb = 0.0;

      if (Platform.isAndroid || Platform.isLinux) {
        final memInfoFile = File('/proc/meminfo');
        if (await memInfoFile.exists()) {
          final lines = await memInfoFile.readAsLines();
          for (final line in lines) {
            if (line.startsWith('MemTotal:')) {
              final kb = _extractKb(line);
              totalMemMb = kb / 1024;
            } else if (line.startsWith('MemAvailable:')) {
              final kb = _extractKb(line);
              availMemMb = kb / 1024;
            }
          }
        }
      }

      double usagePercent = 0.0;
      if (totalMemMb > 0) {
        usagePercent = ((totalMemMb - availMemMb) / totalMemMb * 100).clamp(0.0, 100.0);
      }

      _latestStats = PerformanceStats(
        appRamUsedMb: appRamMb,
        totalPhysicalRamMb: totalMemMb,
        availablePhysicalRamMb: availMemMb,
        systemRamUsagePercent: usagePercent,
        thermalStatus: 'Optimal',
      );

      _statsController.add(_latestStats);
    } catch (_) {}
  }

  double _extractKb(String line) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return double.tryParse(parts[1]) ?? 0.0;
    }
    return 0.0;
  }

  void dispose() {
    stopMonitoring();
    _statsController.close();
  }
}

