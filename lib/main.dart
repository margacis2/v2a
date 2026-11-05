import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_state_provider.dart';
import 'screens/splash_screen.dart';
import 'services/feedback_service.dart';
import 'services/job_queue_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

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

    return MaterialApp(
      title: 'V2A Audio Converter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appState.themeMode,
      home: const SplashScreen(),
    );
  }
}
