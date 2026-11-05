import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2a/models/conversion_config.dart';
import 'package:v2a/widgets/bitrate_selector_widget.dart';
import 'package:v2a/widgets/v2a_logo_widget.dart';
import 'package:v2a/widgets/stat_badge.dart';
import 'package:v2a/widgets/audio_trimmer_widget.dart';

void main() {
  testWidgets('BitrateSelectorWidget renders cleanly on narrow 320px screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    int selectedBitrate = 192;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BitrateSelectorWidget(
              format: AudioFormat.mp3,
              selectedBitrate: selectedBitrate,
              onBitrateChanged: (val) {
                selectedBitrate = val;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify key chips render without overflow
    expect(find.text('128'), findsWidgets);
    expect(find.text('320'), findsWidgets);
    expect(find.byType(Slider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BitrateSelectorWidget renders cleanly in landscape (800x400)', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BitrateSelectorWidget(
              format: AudioFormat.aac,
              selectedBitrate: 256,
              onBitrateChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('High Fidelity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatBadge gracefully truncates long text without RenderFlex overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: StatBadge(
              icon: Icons.speed_rounded,
              label: 'EXTREMELY_LONG_STATUS_LABEL_THAT_WOULD_OVERFLOW_NORMALLY',
              value: '100% OK',
              color: Colors.blue,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('V2ALogo renders with waveform and text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: V2ALogo(size: 80, showText: true),
          ),
        ),
      ),
    );

    expect(find.byType(V2ALogo), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AudioTrimmerDialog renders and interacts without overflow on 360px', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AudioTrimmerDialog(
            totalDurationMs: 600000, // 10 minutes
            initialStartMs: 30000,
            initialEndMs: 300000,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Precise Audio Trimming'), findsOneWidget);
    expect(find.text('Start +1m'), findsOneWidget);
    expect(find.text('Apply Trim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('All 8 ConversionPresets have valid parameters', () {
    final validPresets = ConversionPreset.values.where((p) => p != ConversionPreset.custom).toList();
    expect(validPresets.length, equals(8));

    for (final preset in validPresets) {
      expect(preset.label.isNotEmpty, isTrue);
      expect(preset.description.isNotEmpty, isTrue);
      expect(preset.format, isNotNull);
      expect(preset.sampleRate, greaterThanOrEqualTo(0));
    }
  });
}
