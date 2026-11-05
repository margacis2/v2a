import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversion_config.dart';
import '../models/conversion_job.dart';
import '../providers/app_state_provider.dart';
import '../services/audio_player_service.dart';
import '../services/database_service.dart';
import '../services/job_queue_service.dart';
import '../utils/app_transitions.dart';
import '../widgets/v2a_logo_widget.dart';
import 'active_jobs_screen.dart';
import 'audio_player_screen.dart';
import 'file_picker_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'standalone_trimmer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  List<ConversionJob> _recentConversions = [];
  bool _isLoadingRecents = true;

  @override
  void dispose() {
    try {
      Provider.of<AppStateProvider>(context, listen: false).stopPerformanceMonitoring();
    } catch (_) {}
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadRecents();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AppStateProvider>(context, listen: false).startPerformanceMonitoring();
      }
    });
  }

  Future<void> _loadRecents() async {
    setState(() => _isLoadingRecents = true);
    final history = await _db.getHistory();
    if (mounted) {
      setState(() {
        _recentConversions = history.take(5).toList();
        _isLoadingRecents = false;
      });
    }
  }

  void _openFilePicker({required bool isBatch}) {
    Navigator.of(context).push(
      AppTransitions.slideFadeRoute(FilePickerScreen(isBatchMode: isBatch)),
    ).then((_) => _loadRecents());
  }

  void _playAudio(ConversionJob job) async {
    final file = File(job.finalOutputPath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio file no longer exists at original location')),
        );
      }
      return;
    }

    final audioService = AudioPlayerService();
    final ok = await audioService.playSingleFile(job.finalOutputPath);
    if (ok && mounted) {
      Navigator.of(context).push(
        AppTransitions.slideFadeRoute(AudioPlayerScreen(filePath: job.finalOutputPath)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appState = Provider.of<AppStateProvider>(context);
    final queueService = Provider.of<JobQueueService>(context);
    final stats = appState.performanceStats;

    return Scaffold(
      appBar: AppBar(
        title: const V2ALogo(size: 32, showText: true),
        actions: [
          // Active Queue Badge Icon
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.playlist_play_rounded),
                tooltip: 'Active Queue',
                onPressed: () {
                  Navigator.of(context).push(
                    AppTransitions.slideFadeRoute(const ActiveJobsScreen()),
                  ).then((_) => _loadRecents());
                },
              ),
              if (queueService.activeJobCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${queueService.activeJobCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () {
              Navigator.of(context).push(
                AppTransitions.slideFadeRoute(const HistoryScreen()),
              ).then((_) => _loadRecents());
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                AppTransitions.slideFadeRoute(const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active Conversion Alert Banner
              if (queueService.isProcessing && queueService.activeJob != null) ...[
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      AppTransitions.slideFadeRoute(const ActiveJobsScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Converting: ${queueService.activeJob!.requestedFileName}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(queueService.activeJob!.progress * 100).toStringAsFixed(0)}% • ${queueService.activeJob!.speedRatio.toStringAsFixed(1)}x speed',
                                style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Hardware Performance Strip (Priority 1: Overflow Proof Wrap)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.memory_rounded, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'RAM: ${stats.appRamFormatted}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'FFmpeg Ready',
                          style: TextStyle(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Cards: Responsive Layout (Priority 1 & 3: Standalone Audio Trimmer Added)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isVeryNarrow = constraints.maxWidth < 340;
                  if (isVeryNarrow) {
                    return Column(
                      children: [
                        _buildActionCard(
                          theme: theme,
                          icon: Icons.video_library_rounded,
                          title: 'Extract Audio',
                          subtitle: 'Single video with preview & track selector',
                          color: theme.colorScheme.primary,
                          onTap: () => _openFilePicker(isBatch: false),
                        ),
                        const SizedBox(height: 10),
                        _buildActionCard(
                          theme: theme,
                          icon: Icons.auto_awesome_motion_rounded,
                          title: 'Batch Convert',
                          subtitle: 'Process multiple videos in background queue',
                          color: const Color(0xFF00ACC1),
                          onTap: () => _openFilePicker(isBatch: true),
                        ),
                        const SizedBox(height: 10),
                        _buildActionCard(
                          theme: theme,
                          icon: Icons.content_cut_rounded,
                          title: 'Audio Trimmer',
                          subtitle: 'Trim existing audio with real waveform & playback',
                          color: const Color(0xFFE65100),
                          onTap: () {
                            Navigator.of(context).push(
                              AppTransitions.slideFadeRoute(const StandaloneTrimmerScreen()),
                            ).then((_) => _loadRecents());
                          },
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              theme: theme,
                              icon: Icons.video_library_rounded,
                              title: 'Extract Audio',
                              subtitle: 'Single video with preview & track selector',
                              color: theme.colorScheme.primary,
                              onTap: () => _openFilePicker(isBatch: false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              theme: theme,
                              icon: Icons.auto_awesome_motion_rounded,
                              title: 'Batch Convert',
                              subtitle: 'Process multiple videos in background queue',
                              color: const Color(0xFF00ACC1),
                              onTap: () => _openFilePicker(isBatch: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildActionCard(
                        theme: theme,
                        icon: Icons.content_cut_rounded,
                        title: 'Audio Trimmer',
                        subtitle: 'Trim existing audio files with real waveform visualizer & playback',
                        color: const Color(0xFFE65100),
                        onTap: () {
                          Navigator.of(context).push(
                            AppTransitions.slideFadeRoute(const StandaloneTrimmerScreen()),
                          ).then((_) => _loadRecents());
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              // Quick Presets Bar (Priority 4: All 8 Presets)
              Text(
                'Instant Presets',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ConversionPreset.values
                      .where((p) => p != ConversionPreset.custom)
                      .map((preset) => _presetChip(preset, theme))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Recent Conversions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Recent Conversions',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_recentConversions.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          AppTransitions.slideFadeRoute(const HistoryScreen()),
                        ).then((_) => _loadRecents());
                      },
                      child: const Text('View All'),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Recent Conversions List
              if (_isLoadingRecents)
                const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
              else if (_recentConversions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E222A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.audiotrack_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text(
                        'No conversions yet',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap "Extract Audio" or "Batch Convert" to select your first video.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: _recentConversions.map((job) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.music_note_rounded, color: theme.colorScheme.primary, size: 22),
                        ),
                        title: Text(
                          job.requestedFileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${job.format.label} • ${job.formattedOutputSize}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_circle_fill_rounded, size: 28),
                          color: theme.colorScheme.primary,
                          onPressed: () => _playAudio(job),
                        ),
                        onTap: () => _playAudio(job),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(ConversionPreset preset, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(_presetIcon(preset), size: 14, color: theme.colorScheme.primary),
        label: Text(preset.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        onPressed: () {
          // Open FilePicker to immediately use this preset
          _openFilePicker(isBatch: false);
        },
      ),
    );
  }

  IconData _presetIcon(ConversionPreset preset) {
    switch (preset) {
      case ConversionPreset.fastestCompatible:
        return Icons.bolt_rounded;
      case ConversionPreset.balanced:
        return Icons.balance_rounded;
      case ConversionPreset.bestQuality:
        return Icons.diamond_rounded;
      case ConversionPreset.smallestPractical:
        return Icons.folder_zip_rounded;
      case ConversionPreset.voiceSpeech:
        return Icons.record_voice_over_rounded;
      case ConversionPreset.music:
        return Icons.music_note_rounded;
      case ConversionPreset.losslessMaster:
        return Icons.album_rounded;
      case ConversionPreset.maxCompression:
        return Icons.compress_rounded;
      case ConversionPreset.custom:
        return Icons.tune_rounded;
    }
  }
}
