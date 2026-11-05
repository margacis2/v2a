import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/conversion_job.dart';
import '../services/audio_player_service.dart';
import '../utils/app_transitions.dart';
import 'audio_player_screen.dart';
import 'home_screen.dart';

class ResultScreen extends StatelessWidget {
  final ConversionJob job;

  const ResultScreen({super.key, required this.job});

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(2)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  void _playAudio(BuildContext context) async {
    final file = File(job.finalOutputPath);
    if (!await file.exists() || await file.length() == 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Converted audio file is missing or unreadable.')),
        );
      }
      return;
    }

    final audioService = AudioPlayerService();
    final success = await audioService.playSingleFile(job.finalOutputPath);

    if (success && context.mounted) {
      Navigator.of(context).push(
        AppTransitions.slideFadeRoute(
          AudioPlayerScreen(filePath: job.finalOutputPath),
        ),
      );
    }
  }

  void _shareAudio() async {
    final file = File(job.finalOutputPath);
    if (await file.exists()) {
      await SharePlus.instance.share(ShareParams(files: [XFile(job.finalOutputPath)], text: 'Converted audio: ${job.requestedFileName}'));
    }
  }

  void _openExternally() async {
    final file = File(job.finalOutputPath);
    if (await file.exists()) {
      await OpenFilex.open(job.finalOutputPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final spaceSavedBytes = (job.sourceSizeBytes - job.outputSizeBytes).clamp(0, job.sourceSizeBytes);
    final spaceSavedPercent = job.sourceSizeBytes > 0
        ? ((spaceSavedBytes / job.sourceSizeBytes) * 100).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversion Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success Card Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Audio Extraction Complete!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    job.requestedFileName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Metrics Summary Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: Icons.audio_file_rounded,
                    label: 'Format',
                    value: job.format.label,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: Icons.timer_rounded,
                    label: 'Duration',
                    value: _formatDuration(job.sourceDurationMs),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: Icons.straighten_rounded,
                    label: 'Output Size',
                    value: job.formattedOutputSize,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: Icons.pie_chart_rounded,
                    label: 'Space Saved',
                    value: '$spaceSavedPercent%',
                    valueColor: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Conversion Stats Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Conversion Summary', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildRow('Source File', job.sourceFileName),
                    _buildRow('Source Size', _formatBytes(job.sourceSizeBytes)),
                    _buildRow('Conversion Mode', job.mode.title),
                    _buildRow('Average Speed', '${job.speedRatio.toStringAsFixed(1)}x Realtime'),
                    _buildRow('Processing Time', '${job.elapsedSeconds} seconds'),
                    _buildRow('Saved Location', job.finalOutputPath, isPath: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Primary Play Audio Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _playAudio(context),
                icon: const Icon(Icons.play_circle_fill_rounded, size: 24),
                label: const Text('Play Audio Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareAudio,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openExternally,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open In...'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.home_rounded),
              label: const Text('Return to Home'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isPath = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12, fontWeight: isPath ? FontWeight.normal : FontWeight.w600),
              maxLines: isPath ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
