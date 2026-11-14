import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/conversion_job.dart';
import 'conversion_engine.dart';
import 'database_service.dart';
import 'notification_service.dart';

class JobQueueService extends ChangeNotifier {
  static final JobQueueService _instance = JobQueueService._internal();
  factory JobQueueService() => _instance;
  JobQueueService._internal();

  final DatabaseService _db = DatabaseService();
  final ConversionEngine _engine = ConversionEngine();
  final NotificationService _notifications = NotificationService();

  List<ConversionJob> _jobs = [];
  List<ConversionJob> get jobs => List.unmodifiable(_jobs);

  int _maxConcurrency = 1;
  int get maxConcurrency => _maxConcurrency;

  void setMaxConcurrency(int value) {
    if (value < 1) value = 1;
    if (value > 4) value = 4;
    _maxConcurrency = value;
    notifyListeners();
    _processNextInQueue();
  }

  final Set<String> _runningJobIds = {};

  bool get isProcessing => _runningJobIds.isNotEmpty;

  ConversionJob? _activeJob;
  ConversionJob? get activeJob => _activeJob;

  int get totalJobsCount => _jobs.length;
  int get activeJobCount => _jobs.where((j) => j.status.isActive).length;
  int get queuedJobCount => _jobs.where((j) => j.status == JobStatus.queued).length;
  int get completedJobCount => _jobs.where((j) => j.status == JobStatus.completed).length;
  int get failedJobCount => _jobs.where((j) => j.status == JobStatus.failed || j.status == JobStatus.interrupted).length;
  int get cancelledJobCount => _jobs.where((j) => j.status == JobStatus.cancelled).length;

  /// Overall batch progress between 0.0 and 1.0
  double get batchProgress {
    if (_jobs.isEmpty) return 0.0;
    double totalWeight = 0.0;
    for (final job in _jobs) {
      if (job.status == JobStatus.completed) {
        totalWeight += 1.0;
      } else if (job.status.isActive) {
        totalWeight += job.progress.clamp(0.0, 1.0);
      }
    }
    return (totalWeight / _jobs.length).clamp(0.0, 1.0);
  }

  Future<void> init() async {
    await _notifications.init();
    await _db.recoverInterruptedJobs();
    await reloadJobs();
    _processNextInQueue();
  }

  Future<void> reloadJobs() async {
    _jobs = await _db.getAllJobs();
    notifyListeners();
  }

  /// Adds a single conversion job to the queue
  Future<void> enqueueJob(ConversionJob job) async {
    _jobs.insert(0, job);
    try {
      await _db.insertJob(job);
    } catch (e) {
      debugPrint('[JobQueueService] DB insert warning: $e');
    }
    notifyListeners();
    _processNextInQueue();
  }

  /// Adds multiple jobs in a batch in sequential order
  Future<void> enqueueBatch(List<ConversionJob> batchJobs) async {
    for (final job in batchJobs) {
      _jobs.add(job);
      try {
        await _db.insertJob(job);
      } catch (e) {
        debugPrint('[JobQueueService] DB insert warning: $e');
      }
    }
    notifyListeners();
    _processNextInQueue();
  }

  /// Cancels a running or queued job
  Future<void> cancelJob(String jobId) async {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index == -1) return;

    final job = _jobs[index];
    if (job.status == JobStatus.running || job.status == JobStatus.preparing || job.status == JobStatus.validating) {
      _jobs[index] = job.copyWith(status: JobStatus.cancelling);
      notifyListeners();
      await _engine.cancelJob(jobId);
    } else if (job.status == JobStatus.queued) {
      _jobs[index] = job.copyWith(status: JobStatus.cancelled, completedAt: DateTime.now());
      try {
        await _db.updateJob(_jobs[index]);
      } catch (_) {}
      notifyListeners();
    }
  }

  /// Retries a failed or cancelled job
  Future<void> retryJob(String jobId) async {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index == -1) return;

    final job = _jobs[index];
    _jobs[index] = job.copyWith(
      status: JobStatus.queued,
      progress: 0.0,
      errorMessage: null,
      elapsedSeconds: 0,
      speedRatio: 0.0,
    );
    try {
      await _db.updateJob(_jobs[index]);
    } catch (_) {}
    notifyListeners();
    _processNextInQueue();
  }

  /// Removes a job record from SQLite without deleting physical output files
  Future<void> removeJob(String jobId) async {
    _jobs.removeWhere((j) => j.id == jobId);
    try {
      await _db.deleteJob(jobId);
    } catch (_) {}
    notifyListeners();
  }

  /// Clears completed history entries
  Future<void> clearCompleted() async {
    _jobs.removeWhere((j) => j.status == JobStatus.completed);
    try {
      await _db.clearCompletedHistory();
    } catch (_) {}
    notifyListeners();
  }

  /// Main background queue execution loop with configurable concurrency & robust error isolation
  Future<void> _processNextInQueue() async {
    while (_runningJobIds.length < _maxConcurrency) {
      final nextIndex = _jobs.indexWhere((j) => j.status == JobStatus.queued && !_runningJobIds.contains(j.id));
      if (nextIndex == -1) break;

      final jobToRun = _jobs[nextIndex];
      _runningJobIds.add(jobToRun.id);
      _executeSingleJob(jobToRun.id);
    }
  }

  Future<void> _executeSingleJob(String jobId) async {
    final startIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (startIndex == -1) {
      _runningJobIds.remove(jobId);
      return;
    }

    // Step 1: Validating
    var currentJob = _jobs[startIndex].copyWith(status: JobStatus.validating);
    _jobs[startIndex] = currentJob;
    _activeJob = currentJob;
    notifyListeners();
    try {
      await _db.updateJob(currentJob);
    } catch (_) {}

    // Step 2: Preparing
    final prepIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (prepIndex != -1) {
      currentJob = _jobs[prepIndex].copyWith(status: JobStatus.preparing);
      _jobs[prepIndex] = currentJob;
      notifyListeners();
      try {
        await _db.updateJob(currentJob);
      } catch (_) {}
    }

    try {
      // Step 3: Running
      final runIndex = _jobs.indexWhere((j) => j.id == jobId);
      if (runIndex != -1) {
        currentJob = _jobs[runIndex].copyWith(status: JobStatus.running);
        _jobs[runIndex] = currentJob;
        notifyListeners();
        try {
          await _db.updateJob(currentJob);
        } catch (_) {}
      }

      final notifId = currentJob.id.hashCode.abs() % 100000;
      int lastNotifPercent = -1;

      final result = await _engine.executeConversion(
        job: currentJob,
        onProgress: ({
          required double progress,
          required double speedRatio,
          required int currentTimeMs,
          required int elapsedSeconds,
          required int estimatedRemainingSeconds,
        }) {
          final idx = _jobs.indexWhere((j) => j.id == jobId);
          if (idx != -1) {
            _jobs[idx] = _jobs[idx].copyWith(
              progress: progress,
              speedRatio: speedRatio,
              currentTimeMs: currentTimeMs,
              elapsedSeconds: elapsedSeconds,
              estimatedRemainingSeconds: estimatedRemainingSeconds,
            );
            notifyListeners();

            // Throttled notification update
            final percent = (progress * 100).round();
            if (percent != lastNotifPercent && (percent % 5 == 0 || percent >= 99)) {
              lastNotifPercent = percent;
              _notifications.showProgressNotification(
                notificationId: notifId,
                title: 'Converting (${completedJobCount + 1}/$totalJobsCount)',
                fileName: currentJob.sourceFileName,
                progressPercent: percent,
                speedRatio: speedRatio,
              );
            }
          }
        },
      );

      final finalIndex = _jobs.indexWhere((j) => j.id == jobId);
      if (finalIndex != -1) {
        if (result.success) {
          _jobs[finalIndex] = _jobs[finalIndex].copyWith(
            status: JobStatus.completed,
            progress: 1.0,
            finalOutputPath: result.outputPath,
            outputSizeBytes: result.outputSizeBytes,
            speedRatio: result.averageSpeed,
            completedAt: DateTime.now(),
          );
          await _notifications.showCompletionNotification(
            notificationId: notifId,
            title: 'Conversion Complete',
            body: '${currentJob.sourceFileName} converted to ${currentJob.format.extension.toUpperCase()}',
          );
        } else if (result.errorMessage?.contains('cancelled') == true) {
          _jobs[finalIndex] = _jobs[finalIndex].copyWith(
            status: JobStatus.cancelled,
            errorMessage: result.errorMessage,
            completedAt: DateTime.now(),
          );
          await _notifications.cancelNotification(notifId);
        } else {
          // Failed (isolated: other jobs continue)
          _jobs[finalIndex] = _jobs[finalIndex].copyWith(
            status: JobStatus.failed,
            errorMessage: result.errorMessage,
            completedAt: DateTime.now(),
          );
          await _notifications.showCompletionNotification(
            notificationId: notifId,
            title: 'Conversion Failed',
            body: result.errorMessage ?? 'An error occurred during conversion',
          );
        }
        try {
          await _db.updateJob(_jobs[finalIndex]);
        } catch (_) {}
      }
    } catch (e) {
      final finalIndex = _jobs.indexWhere((j) => j.id == jobId);
      if (finalIndex != -1) {
        _jobs[finalIndex] = _jobs[finalIndex].copyWith(
          status: JobStatus.failed,
          errorMessage: e.toString(),
          completedAt: DateTime.now(),
        );
        try {
          await _db.updateJob(_jobs[finalIndex]);
        } catch (_) {}
      }
    } finally {
      _runningJobIds.remove(jobId);
      if (_activeJob?.id == jobId) {
        _activeJob = _jobs.where((j) => _runningJobIds.contains(j.id)).firstOrNull;
      }
      notifyListeners();
      // Continue queue
      _processNextInQueue();
    }
  }
}
