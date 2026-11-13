import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/desktop_media_engine.dart';

class DesktopAboutScreen extends StatefulWidget {
  const DesktopAboutScreen({super.key});

  @override
  State<DesktopAboutScreen> createState() => _DesktopAboutScreenState();
}

class _DesktopAboutScreenState extends State<DesktopAboutScreen> {
  final DesktopMediaEngine _engine = DesktopMediaEngine();
  String _ffmpegVersion = 'Detecting...';

  @override
  void initState() {
    super.initState();
    _loadFfmpegVersion();
  }

  Future<void> _loadFfmpegVersion() async {
    final v = await _engine.getVersion();
    if (mounted) setState(() => _ffmpegVersion = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13151B) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Identity Hero
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.graphic_eq_rounded, size: 42, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'V2A — Video to Audio Studio',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Version 1.2.0 Desktop • Native 64-bit Software',
                    style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'com.v2a.converter.desktop',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Features Summary Card
            Container(
              padding: const EdgeInsets.all(24),
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
                  const Text(
                    'Application Highlights',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  _buildHighlightRow(
                    Icons.bolt_rounded,
                    const Color(0xFF2563EB),
                    'Mode A Stream Copy',
                    'Zero-re-encode packet passthrough (-c:a copy) when source codecs match target containers.',
                  ),
                  const SizedBox(height: 12),
                  _buildHighlightRow(
                    Icons.tune_rounded,
                    const Color(0xFF06B6D4),
                    '8 Conversion Presets',
                    'Fastest Compatibility, Balanced, Best Quality, Smallest File, Voice, Music, Lossless FLAC, Max Compression.',
                  ),
                  const SizedBox(height: 12),
                  _buildHighlightRow(
                    Icons.shield_rounded,
                    const Color(0xFF10B981),
                    'Never Overwrite Guarantee',
                    'Atomic temporary processing files with duplicate-safe unique naming resolution.',
                  ),
                  const SizedBox(height: 12),
                  _buildHighlightRow(
                    Icons.speed_rounded,
                    const Color(0xFF8B5CF6),
                    'Real-Time Streaming Engine',
                    'Direct -progress pipe:1 streaming parser with speed ratios, remaining time estimates, and hardware acceleration.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // System Diagnostics Card
            Container(
              padding: const EdgeInsets.all(24),
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
                  const Text(
                    'System Diagnostics',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildDiagRow('Operating System', Platform.operatingSystemVersion),
                  _buildDiagRow('Architecture', '${Platform.operatingSystem} (${Platform.numberOfProcessors} cores)'),
                  _buildDiagRow('Executable Location', Platform.resolvedExecutable),
                  _buildDiagRow('FFmpeg Core', _ffmpegVersion),
                  _buildDiagRow('Dart VM Version', Platform.version.split(' ').first),
                  _buildDiagRow('License', 'GNU General Public License v3.0 (GPLv3)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightRow(IconData icon, Color color, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

