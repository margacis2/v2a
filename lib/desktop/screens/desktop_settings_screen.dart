import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../../services/desktop_media_engine.dart';
import '../../services/output_manager.dart';

class DesktopSettingsScreen extends StatefulWidget {
  const DesktopSettingsScreen({super.key});

  @override
  State<DesktopSettingsScreen> createState() => _DesktopSettingsScreenState();
}

class _DesktopSettingsScreenState extends State<DesktopSettingsScreen> {
  final DesktopMediaEngine _engine = DesktopMediaEngine();
  final OutputManager _outputManager = OutputManager();

  String _outputDir = '';
  final TextEditingController _ffmpegController = TextEditingController();
  final TextEditingController _ffprobeController = TextEditingController();

  String _engineStatus = 'Detecting...';
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _ffmpegController.dispose();
    _ffprobeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final dir = await _outputManager.getActiveOutputDirectory();
    final version = await _engine.getVersion();

    if (mounted) {
      setState(() {
        _outputDir = dir.path;
        _engineStatus = version;
        _ffmpegController.text = _engine.ffmpegPath;
        _ffprobeController.text = _engine.ffprobePath;
      });
    }
  }

  Future<void> _pickOutputDir() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Default Audio Destination Folder',
      initialDirectory: _outputDir.isNotEmpty ? _outputDir : null,
    );
    if (path != null && mounted) {
      final success = await _outputManager.setCustomOutputDirectory(path);
      if (success) {
        if (!mounted) return;
        setState(() => _outputDir = path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Output directory updated successfully')),
        );
      }
    }
  }

  Future<void> _resetOutputDir() async {
    await _outputManager.resetToDefaultOutputDirectory();
    final defaultDir = await _outputManager.getActiveOutputDirectory();
    setState(() => _outputDir = defaultDir.path);
  }

  Future<void> _testAndSaveFfmpeg() async {
    setState(() => _isTesting = true);

    final ffmpegPath = _ffmpegController.text.trim();
    final ffprobePath = _ffprobeController.text.trim();

    if (ffmpegPath.isEmpty) {
      await _engine.clearCustomPaths();
    } else {
      await _engine.setCustomPaths(
        ffmpegPath: ffmpegPath,
        ffprobePath: ffprobePath.isNotEmpty ? ffprobePath : null,
      );
    }

    final version = await _engine.getVersion();
    final ready = _engine.isReady;

    if (mounted) {
      setState(() {
        _engineStatus = version;
        _isTesting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ready ? 'FFmpeg validated successfully!' : 'Failed to validate FFmpeg binary'),
          backgroundColor: ready ? const Color(0xFF10B981) : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appState = Provider.of<AppStateProvider>(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13151B) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Settings',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configure audio pipeline, storage destinations, and system preferences',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 28),

            // Storage Destination Section
            Text(
              'Default Output Destination',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
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
                  const Icon(Icons.folder_rounded, color: Color(0xFF2563EB), size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Destination Folder',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _outputDir,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _resetOutputDir,
                    child: const Text('Reset Default'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _pickOutputDir,
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('Change'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // FFmpeg Engine Configuration
            Text(
              'FFmpeg Core Engine',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
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
                  // Engine Status Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _engine.isReady
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _engine.isReady ? const Color(0xFF10B981) : Colors.orange,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _engine.isReady ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: _engine.isReady ? const Color(0xFF10B981) : Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _engine.isReady
                                    ? (_engine.engineMode == DesktopEngineMode.bundledComplete
                                        ? 'Complete Mode: Bundled FFmpeg Active'
                                        : 'Lite Mode: System PATH FFmpeg Active')
                                    : 'FFmpeg Unavailable',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _engineStatus,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Custom Path Inputs
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('FFmpeg Executable Path (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _ffmpegController,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'e.g. C:\\tools\\ffmpeg\\bin\\ffmpeg.exe',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF13151B) : const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('FFprobe Executable Path (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _ffprobeController,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'e.g. C:\\tools\\ffmpeg\\bin\\ffprobe.exe',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF13151B) : const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isTesting ? null : _testAndSaveFfmpeg,
                      icon: _isTesting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Test & Apply Executable'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Appearance Section
            Text(
              'Appearance',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
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
                  const Icon(Icons.palette_rounded, color: Color(0xFF8B5CF6), size: 28),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Theme Preference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 2),
                        Text('Choose between Dark, Light, or System styling', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {appState.themeMode},
                    onSelectionChanged: (set) {
                      appState.setThemeMode(set.first);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
