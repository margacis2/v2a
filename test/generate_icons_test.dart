import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate official V2A launcher icons for Android', () async {
    final sizes = {
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };

    for (final entry in sizes.entries) {
      final folder = entry.key;
      final size = entry.value;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final w = size.toDouble();
      final h = size.toDouble();
      final center = Offset(w / 2, h / 2);

      // Squircle Background
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h),
        Radius.circular(w * 0.24),
      );

      final bgPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(w, h),
          [
            const Color(0xFF0D47A1),
            const Color(0xFF00ACC1),
          ],
        );
      canvas.drawRRect(rect, bgPaint);

      // Arc
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.35);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: w * 0.38),
        -pi * 0.8,
        pi * 1.6,
        false,
        arcPaint,
      );

      // Play Triangle
      final trianglePath = Path();
      final triLeft = w * 0.26;
      final triRight = w * 0.44;
      final triTop = h * 0.32;
      final triBottom = h * 0.68;
      final triCenterY = h * 0.5;

      trianglePath.moveTo(triLeft, triTop);
      trianglePath.lineTo(triRight, triCenterY);
      trianglePath.lineTo(triLeft, triBottom);
      trianglePath.close();

      final playPaint = Paint()..color = Colors.white;
      canvas.drawPath(trianglePath, playPaint);

      // Waveform Bars
      final barPaint = Paint()..color = const Color(0xFF00E5FF);
      final barWidth = w * 0.065;
      final barRadius = Radius.circular(barWidth / 2);

      final bars = [
        {'x': w * 0.52, 'height': h * 0.28},
        {'x': w * 0.63, 'height': h * 0.46},
        {'x': w * 0.74, 'height': h * 0.34},
        {'x': w * 0.85, 'height': h * 0.20},
      ];

      for (final bar in bars) {
        final bx = bar['x']!;
        final bh = bar['height']!;
        final by = center.dy - (bh / 2);

        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, barWidth, bh), barRadius),
          barPaint,
        );
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(size, size);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final destDir = Directory('android/app/src/main/res/$folder');
        if (!await destDir.exists()) {
          await destDir.create(recursive: true);
        }
        final destFile = File('${destDir.path}/ic_launcher.png');
        await destFile.writeAsBytes(byteData.buffer.asUint8List());
      }
    }

    expect(File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png').existsSync(), isTrue);
  });
}
