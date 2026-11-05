class PerformanceStats {
  final double appRamUsedMb;
  final double totalPhysicalRamMb;
  final double availablePhysicalRamMb;
  final double systemRamUsagePercent;
  final double processingSpeedRatio; // e.g. 14.5x
  final double readSpeedMbPerSec;
  final Duration elapsedTime;
  final Duration estimatedRemainingTime;
  final String thermalStatus;

  const PerformanceStats({
    this.appRamUsedMb = 0.0,
    this.totalPhysicalRamMb = 0.0,
    this.availablePhysicalRamMb = 0.0,
    this.systemRamUsagePercent = 0.0,
    this.processingSpeedRatio = 0.0,
    this.readSpeedMbPerSec = 0.0,
    this.elapsedTime = Duration.zero,
    this.estimatedRemainingTime = Duration.zero,
    this.thermalStatus = 'Normal',
  });

  String get appRamFormatted => '${appRamUsedMb.toStringAsFixed(1)} MB';
  String get systemRamFormatted =>
      '${(totalPhysicalRamMb - availablePhysicalRamMb).toStringAsFixed(0)} / ${totalPhysicalRamMb.toStringAsFixed(0)} MB (${systemRamUsagePercent.toStringAsFixed(1)}%)';
  String get speedFormatted =>
      processingSpeedRatio > 0 ? '${processingSpeedRatio.toStringAsFixed(1)}x Realtime' : 'Calculating...';
}

