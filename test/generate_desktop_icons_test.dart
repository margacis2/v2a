import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> renderV2AIcon(int size) async {
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
  return byteData!.buffer.asUint8List();
}

Uint8List buildIcoFile(List<MapEntry<int, Uint8List>> images) {
  final count = images.length;
  // Header: 6 bytes
  // Directory entries: 16 bytes per image
  final headerAndDirSize = 6 + (16 * count);

  var totalSize = headerAndDirSize;
  for (final img in images) {
    totalSize += img.value.length;
  }

  final byteData = ByteData(totalSize);

  // Write ICO header
  byteData.setUint16(0, 0, Endian.little); // Reserved
  byteData.setUint16(2, 1, Endian.little); // Image type (1 = ICO)
  byteData.setUint16(4, count, Endian.little); // Number of images

  var currentOffset = headerAndDirSize;

  for (var i = 0; i < count; i++) {
    final size = images[i].key;
    final pngBytes = images[i].value;
    final entryOffset = 6 + (i * 16);

    byteData.setUint8(entryOffset + 0, size == 256 ? 0 : size); // Width
    byteData.setUint8(entryOffset + 1, size == 256 ? 0 : size); // Height
    byteData.setUint8(entryOffset + 2, 0); // Palette count
    byteData.setUint8(entryOffset + 3, 0); // Reserved
    byteData.setUint16(entryOffset + 4, 1, Endian.little); // Color planes
    byteData.setUint16(entryOffset + 6, 32, Endian.little); // Bits per pixel
    byteData.setUint32(entryOffset + 8, pngBytes.length, Endian.little); // Image size
    byteData.setUint32(entryOffset + 12, currentOffset, Endian.little); // Image offset

    // Copy PNG bytes into payload
    final destView = byteData.buffer.asUint8List(currentOffset, pngBytes.length);
    destView.setAll(0, pngBytes);

    currentOffset += pngBytes.length;
  }

  return byteData.buffer.asUint8List();
}

void main() {
  test('Generate official V2A icons for Windows and macOS', () async {
    // 1. Generate macOS AppIcon set
    final macosSizes = {
      16: 'app_icon_16.png',
      32: 'app_icon_32.png',
      64: 'app_icon_64.png',
      128: 'app_icon_128.png',
      256: 'app_icon_256.png',
      512: 'app_icon_512.png',
      1024: 'app_icon_1024.png',
    };

    final macosDir = Directory('macos/Runner/Assets.xcassets/AppIcon.appiconset');
    if (!await macosDir.exists()) {
      await macosDir.create(recursive: true);
    }

    final icoImages = <MapEntry<int, Uint8List>>[];

    for (final entry in macosSizes.entries) {
      final size = entry.key;
      final fileName = entry.value;

      final pngBytes = await renderV2AIcon(size);
      final outFile = File('${macosDir.path}/$fileName');
      await outFile.writeAsBytes(pngBytes);

      if ([16, 32, 48, 64, 128, 256].contains(size)) {
        icoImages.add(MapEntry(size, pngBytes));
      }
    }

    // Also render 48x48 specifically for Windows ICO
    final png48 = await renderV2AIcon(48);
    icoImages.insert(2, MapEntry(48, png48));

    // Sort ICO images by resolution ascending
    icoImages.sort((a, b) => a.key.compareTo(b.key));

    // 2. Generate Windows app_icon.ico
    final icoBytes = buildIcoFile(icoImages);
    final winIconFile = File('windows/runner/resources/app_icon.ico');
    if (!await winIconFile.parent.exists()) {
      await winIconFile.parent.create(recursive: true);
    }
    await winIconFile.writeAsBytes(icoBytes);

    expect(winIconFile.existsSync(), isTrue);
    expect(winIconFile.lengthSync() > 1000, isTrue);

    for (final fileName in macosSizes.values) {
      final f = File('${macosDir.path}/$fileName');
      expect(f.existsSync(), isTrue);
      expect(f.lengthSync() > 100, isTrue);
    }
  });
}
