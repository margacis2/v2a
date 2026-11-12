import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../models/conversion_job.dart';
import '../../services/desktop_media_engine.dart';
import '../../services/job_queue_service.dart';

class DesktopHomeScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final ValueChanged<String>? onFileSelected;

  const DesktopHomeScreen({
    super.key,
    required this.onNavigate,
    this.onFileSelected,
  });

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

class _DesktopHomeScreenState extends State<DesktopHomeScreen> {
  final DesktopMediaEngine _engine = DesktopMediaEngine();
  String _ffmpegVersion = 'Detecting FFmpeg...';
  bool _isEngineReady = false;

  @override
  void initState() {
    super.initState();
    _checkEngine();
  }

  Future<void> _checkEngine() async {
    final ready = await _engine.initialize();
    final version = await _engine.getVersion();
    if (mounted) {
      setState(() {
        _isEngineReady = ready;
        _ffmpegVersion = version;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4', 'mkv', 'mov', 'avi', 'flv', 'wmv', 'webm', '3gp', 'm4v', 'ts', 'mts',
        'mp3', 'aac', 'm4a', 'wav', 'flac', 'ogg', 'opus',
      ],
    );

    if (result.isNotEmpty) {
      final path = result.first.path;
      if (path != null && mounted) {
        widget.onFileSelected?.call(path);
        widget.onNavigate(1); // Navigate to Convert screen
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final queue = Provider.of<JobQueueService>(context);

    final completedJobs = queue.jobs.where((j) => j.status == JobStatus.completed).length;
    final activeJobs = queue.jobs.where((j) => j.status == JobStatus.running || j.status == JobStatus.queued).length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13151B) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Welcome & Engine Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to V2A Studio',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'High-performance desktop video-to-audio converter and editor',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                // Engine pill
                Tooltip(
                  message: _ffmpegVersion,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isEngineReady
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isEngineReady ? const Color(0xFF10B981) : Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isEngineReady ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          size: 16,
                          color: _isEngineReady ? const Color(0xFF10B981) : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isEngineReady
                              ? (_engine.engineMode == DesktopEngineMode.bundledComplete
                                  ? 'Complete Mode (Bundled FFmpeg)'
                                  : 'Lite Mode (System FFmpeg)')
                              : 'FFmpeg Required',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isEngineReady ? const Color(0xFF10B981) : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Drop / Pick Media Big Action Card
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1E27) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.file_upload_outlined,
                          size: 36,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Choose a Video or Audio File to Convert',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supports MP4, MKV, MOV, WebM, AVI, FLV, TS, MP3, AAC, FLAC, WAV, and more',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Browse Files (Ctrl + O)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Stat Cards Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    icon: Icons.task_alt_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Completed Jobs',
                    value: '$completedJobs',
                    subtitle: 'Conversions finalized',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    icon: Icons.sync_rounded,
                    iconColor: const Color(0xFF2563EB),
                    title: 'Active / Queued',
                    value: '$activeJobs',
                    subtitle: 'Jobs in progress',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    icon: Icons.speed_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Engine Performance',
                    value: 'Hardware Accel',
                    subtitle: 'Mode A Stream Copy + Mode B',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Quick Studio Tools
            Text(
              'Studio Modules',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    context: context,
                    icon: Icons.swap_horiz_rounded,
                    color: const Color(0xFF2563EB),
                    title: 'Audio Converter',
                    description: '8 built-in studio presets, custom bitrates & EBU R128 loudness',
                    onTap: () => widget.onNavigate(1),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildActionTile(
                    context: context,
                    icon: Icons.content_cut_rounded,
                    color: const Color(0xFF06B6D4),
                    title: 'Audio Trimmer',
                    description: 'Visual waveform editor with ±1s, ±5s, ±1m precision nudge buttons',
                    onTap: () => widget.onNavigate(3),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildActionTile(
                    context: context,
                    icon: Icons.headphones_rounded,
                    color: const Color(0xFFEC4899),
                    title: 'Studio Player',
                    description: 'Integrated audio playback with speed controls 0.5x – 2.0x',
                    onTap: () => widget.onNavigate(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1E27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1E27) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
