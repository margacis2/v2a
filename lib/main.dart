import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'desktop/desktop_app_shell.dart';
import 'providers/app_state_provider.dart';
import 'screens/splash_screen.dart';
import 'services/feedback_service.dart';
import 'services/job_queue_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop window configuration (Windows & macOS)
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(1000, 650),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'V2A — Video to Audio Converter',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } else {
    // Android mobile status & navigation bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // Instant lightweight provider creation without blocking first paint
  final appState = AppStateProvider();
  final queueService = JobQueueService();
  final feedbackService = FeedbackService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateProvider>.value(value: appState),
        ChangeNotifierProvider<JobQueueService>.value(value: queueService),
        ChangeNotifierProvider<FeedbackService>.value(value: feedbackService),
      ],
      child: const V2AApp(),
    ),
  );
}

class V2AApp extends StatelessWidget {
  const V2AApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return MaterialApp(
      title: 'V2A — Video to Audio Converter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appState.themeMode,
      home: isDesktop ? const DesktopAppShell() : const SplashScreen(),
    );
  }
}
