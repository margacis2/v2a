import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/conversion_job.dart';
import '../../services/job_queue_service.dart';

class DesktopQueueScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const DesktopQueueScreen({
    super.key,
    required this.onNavigate,
  });

  void _revealInExplorer(String filePath) {
    if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [File(filePath).parent.path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final queue = Provider.of<JobQueueService>(context);

    final jobs = queue.jobs;
    final activeCount = jobs.where((j) => j.status == JobStatus.running || j.status == JobStatus.queued).length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13151B) : const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Conversion Queue',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (activeCount > 0) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$activeCount Active',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Multi-threaded batch background conversion pipeline',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: jobs.any((j) => j.status == JobStatus.completed)
                          ? () => queue.clearCompleted()
                          : null,
                      icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                      label: const Text('Clear Completed (Ctrl+Shift+C)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => onNavigate(1),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Job'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Queue List or Empty State
            Expanded(
              child: jobs.isEmpty
                  ? _buildEmptyQueue(context)
                  : ListView.separated(
                      itemCount: jobs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final job = jobs[index];
                        return _buildJobCard(context, job, queue, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyQueue(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.queue_music_rounded, size: 40, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Queue is Empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Add media files from the Audio Converter or drop them onto Home',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => onNavigate(1),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Open Converter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, ConversionJob job, JobQueueService queue, bool isDark) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (job.status) {
      case JobStatus.running:
        statusColor = const Color(0xFF2563EB);
        statusText = 'Converting (${(job.progress * 100).toStringAsFixed(0)}%)';
        statusIcon = Icons.sync_rounded;
        break;
      case JobStatus.queued:
        statusColor = Colors.orange;
        statusText = 'Queued';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case JobStatus.completed:
        statusColor = const Color(0xFF10B981);
        statusText = 'Completed';
        statusIcon = Icons.check_circle_rounded;
        break;
      case JobStatus.failed:
        statusColor = Colors.red;
        statusText = 'Failed';
        statusIcon = Icons.error_rounded;
        break;
      case JobStatus.cancelled:
        statusColor = Colors.grey;
        statusText = 'Cancelled';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.blueGrey;
        statusText = job.status.label;
        statusIcon = Icons.info_outline_rounded;
        break;
    }

    final targetName = '${job.requestedFileName}.${job.format.extension}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1E27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: job.status == JobStatus.running
              ? const Color(0xFF2563EB).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  job.format.label.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  job.preset.name,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ),
              const Spacer(),
              // Action buttons per job
              if (job.status == JobStatus.running || job.status == JobStatus.queued)
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, size: 20, color: Colors.red),
                  tooltip: 'Cancel Job',
                  onPressed: () => queue.cancelJob(job.id),
                ),
              if (job.status == JobStatus.completed && job.finalOutputPath.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.folder_open_rounded, size: 20, color: Color(0xFF2563EB)),
                  tooltip: 'Show in Explorer / Finder',
                  onPressed: () => _revealInExplorer(job.finalOutputPath),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Remove',
                onPressed: () => queue.removeJob(job.id),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            targetName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Source: ${job.sourceFileName} (${(job.sourceSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB)',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: job.status == JobStatus.completed
                  ? 1.0
                  : (job.status == JobStatus.running ? job.progress : (job.status == JobStatus.queued ? null : 0.0)),
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          if (job.status == JobStatus.running) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Speed: ${job.speedRatio.toStringAsFixed(1)}x',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                Text(
                  job.estimatedRemainingSeconds > 0
                      ? 'ETA: ${job.estimatedRemainingSeconds}s remaining'
                      : 'Finalizing...',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ],
          if (job.status == JobStatus.failed && job.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              job.errorMessage!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
