import 'dart:math';
import 'package:flutter/material.dart';

class V2ALogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? color;

  const V2ALogo({
    super.key,
    this.size = 48,
    this.showText = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = color ?? theme.colorScheme.primary;

    final logoWidget = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _V2ALogoPainter(
          primaryColor: primary,
          accentColor: const Color(0xFF00E5FF),
          secondaryColor: const Color(0xFF0091EA),
        ),
      ),
    );

    if (!showText) return logoWidget;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoWidget,
        const SizedBox(width: 10),
        Text(
          'V2A',
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: primary,
          ),
        ),
      ],
    );
  }
}

class _V2ALogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final Color secondaryColor;

  _V2ALogoPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // 1. Background Rounded Squircle with Vibrant Gradient
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w * 0.26),
    );

    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF0D47A1),
          const Color(0xFF1976D2),
          const Color(0xFF00ACC1),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRRect(rect, bgPaint);

    // Subtle inner glow rim
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..color = Colors.white.withValues(alpha: 0.25);
    canvas.drawRRect(rect, borderPaint);

    // 2. Transformation Arc (Circular arrow representing Video -> Audio conversion)
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.35);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: w * 0.38),
      -pi * 0.8,
      pi * 1.6,
      false,
      arcPaint,
    );

    // 3. Left Video Play Triangle Symbol
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

    final playPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white, const Color(0xFFE0F7FA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(triLeft, triTop, triRight - triLeft, triBottom - triTop));

    canvas.drawPath(trianglePath, playPaint);

    // 4. Right Equalizer Audio Waveform Bars (Representing Audio Output)
    final barPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

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
      final bh = bar['y'] ?? bar['height']!;
      final by = center.dy - (bh / 2);

      barPaint.shader = LinearGradient(
        colors: [
          const Color(0xFF00E5FF),
          Colors.white,
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(bx, by, barWidth, bh));

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, barWidth, bh), barRadius),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

