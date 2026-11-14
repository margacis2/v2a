import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversion_job.dart';
import '../providers/app_state_provider.dart';
import '../services/audio_player_service.dart';
import '../services/conversion_engine.dart';
import '../services/feedback_service.dart';
import '../services/job_queue_service.dart';
import '../utils/app_transitions.dart';
import 'audio_player_screen.dart';
import 'result_screen.dart';

class ActiveJobsScreen extends StatefulWidget {
  final String? highlightJobId;

  const ActiveJobsScreen({super.key, this.highlightJobId});

  @override
  State<ActiveJobsScreen> createState() => _ActiveJobsScreenState();
}

class _ActiveJobsScreenState extends State<ActiveJobsScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedJobIds = {};

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _toggleSelection(String jobId) {
    setState(() {
      if (_selectedJobIds.contains(jobId)) {
        _selectedJobIds.remove(jobId);
        if (_selectedJobIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedJobIds.add(jobId);
      }
    });
  }

  void _selectAll(List<ConversionJob> jobs) {
    setState(() {
      if (_selectedJobIds.length == jobs.length) {
        _selectedJobIds.clear();
      } else {
        _selectedJobIds.addAll(jobs.map((j) => j.id));
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedJobIds.clear();
    });
  }

  // Priority 2.C: Multi-select Queue Removal with Safe Active-Job Cancellation
  void _confirmRemoveSelected(JobQueueService queueService, List<ConversionJob> jobs) {
    final selectedJobs = jobs.where((j) => _selectedJobIds.contains(j.id)).toList();
    if (selectedJobs.isEmpty) return;

    final runningCount = selectedJobs.where((j) => j.status == JobStatus.running || j.status == JobStatus.finalizing || j.status == JobStatus.preparing).length;
    final queuedCount = selectedJobs.where((j) => j.status == JobStatus.queued).length;
    final otherCount = selectedJobs.length - runningCount - queuedCount;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Remove ${selectedJobs.length} Selected Job(s)?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (runningCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '⚠️ $runningCount active conversion(s) will be stopped immediately.',
                    style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
              if (queuedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• $queuedCount queued item(s) will be removed from conversion.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (otherCount > 0)
                Text(
                  '• $otherCount completed or failed item(s) will be cleared from this queue view.',
                  style: const TextStyle(fontSize: 12),
                ),
              const SizedBox(height: 12),
              const Text(
                'Note: Output audio files for already completed jobs will remain safely on your device.',
                style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.of(ctx).pop();

                // Stop any active sessions first
                for (final job in selectedJobs) {
                  if (job.status == JobStatus.running || job.status == JobStatus.finalizing || job.status == JobStatus.preparing) {
                    await ConversionEngine().cancelSession(job.id);
                  }
                  queueService.removeJob(job.id);
                }

                final count = selectedJobs.length;
                _exitSelectionMode();

                if (mounted) {
                  FeedbackService().notifyFileDeleted(
                    context,
                    count: count,
                    description: '$count job(s) removed from queue',
                  );
                }
              },
              child: const Text('Remove Selected'),
            ),
          ],
        );
      },
    );
  }

  // Priority 2.D: Safe Clear Completed Dialog
  void _confirmClearCompleted(JobQueueService queueService) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Clear Completed Jobs?'),
          content: const Text(
            'This removes finished conversion items from the active queue list.\n\nYour converted audio files in storage will NOT be deleted.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                queueService.clearCompleted();
                FeedbackService().notifyFileDeleted(
                  context,
                  count: 1,
                  description: 'Completed items cleared from queue view',
                );
              },
              child: const Text('Clear'),
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
    final queueService = Provider.of<JobQueueService>(context);
    final appState = Provider.of<AppStateProvider>(context);
    final stats = appState.performanceStats;

    final jobs = queueService.jobs;
    final isBatchActive = queueService.totalJobsCount > 1 && (queueService.activeJobCount > 0 || queueService.queuedJobCount > 0);

    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Cancel Selection',
                onPressed: _exitSelectionMode,
              )
            : null,
        title: Text(
          _isSelectionMode ? '${_selectedJobIds.length} Selected' : 'Conversion Queue',
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(
                _selectedJobIds.length == jobs.length && jobs.isNotEmpty
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
              ),
              tooltip: _selectedJobIds.length == jobs.length ? 'Deselect All' : 'Select All',
              onPressed: jobs.isNotEmpty ? () => _selectAll(jobs) : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              tooltip: 'Remove Selected',
              onPressed: _selectedJobIds.isEmpty ? null : () => _confirmRemoveSelected(queueService, jobs),
            ),
          ] else ...[
            if (jobs.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.checklist_rounded),
                tooltip: 'Select Multiple',
                onPressed: () {
                  setState(() => _isSelectionMode = true);
                },
              ),
            if (jobs.any((j) => j.status == JobStatus.completed))
              IconButton(
                icon: const Icon(Icons.cleaning_services_rounded),
                tooltip: 'Clear Completed',
                onPressed: () => _confirmClearCompleted(queueService),
              ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Hardware RAM & System Load Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222A) : const Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.memory_rounded, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          const Flexible(
                            child: Text(
                              'Process RAM',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      stats.appRamFormatted,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: stats.systemRamUsagePercent > 0 ? (stats.systemRamUsagePercent / 100).clamp(0.0, 1.0) : null,
                    minHeight: 4,
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      stats.systemRamUsagePercent > 85 ? Colors.red : theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Total: ${stats.systemRamFormatted}',
                        style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Queue: ${queueService.activeJobCount} active • ${queueService.queuedJobCount} pending',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Priority 2.3: Overall Batch Conversion Progress Card
          if (isBatchActive) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_motion_rounded, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Batch Conversion Progress',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${queueService.completedJobCount}/${queueService.totalJobsCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: queueService.batchProgress,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Completed ${(queueService.batchProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Pending: ${queueService.queuedJobCount} • Active: ${queueService.activeJobCount}',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Jobs List View
          Expanded(
            child: jobs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.playlist_remove_rounded, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text(
                          'Conversion queue is empty',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Extract video audio or use Batch Convert from Home',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: jobs.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      final isHighlighted = job.id == widget.highlightJobId;
                      final isSelected = _selectedJobIds.contains(job.id);

                      return Card(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : (isHighlighted ? theme.colorScheme.primary.withValues(alpha: 0.08) : null),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: isHighlighted
                              ? BorderSide(color: theme.colorScheme.primary, width: 2)
                              : BorderSide.none,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(job.id);
                            } else if (job.status == JobStatus.completed) {
                              Navigator.of(context).push(
                                AppTransitions.slideFadeRoute(ResultScreen(job: job)),
                              );
                            }
                          },
                          onLongPress: () {
                            if (!_isSelectionMode) {
                              setState(() {
                                _isSelectionMode = true;
                                _selectedJobIds.add(job.id);
                              });
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header: Checkbox / Status icon + Filename + Badge
                                Row(
                                  children: [
                                    if (_isSelectionMode)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Checkbox(
                                          value: isSelected,
                                          visualDensity: VisualDensity.compact,
                                          onChanged: (_) => _toggleSelection(job.id),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _statusColor(job.status).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _statusIcon(job.status),
                                          color: _statusColor(job.status),
                                          size: 18,
                                        ),
                                      ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            job.requestedFileName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${job.format.label} • ${job.mode.title}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStatusBadge(job.status, theme),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Progress bar if active
                                if (job.status.isActive) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: job.progress > 0 ? job.progress : null,
                                      minHeight: 5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        '${(job.progress * 100).toStringAsFixed(0)}% • ${job.speedRatio > 0 ? "${job.speedRatio.toStringAsFixed(1)}x" : "Starting..."}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      Text(
                                        'Elapsed: ${_formatDuration(job.elapsedSeconds)}${job.etaSeconds > 0 ? " • ETA: ~${_formatDuration(job.etaSeconds)}" : ""}',
                                        style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                  if (!_isSelectionMode) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        ),
                                        icon: const Icon(Icons.cancel_outlined, size: 14),
                                        label: const Text('Cancel', style: TextStyle(fontSize: 11)),
                                        onPressed: () => queueService.cancelJob(job.id),
                                      ),
                                    ),
                                  ],
                                ] else if (job.status == JobStatus.queued) ...[
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        'Waiting in sequential queue',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                      ),
                                      if (!_isSelectionMode)
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            foregroundColor: Colors.red,
                                          ),
                                          onPressed: () => queueService.removeJob(job.id),
                                          child: const Text('Cancel', style: TextStyle(fontSize: 11)),
                                        ),
                                    ],
                                  ),
                                ] else if (job.status == JobStatus.completed) ...[
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Text(
                                        'Output: ${job.formattedOutputSize}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                      ),
                                      if (!_isSelectionMode)
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                visualDensity: VisualDensity.compact,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              ),
                                              icon: const Icon(Icons.play_arrow_rounded, size: 14),
                                              label: const Text('Play Audio', style: TextStyle(fontSize: 11)),
                                              onPressed: () async {
                                                final audioService = AudioPlayerService();
                                                final ok = await audioService.playSingleFile(job.finalOutputPath);
                                                if (ok && context.mounted) {
                                                  Navigator.of(context).push(
                                                    AppTransitions.slideFadeRoute(AudioPlayerScreen(filePath: job.finalOutputPath)),
                                                  );
                                                }
                                              },
                                            ),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                visualDensity: VisualDensity.compact,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              ),
                                              icon: const Icon(Icons.visibility_rounded, size: 14),
                                              label: const Text('View Details', style: TextStyle(fontSize: 11)),
                                              onPressed: () {
                                                Navigator.of(context).push(
                                                  AppTransitions.slideFadeRoute(ResultScreen(job: job)),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ] else if (job.status == JobStatus.failed || job.status == JobStatus.interrupted) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (job.errorMessage != null)
                                        Flexible(
                                          child: Text(
                                            job.errorMessage!,
                                            style: const TextStyle(fontSize: 10, color: Colors.red),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      if (!_isSelectionMode)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                visualDensity: VisualDensity.compact,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              ),
                                              icon: const Icon(Icons.refresh_rounded, size: 14),
                                              label: const Text('Retry', style: TextStyle(fontSize: 11)),
                                              onPressed: () => queueService.retryJob(job.id),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                              onPressed: () => queueService.removeJob(job.id),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(JobStatus status, ThemeData theme) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _statusColor(JobStatus status) {
    switch (status) {
      case JobStatus.completed:
        return Colors.green;
      case JobStatus.running:
      case JobStatus.finalizing:
      case JobStatus.preparing:
      case JobStatus.validating:
      case JobStatus.inspecting:
        return const Color(0xFF1E88E5);
      case JobStatus.queued:
        return Colors.orange;
      case JobStatus.paused:
        return Colors.amber;
      case JobStatus.failed:
      case JobStatus.interrupted:
        return Colors.red;
      case JobStatus.cancelled:
      case JobStatus.cancelling:
      case JobStatus.waitingForStorage:
        return Colors.grey;
    }
  }

  IconData _statusIcon(JobStatus status) {
    switch (status) {
      case JobStatus.completed:
        return Icons.check_circle_rounded;
      case JobStatus.running:
        return Icons.sync_rounded;
      case JobStatus.finalizing:
      case JobStatus.preparing:
      case JobStatus.validating:
      case JobStatus.inspecting:
        return Icons.hourglass_top_rounded;
      case JobStatus.queued:
        return Icons.schedule_rounded;
      case JobStatus.paused:
        return Icons.pause_circle_rounded;
      case JobStatus.failed:
        return Icons.error_rounded;
      case JobStatus.interrupted:
        return Icons.warning_rounded;
      case JobStatus.cancelled:
      case JobStatus.cancelling:
        return Icons.cancel_rounded;
      case JobStatus.waitingForStorage:
        return Icons.storage_rounded;
    }
  }
}
