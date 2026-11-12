import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v2a/providers/app_state_provider.dart';
import 'package:v2a/screens/splash_screen.dart';
import 'package:v2a/services/feedback_service.dart';
import 'package:v2a/services/job_queue_service.dart';

void main() {
  testWidgets('SplashScreen displays logo, V2A title, and subtitle smoothly', (tester) async {
    SharedPreferences.setMockInitialValues({'v2a_onboarding_completed': true});

    final appState = AppStateProvider();
    final queue = JobQueueService();
    final feedback = FeedbackService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppStateProvider>.value(value: appState),
          ChangeNotifierProvider<JobQueueService>.value(value: queue),
          ChangeNotifierProvider<FeedbackService>.value(value: feedback),
        ],
        child: const MaterialApp(
          home: SplashScreen(),
        ),
      ),
    );

    // Initial frame
    expect(find.text('V2A'), findsOneWidget);
    expect(find.text('Video-to-Audio Converter'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Animate forward
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('V2A'), findsOneWidget);

    // Complete duration to transition
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(seconds: 1));

    appState.stopPerformanceMonitoring();
  });
}
