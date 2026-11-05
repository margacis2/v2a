import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../services/media_metadata_service.dart';
import '../utils/app_transitions.dart';
import 'conversion_settings_screen.dart';
import 'video_preview_screen.dart';

class FilePickerScreen extends StatefulWidget {
  final bool isBatchMode;

  const FilePickerScreen({super.key, this.isBatchMode = false});

  @override
  State<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends State<FilePickerScreen> {
  final List<MediaFile> _loadedFiles = [];
  bool _isLoading = false;
  String _loadingMessage = '';
  String _sortBy = 'name'; // 'name', 'size', 'duration'
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickFiles();
    });
  }

  Future<void> _pickFiles() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Opening media picker...';
    });

    try {
      const allowedExts = [
        'mp4',
        'mkv',
        'mov',
        'webm',
        'avi',
        'flv',
        '3gp',
        'mpeg',
        'ts',
        'm4v',
        'mp3',
        'aac',
        'm4a',
        'wav',
        'flac',
        'ogg',
        'opus',
      ];

      List<PlatformFile> pickedFiles = [];
      if (widget.isBatchMode) {
        pickedFiles = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: allowedExts,
        );
      } else {
        final single = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: allowedExts,
        );
        if (single != null) {
          pickedFiles = [single];
        }
      }

      if (pickedFiles.isNotEmpty) {
        final metaService = MediaMetadataService();
        final newFiles = <MediaFile>[];

        for (int i = 0; i < pickedFiles.length; i++) {
          final file = pickedFiles[i];
          if (file.path != null) {
            setState(() {
              _loadingMessage = 'Analyzing file ${i + 1} of ${pickedFiles.length} (${file.name})...';
            });
            final analyzed = await metaService.analyzeMediaFile(file.path!);
            newFiles.add(analyzed);
          }
        }

        setState(() {
          _loadedFiles.addAll(newFiles);
          _applySort();
        });

        // If single file mode and exactly 1 file was picked, navigate smoothly to preview
        if (!widget.isBatchMode && _loadedFiles.length == 1 && mounted) {
          final first = _loadedFiles.first;
          if (!first.isCorrupted) {
            Navigator.of(context).pushReplacement(
              AppTransitions.slideFadeRoute(VideoPreviewScreen(mediaFile: first)),
            );
            return;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });
      }
    }
  }

  void _applySort() {
    setState(() {
      _loadedFiles.sort((a, b) {
        int cmp = 0;
        if (_sortBy == 'name') {
          cmp = a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
        } else if (_sortBy == 'size') {
          cmp = a.sizeBytes.compareTo(b.sizeBytes);
        } else if (_sortBy == 'duration') {
          cmp = a.duration.compareTo(b.duration);
        }
        return _sortAscending ? cmp : -cmp;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBatchMode ? 'Batch Selection (${_loadedFiles.length})' : 'Select Video'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Add More Files',
            onPressed: _pickFiles,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort By',
            onSelected: (val) {
              setState(() {
                if (_sortBy == val) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = val;
                  _sortAscending = true;
                }
                _applySort();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'name', child: Text('Sort by Name ${_sortBy == 'name' ? (_sortAscending ? '▲' : '▼') : ''}')),
              PopupMenuItem(value: 'size', child: Text('Sort by Size ${_sortBy == 'size' ? (_sortAscending ? '▲' : '▼') : ''}')),
              PopupMenuItem(value: 'duration', child: Text('Sort by Duration ${_sortBy == 'duration' ? (_sortAscending ? '▲' : '▼') : ''}')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_loadingMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            )
          : _loadedFiles.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library_outlined, size: 72, color: Colors.grey.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        const Text('No media selected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          'Choose video or audio files from your device storage or SD card',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.folder_open_rounded),
                          label: const Text('Browse Files'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _loadedFiles.length,
                  itemBuilder: (context, index) {
                    final item = _loadedFiles[index];
                    final hasThumbnail = item.thumbnailPath != null && File(item.thumbnailPath!).existsSync();

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (item.isCorrupted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invalid file: ${item.validationError}')),
                            );
                            return;
                          }
                          // Open Preview Screen
                          Navigator.of(context).push(
                            AppTransitions.slideFadeRoute(VideoPreviewScreen(mediaFile: item)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Row(
                            children: [
                              // Thumbnail or Icon
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  color: isDark ? const Color(0xFF252B36) : const Color(0xFFE5E7EB),
                                  child: hasThumbnail
                                      ? Image.file(File(item.thumbnailPath!), fit: BoxFit.cover)
                                      : Icon(
                                          item.hasAudio ? Icons.video_file_rounded : Icons.broken_image_rounded,
                                          size: 30,
                                          color: item.hasAudio ? theme.colorScheme.primary : Colors.grey,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Info Column (Responsive with no overflow)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${item.formattedDuration} • ${item.formattedSize} • ${item.extension.toUpperCase().replaceAll('.', '')}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    if (item.validationError != null)
                                      Text(
                                        item.validationError!,
                                        style: const TextStyle(color: Colors.red, fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    else if (item.audioTracks.isNotEmpty)
                                      Text(
                                        '${item.audioTracks.length} audio track${item.audioTracks.length > 1 ? "s" : ""} • ${item.audioTracks.first.codec.toUpperCase()}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),

                              // Action Icon
                              IconButton(
                                icon: const Icon(Icons.play_circle_outline_rounded),
                                tooltip: 'Preview Video',
                                onPressed: () {
                                  Navigator.of(context).push(
                                    AppTransitions.slideFadeRoute(VideoPreviewScreen(mediaFile: item)),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: widget.isBatchMode && _loadedFiles.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Priority 2 Fix: Pass ALL loadedFiles to ConversionSettingsScreen!
                    Navigator.of(context).push(
                      AppTransitions.slideFadeRoute(
                        ConversionSettingsScreen(batchFiles: _loadedFiles),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text('Configure Batch (${_loadedFiles.length} files)'),
                ),
              ),
            )
          : null,
    );
  }
}
