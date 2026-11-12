import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/job_queue_service.dart';
import 'screens/desktop_about_screen.dart';
import 'screens/desktop_convert_screen.dart';
import 'screens/desktop_history_screen.dart';
import 'screens/desktop_home_screen.dart';
import 'screens/desktop_player_screen.dart';
import 'screens/desktop_queue_screen.dart';
import 'screens/desktop_settings_screen.dart';
import 'screens/desktop_trimmer_screen.dart';
import 'widgets/desktop_sidebar.dart';

class DesktopAppShell extends StatefulWidget {
  const DesktopAppShell({super.key});

  @override
  State<DesktopAppShell> createState() => _DesktopAppShellState();
}

class _DesktopAppShellState extends State<DesktopAppShell> {
  int _currentIndex = 0;

  // Inter-screen state
  String? _convertFilePath;
  String? _trimmerFilePath;
  String? _playerFilePath;

  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onHomeFileSelected(String path) {
    setState(() {
      _convertFilePath = path;
      _currentIndex = 1;
    });
  }

  void _onPlayFile(String path) {
    setState(() {
      _playerFilePath = path;
      _currentIndex = 4;
    });
  }

  void _onReconvertFile(String path) {
    setState(() {
      _convertFilePath = path;
      _currentIndex = 1;
    });
  }

  Future<void> _handleGlobalPickFile() async {
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
        setState(() {
          _convertFilePath = path;
          _currentIndex = 1;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(
          Platform.isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyO,
        ): const _OpenFileIntent(),
        LogicalKeySet(
          Platform.isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
          LogicalKeyboardKey.comma,
        ): const _OpenSettingsIntent(),
        LogicalKeySet(
          Platform.isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyC,
        ): const _ClearQueueIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenFileIntent: CallbackAction<_OpenFileIntent>(
            onInvoke: (intent) => _handleGlobalPickFile(),
          ),
          _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
            onInvoke: (intent) => _navigateTo(6),
          ),
          _ClearQueueIntent: CallbackAction<_ClearQueueIntent>(
            onInvoke: (intent) {
              Provider.of<JobQueueService>(context, listen: false).clearCompleted();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                // Desktop Sidebar Navigation
                DesktopSidebar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _navigateTo,
                ),

                // Active Main Screen
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      DesktopHomeScreen(
                        onNavigate: _navigateTo,
                        onFileSelected: _onHomeFileSelected,
                      ),
                      DesktopConvertScreen(
                        initialFilePath: _convertFilePath,
                        onNavigate: _navigateTo,
                      ),
                      DesktopQueueScreen(
                        onNavigate: _navigateTo,
                      ),
                      DesktopTrimmerScreen(
                        initialFilePath: _trimmerFilePath,
                      ),
                      DesktopPlayerScreen(
                        initialFilePath: _playerFilePath,
                      ),
                      DesktopHistoryScreen(
                        onNavigate: _navigateTo,
                        onPlayFile: _onPlayFile,
                        onReconvertFile: _onReconvertFile,
                      ),
                      const DesktopSettingsScreen(),
                      const DesktopAboutScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenFileIntent extends Intent {
  const _OpenFileIntent();
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

class _ClearQueueIntent extends Intent {
  const _ClearQueueIntent();
}
