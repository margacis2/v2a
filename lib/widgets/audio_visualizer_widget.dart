import 'dart:math';
import 'package:flutter/material.dart';

class AudioVisualizerWidget extends StatefulWidget {
  final bool isPlaying;
  final Color? color;
  final int barCount;

  const AudioVisualizerWidget({
    super.key,
    required this.isPlaying,
    this.color,
    this.barCount = 28,
  });

  @override
  State<AudioVisualizerWidget> createState() => _AudioVisualizerWidgetState();
}

class _AudioVisualizerWidgetState extends State<AudioVisualizerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  late List<double> _heightMultipliers;

  @override
  void initState() {
    super.initState();
    _heightMultipliers = List.generate(widget.barCount, (_) => 0.2 + _random.nextDouble() * 0.8);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(() {
        if (widget.isPlaying) {
          setState(() {
            for (int i = 0; i < _heightMultipliers.length; i++) {
              _heightMultipliers[i] = 0.15 + _random.nextDouble() * 0.85;
            }
          });
        }
      });

    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AudioVisualizerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
      setState(() {
        for (int i = 0; i < _heightMultipliers.length; i++) {
          _heightMultipliers[i] = 0.2;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (index) {
          final heightFactor = _heightMultipliers[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: 4,
            height: (70 * heightFactor).clamp(6.0, 70.0),
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: widget.isPlaying ? 0.9 : 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

