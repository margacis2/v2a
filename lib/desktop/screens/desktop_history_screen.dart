import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/conversion_job.dart';
import '../../services/database_service.dart';

class DesktopHistoryScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final ValueChanged<String>? onPlayFile;
  final ValueChanged<String>? onReconvertFile;

  const DesktopHistoryScreen({
    super.key,
    required this.onNavigate,
    this.onPlayFile,
    this.onReconvertFile,
  });

  @override
  State<DesktopHistoryScreen> createState() => _DesktopHistoryScreenState();
}

class _DesktopHistoryScreenState extends State<DesktopHistoryScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<ConversionJob> _allJobs = [];
  List<ConversionJob> _filteredJobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchController.addListener(_filterJobs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final jobs = await _db.getAllJobs();
    if (mounted) {
      setState(() {
        _allJobs = jobs;
        _filterJobs();
        _isLoading = false;
      });
    }
  }

  void _filterJobs() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredJobs = List.from(_allJobs);
      } else {
        _filteredJobs = _allJobs.where((j) {
          return j.requestedFileName.toLowerCase().contains(query) ||
              j.sourceFileName.toLowerCase().contains(query) ||
              j.preset.name.toLowerCase().contains(query) ||
              j.format.label.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _revealInExplorer(String filePath) {
    if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [File(filePath).parent.path]);
    }
  }

  Future<void> _deleteJob(ConversionJob job) async {
    await _db.deleteJob(job.id);
    _loadHistory();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Conversion History?'),
        content: const Text('This will clear the history log. Your exported audio files will not be deleted from disk.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.clearCompletedHistory();
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13151B) : const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conversion History',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete SQLite journal of all audio exports and jobs',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _allJobs.isNotEmpty ? _clearAll : null,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('Clear History'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _loadHistory,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by file name, format, or preset...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1A1E27) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // History Records Table / List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredJobs.isEmpty
                      ? Center(
                          child: Text(
                            _allJobs.isEmpty ? 'No conversions logged yet' : 'No matching results',
                            style: TextStyle(color: Colors.grey[500], fontSize: 14),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1E27) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ListView.separated(
                              itemCount: _filteredJobs.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final job = _filteredJobs[index];
                                final hasFile = job.finalOutputPath.isNotEmpty &&
                                    File(job.finalOutputPath).existsSync();
                                final targetDisplay = '${job.requestedFileName}.${job.format.extension}';

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.audio_file_rounded, color: Color(0xFF2563EB)),
                                  ),
                                  title: Text(
                                    targetDisplay,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    '${job.preset.name} • ${job.format.label.toUpperCase()} • ${job.bitrateKbps}k • ${job.sampleRateHz} Hz\nSource: ${job.sourceFileName}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (hasFile) ...[
                                        IconButton(
                                          icon: const Icon(Icons.folder_open_rounded, color: Color(0xFF2563EB)),
                                          tooltip: 'Show in File Explorer',
                                          onPressed: () => _revealInExplorer(job.finalOutputPath),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF10B981)),
                                          tooltip: 'Play in Studio Player',
                                          onPressed: () {
                                            widget.onPlayFile?.call(job.finalOutputPath);
                                            widget.onNavigate(4); // Jump to Player
                                          },
                                        ),
                                      ],
                                      IconButton(
                                        icon: const Icon(Icons.replay_rounded),
                                        tooltip: 'Reconvert Source',
                                        onPressed: () {
                                          widget.onReconvertFile?.call(job.sourcePath);
                                          widget.onNavigate(1); // Jump to Convert
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
                                        tooltip: 'Delete Log',
                                        onPressed: () => _deleteJob(job),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
