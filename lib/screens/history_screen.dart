import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/conversion_job.dart';
import '../services/audio_player_service.dart';
import '../services/database_service.dart';
import '../services/feedback_service.dart';
import '../utils/app_transitions.dart';
import 'audio_player_screen.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  List<ConversionJob> _allHistory = [];
  List<ConversionJob> _filteredHistory = [];
  String _selectedFormatFilter = 'ALL';
  bool _isLoading = true;

  // Priority 2: Selection Mode State
  bool _isSelectionMode = false;
  final Set<String> _selectedJobIds = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await _db.getHistory();
    if (mounted) {
      setState(() {
        _allHistory = history;
        _applyFilter();
        _isLoading = false;
        // Prune any selections that no longer exist
        _selectedJobIds.removeWhere((id) => !_allHistory.any((j) => j.id == id));
        if (_selectedJobIds.isEmpty && _isSelectionMode) {
          _isSelectionMode = false;
        }
      });
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredHistory = _allHistory.where((job) {
        final matchesQuery = query.isEmpty ||
            job.requestedFileName.toLowerCase().contains(query) ||
            job.sourceFileName.toLowerCase().contains(query);

        final matchesFormat = _selectedFormatFilter == 'ALL' ||
            job.format.extension.toUpperCase() == _selectedFormatFilter;

        return matchesQuery && matchesFormat;
      }).toList();
    });
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

  void _selectAll() {
    setState(() {
      if (_selectedJobIds.length == _filteredHistory.length) {
        _selectedJobIds.clear();
      } else {
        _selectedJobIds.addAll(_filteredHistory.map((j) => j.id));
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedJobIds.clear();
    });
  }

  void _playAudio(ConversionJob job) async {
    final file = File(job.finalOutputPath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found on storage')),
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

  // Priority 2.B: Multi-select Confirmation Dialog
  void _confirmDeleteSelected() {
    final selectedJobs = _allHistory.where((j) => _selectedJobIds.contains(j.id)).toList();
    if (selectedJobs.isEmpty) return;

    bool deletePhysicalFiles = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dContext, setDialogState) {
            return AlertDialog(
              title: Text('Delete ${selectedJobs.length} Selected Item(s)?'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'The following files will be removed from conversion history:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ...selectedJobs.take(5).map(
                            (j) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.audiotrack, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      j.requestedFileName,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      if (selectedJobs.length > 5)
                        Text(
                          '...and ${selectedJobs.length - 5} more file(s)',
                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Also delete physical audio files from storage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Irreversible. The audio files will be permanently erased.', style: TextStyle(fontSize: 10, color: Colors.red)),
                        value: deletePhysicalFiles,
                        onChanged: (val) {
                          setDialogState(() {
                            deletePhysicalFiles = val ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    int count = 0;
                    for (final job in selectedJobs) {
                      if (deletePhysicalFiles) {
                        try {
                          final file = File(job.finalOutputPath);
                          if (await file.exists()) {
                            await file.delete();
                          }
                        } catch (_) {}
                      }
                      await _db.deleteJob(job.id);
                      count++;
                    }

                    _exitSelectionMode();
                    await _loadHistory();

                    if (mounted) {
                      FeedbackService().notifyFileDeleted(
                        context,
                        count: count,
                        description: deletePhysicalFiles
                            ? '$count audio file(s) & record(s) deleted permanently'
                            : '$count record(s) removed from history',
                      );
                    }
                  },
                  child: Text(deletePhysicalFiles ? 'Delete Files' : 'Remove Records'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Priority 2.D: Explicit Safe Delete All Dialog
  void _confirmDeleteAll() {
    bool deletePhysicalFiles = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dContext, setDialogState) {
            return AlertDialog(
              title: const Text('Clear All Conversion History?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will remove all ${_allHistory.length} completed conversion records from V2A history.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Also delete all generated audio files from storage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Permanent deletion of generated audio files.', style: TextStyle(fontSize: 10, color: Colors.red)),
                    value: deletePhysicalFiles,
                    onChanged: (val) {
                      setDialogState(() {
                        deletePhysicalFiles = val ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();

                    if (deletePhysicalFiles) {
                      for (final job in _allHistory) {
                        try {
                          final file = File(job.finalOutputPath);
                          if (await file.exists()) {
                            await file.delete();
                          }
                        } catch (_) {}
                      }
                    }

                    await _db.clearCompletedHistory();
                    _exitSelectionMode();
                    await _loadHistory();

                    if (mounted) {
                      FeedbackService().notifyFileDeleted(
                        context,
                        count: _allHistory.length,
                        description: deletePhysicalFiles
                            ? 'All history records and audio files were deleted'
                            : 'All history records cleared',
                      );
                    }
                  },
                  child: const Text('Confirm Clear All'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSingleDeleteDialog(ConversionJob job) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Record or File?'),
          content: Text('Choose whether to remove "${job.requestedFileName}" from conversion history only, or delete the physical audio file permanently.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _db.deleteJob(job.id);
                _loadHistory();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  FeedbackService().notifyFileDeleted(context, count: 1, description: 'Record removed from history');
                }
              },
              child: const Text('Remove from History'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                final file = File(job.finalOutputPath);
                if (await file.exists()) {
                  await file.delete();
                }
                await _db.deleteJob(job.id);
                _loadHistory();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  FeedbackService().notifyFileDeleted(context, count: 1, description: 'Audio file deleted permanently');
                }
              },
              child: const Text('Delete File'),
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
          _isSelectionMode ? '${_selectedJobIds.length} Selected' : 'Conversion History',
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(
                _selectedJobIds.length == _filteredHistory.length && _filteredHistory.isNotEmpty
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
              ),
              tooltip: _selectedJobIds.length == _filteredHistory.length ? 'Deselect All' : 'Select All',
              onPressed: _filteredHistory.isNotEmpty ? _selectAll : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              tooltip: 'Delete Selected',
              onPressed: _selectedJobIds.isEmpty ? null : _confirmDeleteSelected,
            ),
          ] else ...[
            if (_filteredHistory.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.checklist_rounded),
                tooltip: 'Select Multiple',
                onPressed: () {
                  setState(() => _isSelectionMode = true);
                },
              ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _loadHistory,
            ),
            if (_allHistory.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                tooltip: 'Clear All History',
                onPressed: _confirmDeleteAll,
              ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversions...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilter();
                        },
                      )
                    : null,
                isDense: true,
              ),
              onChanged: (_) => _applyFilter(),
            ),
          ),

          // Format Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                'ALL',
                'MP3',
                'M4A',
                'AAC',
                'WAV',
                'FLAC',
                'OGG',
                'OPUS',
              ].map((fmt) {
                final isSelected = _selectedFormatFilter == fmt;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(fmt, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      setState(() {
                        _selectedFormatFilter = fmt;
                        _applyFilter();
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 4),

          // Main History List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'No conversion records found',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredHistory.length,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemBuilder: (context, index) {
                          final job = _filteredHistory[index];
                          final isSelected = _selectedJobIds.contains(job.id);

                          return Card(
                            color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.15) : null,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(job.id);
                                } else {
                                  _playAudio(job);
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
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
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
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.audiotrack_rounded,
                                          color: theme.colorScheme.primary,
                                          size: 24,
                                        ),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            job.requestedFileName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${job.format.label} • ${job.formattedOutputSize} • ${job.speedRatio.toStringAsFixed(1)}x speed',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            job.completedAt != null
                                                ? '${job.completedAt!.day}/${job.completedAt!.month}/${job.completedAt!.year} ${job.completedAt!.hour.toString().padLeft(2, '0')}:${job.completedAt!.minute.toString().padLeft(2, '0')}'
                                                : '',
                                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_isSelectionMode) ...[
                                      IconButton(
                                        icon: const Icon(Icons.play_circle_fill_rounded, size: 28),
                                        color: theme.colorScheme.primary,
                                        onPressed: () => _playAudio(job),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (val) {
                                          if (val == 'details') {
                                            Navigator.of(context).push(
                                              AppTransitions.slideFadeRoute(ResultScreen(job: job)),
                                            );
                                          } else if (val == 'share') {
                                            SharePlus.instance.share(ShareParams(files: [XFile(job.finalOutputPath)], text: job.requestedFileName));
                                          } else if (val == 'open') {
                                            OpenFilex.open(job.finalOutputPath);
                                          } else if (val == 'delete') {
                                            _showSingleDeleteDialog(job);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(value: 'details', child: Text('View Details')),
                                          const PopupMenuItem(value: 'share', child: Text('Share')),
                                          const PopupMenuItem(value: 'open', child: Text('Open With')),
                                          const PopupMenuDivider(),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete / Remove', style: TextStyle(color: Colors.red)),
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
}
