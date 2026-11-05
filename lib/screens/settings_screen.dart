import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/conversion_config.dart';
import '../providers/app_state_provider.dart';
import '../services/feedback_service.dart';
import '../services/output_manager.dart';
import '../services/storage_service.dart';
import '../utils/app_transitions.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentOutputDir = '';
  DeviceStorageInfo? _deviceStorage;
  FolderStorageInfo? _v2aFolderStorage;
  bool _isLoadingStorage = true;
  String? _storageError;

  @override
  void initState() {
    super.initState();
    _loadStorageStats();
  }

  Future<void> _loadStorageStats() async {
    setState(() {
      _isLoadingStorage = true;
      _storageError = null;
    });

    try {
      final dir = await OutputManager().getActiveOutputDirectory();
      _currentOutputDir = dir.path;

      final deviceStats = await StorageService().getDeviceStorageInfo(customPath: _currentOutputDir);
      final folderStats = await StorageService().getFolderStorageInfo(_currentOutputDir);

      if (mounted) {
        setState(() {
          _deviceStorage = deviceStats;
          _v2aFolderStorage = folderStats;
          _isLoadingStorage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _storageError = 'Unable to query storage statistics: $e';
          _isLoadingStorage = false;
        });
      }
    }
  }

  Future<void> _changeFolder() async {
    try {
      final selectedPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select V2A Audio Output Directory',
      );

      if (selectedPath != null && selectedPath.isNotEmpty) {
        final success = await OutputManager().setCustomOutputDirectory(selectedPath);
        if (success) {
          await _loadStorageStats();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Save location updated to: $selectedPath')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selected folder is not writable. Please choose another location.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select folder: $e')),
        );
      }
    }
  }

  Future<void> _resetToDefaultFolder() async {
    await OutputManager().resetToDefaultOutputDirectory();
    await _loadStorageStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset to standard public V2A folder.')),
      );
    }
  }

  Future<void> _openOutputFolder() async {
    if (_currentOutputDir.isNotEmpty) {
      final dir = Directory(_currentOutputDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await OpenFilex.open(_currentOutputDir);
    }
  }

  Future<void> _cleanupStorage(BuildContext context) async {
    final deletedTemps = await OutputManager().cleanupAbandonedTempFiles(_currentOutputDir);

    try {
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        final list = cacheDir.listSync(recursive: true);
        for (final item in list) {
          if (item is File && item.path.contains('v2a_thumbnails')) {
            try {
              await item.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleaned cache and removed $deletedTemps abandoned temporary file(s).')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appState = Provider.of<AppStateProvider>(context);
    final stats = appState.performanceStats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Diagnostics'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Priority 1: Real-time Device & Output Storage Overview
          _buildSectionHeader('Device Storage & Capacity', theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storage_rounded, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Internal Storage Statistics',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        tooltip: 'Refresh Storage',
                        visualDensity: VisualDensity.compact,
                        onPressed: _isLoadingStorage ? null : _loadStorageStats,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingStorage) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Querying storage capacity...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ] else if (_storageError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_storageError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                    ),
                  ] else if (_deviceStorage != null) ...[
                    // Progress Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_deviceStorage!.usedFormatted} used of ${_deviceStorage!.totalFormatted}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${_deviceStorage!.usedPercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _deviceStorage!.usedPercentage > 85 ? Colors.red : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (_deviceStorage!.usedPercentage / 100.0).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _deviceStorage!.usedPercentage > 85
                              ? Colors.red
                              : (_deviceStorage!.usedPercentage > 70 ? Colors.orange : theme.colorScheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _diagRow('Total Capacity', _deviceStorage!.totalFormatted),
                    const Divider(height: 10),
                    _diagRow('Used Space', _deviceStorage!.usedFormatted),
                    const Divider(height: 10),
                    _diagRow('Available Space', _deviceStorage!.availableFormatted),
                    const Divider(height: 10),
                    _diagRow(
                      'V2A Audio Files Usage',
                      _v2aFolderStorage != null
                          ? '${_v2aFolderStorage!.sizeFormatted} (${_v2aFolderStorage!.fileCount} files)'
                          : 'Calculating...',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Priority 6: Default Save Location Management
          _buildSectionHeader('Storage & Save Location', theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_special_rounded, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Default Save Location',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF252B36) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Output Folder:',
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentOutputDir.isNotEmpty ? _currentOutputDir : 'Resolving V2A directory...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.drive_folder_upload_rounded, size: 16),
                        label: const Text('Change Folder', style: TextStyle(fontSize: 12)),
                        onPressed: _changeFolder,
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: const Text('Reset to Default', style: TextStyle(fontSize: 12)),
                        onPressed: _resetToDefaultFolder,
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: const Text('Open Folder', style: TextStyle(fontSize: 12)),
                        onPressed: _openOutputFolder,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Priority 5: Effects & Haptics Section
          _buildSectionHeader('Effects & Haptics', theme),
          Card(
            child: Consumer<FeedbackService>(
              builder: (context, feedback, child) {
                return Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary),
                      title: const Text('Visual Effects', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Floating banners and completion feedback', style: TextStyle(fontSize: 12)),
                      value: feedback.visualEffectsEnabled,
                      onChanged: (val) => feedback.setVisualEffectsEnabled(val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: Icon(Icons.vibration_rounded, color: theme.colorScheme.primary),
                      title: const Text('Vibration / Haptics', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Tactile response on conversion finish and deletion', style: TextStyle(fontSize: 12)),
                      value: feedback.hapticsEnabled,
                      onChanged: (val) => feedback.setHapticsEnabled(val),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Appearance Section
          _buildSectionHeader('Appearance & Theme', theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text('System', style: TextStyle(fontSize: 12)), icon: Icon(Icons.brightness_auto, size: 16)),
                        ButtonSegment(value: ThemeMode.light, label: Text('Light', style: TextStyle(fontSize: 12)), icon: Icon(Icons.light_mode, size: 16)),
                        ButtonSegment(value: ThemeMode.dark, label: Text('Dark', style: TextStyle(fontSize: 12)), icon: Icon(Icons.dark_mode, size: 16)),
                      ],
                      selected: {appState.themeMode},
                      onSelectionChanged: (set) {
                        if (set.isNotEmpty) appState.setThemeMode(set.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Defaults Section
          _buildSectionHeader('Conversion Defaults', theme),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Default Audio Format', style: TextStyle(fontSize: 14)),
                  subtitle: Text(appState.defaultFormat.label, style: const TextStyle(fontSize: 12)),
                  trailing: DropdownButton<AudioFormat>(
                    value: appState.defaultFormat,
                    underline: const SizedBox(),
                    items: AudioFormat.values.map((f) {
                      return DropdownMenuItem(value: f, child: Text(f.extension.toUpperCase(), style: const TextStyle(fontSize: 13)));
                    }).toList(),
                    onChanged: (f) {
                      if (f != null) appState.setDefaultFormat(f);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Default Bitrate', style: TextStyle(fontSize: 14)),
                  subtitle: Text('${appState.defaultBitrate} kbps', style: const TextStyle(fontSize: 12)),
                  trailing: Builder(
                    builder: (context) {
                      final bitrates = [64, 96, 128, 160, 192, 256, 320];
                      if (!bitrates.contains(appState.defaultBitrate)) {
                        bitrates.add(appState.defaultBitrate);
                        bitrates.sort();
                      }
                      return DropdownButton<int>(
                        value: appState.defaultBitrate,
                        underline: const SizedBox(),
                        items: bitrates.map((b) {
                          return DropdownMenuItem(value: b, child: Text('$b kbps', style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (b) {
                          if (b != null) appState.setDefaultBitrate(b);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Hardware & RAM Diagnostics (Priority 1: Overflow Proof)
          _buildSectionHeader('Hardware & Memory Diagnostics', theme),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _diagRow('App Process RAM', stats.appRamFormatted),
                  const Divider(height: 12),
                  _diagRow('Total Physical RAM', '${stats.totalPhysicalRamMb.toStringAsFixed(0)} MB'),
                  const Divider(height: 12),
                  _diagRow('Available Free RAM', '${stats.availablePhysicalRamMb.toStringAsFixed(0)} MB'),
                  const Divider(height: 12),
                  _diagRow('System RAM Load', '${stats.systemRamUsagePercent.toStringAsFixed(1)}%'),
                  const Divider(height: 12),
                  _diagRow('Thermal State', stats.thermalStatus),
                  const Divider(height: 12),
                  _diagRow('Operating System', '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Storage & Cache Maintenance
          _buildSectionHeader('Storage Maintenance', theme),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: Colors.orange),
                  title: const Text('Clean Cache & Temp Files', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Deletes cached thumbnails and abandoned partial files', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _cleanupStorage(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded, color: Colors.blue),
                  title: const Text('Replay First-Launch Tutorial', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('View the 5-step interactive walkthrough', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      AppTransitions.slideFadeRoute(const OnboardingScreen(isReplay: true)),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // About & Legal
          _buildSectionHeader('About V2A', theme),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.verified_rounded, color: Colors.green),
                  title: Text('V2A Audio Converter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text('Version 1.0.0 • Professional Edition', style: TextStyle(fontSize: 12)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Open Source Licenses', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('FFmpeg, ExoPlayer, Flutter, SQLite', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(context: context, applicationName: 'V2A Audio Converter'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
      ),
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
