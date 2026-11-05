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

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

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
    await _db.insertJob(job);
    notifyListeners();
    _processNextInQueue();
  }

  /// Adds multiple jobs in a batch in sequential order
  Future<void> enqueueBatch(List<ConversionJob> batchJobs) async {
    for (final job in batchJobs) {
      _jobs.add(job);
      await _db.insertJob(job);
    }
    notifyListeners();
    _processNextInQueue();
  }

  /// Cancels a running or queued job
  Future<void> cancelJob(String jobId) async {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index == -1) return;

    final job = _jobs[index];
    if (job.status == JobStatus.running || job.status == JobStatus.preparing) {
      _jobs[index] = job.copyWith(status: JobStatus.cancelling);
      notifyListeners();
      await _engine.cancelJob(jobId);
    } else if (job.status == JobStatus.queued) {
      _jobs[index] = job.copyWith(status: JobStatus.cancelled, completedAt: DateTime.now());
      await _db.updateJob(_jobs[index]);
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
    await _db.updateJob(_jobs[index]);
    notifyListeners();
    _processNextInQueue();
  }

  /// Removes a job record from SQLite without deleting physical output files
  Future<void> removeJob(String jobId) async {
    _jobs.removeWhere((j) => j.id == jobId);
    await _db.deleteJob(jobId);
    notifyListeners();
  }

  /// Clears completed history entries
  Future<void> clearCompleted() async {
    _jobs.removeWhere((j) => j.status == JobStatus.completed);
    await _db.clearCompletedHistory();
    notifyListeners();
  }

  /// Main background queue execution loop (sequential with failure isolation)
  Future<void> _processNextInQueue() async {
    if (_isProcessing) return;

    final nextIndex = _jobs.indexWhere((j) => j.status == JobStatus.queued);
    if (nextIndex == -1) {
      _activeJob = null;
      _isProcessing = false;
      notifyListeners();
      return;
    }

    _isProcessing = true;
    var currentJob = _jobs[nextIndex];
    _activeJob = currentJob;

    // Transition to Preparing
    currentJob = currentJob.copyWith(status: JobStatus.preparing);
    _jobs[nextIndex] = currentJob;
    await _db.updateJob(currentJob);
    notifyListeners();

    try {
      // Transition to Running
      currentJob = currentJob.copyWith(status: JobStatus.running);
      _jobs[nextIndex] = currentJob;
      await _db.updateJob(currentJob);
      notifyListeners();

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
          final idx = _jobs.indexWhere((j) => j.id == currentJob.id);
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

      final finalIndex = _jobs.indexWhere((j) => j.id == currentJob.id);
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
          // Failed (failure isolation: next queued job will still execute smoothly)
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
        await _db.updateJob(_jobs[finalIndex]);
      }
    } catch (e) {
      final finalIndex = _jobs.indexWhere((j) => j.id == currentJob.id);
      if (finalIndex != -1) {
        _jobs[finalIndex] = _jobs[finalIndex].copyWith(
          status: JobStatus.failed,
          errorMessage: e.toString(),
          completedAt: DateTime.now(),
        );
        await _db.updateJob(_jobs[finalIndex]);
      }
    } finally {
      _isProcessing = false;
      _activeJob = null;
      notifyListeners();
      // Continue queue sequentially
      _processNextInQueue();
    }
  }
}
