import 'package:flutter/material.dart';

class AudioTrimmerDialog extends StatefulWidget {
  final int totalDurationMs;
  final int initialStartMs;
  final int initialEndMs;

  const AudioTrimmerDialog({
    super.key,
    required this.totalDurationMs,
    required this.initialStartMs,
    required this.initialEndMs,
  });

  @override
  State<AudioTrimmerDialog> createState() => _AudioTrimmerDialogState();
}

class _AudioTrimmerDialogState extends State<AudioTrimmerDialog> {
  late int _startMs;
  late int _endMs;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _startMs = widget.initialStartMs.clamp(0, widget.totalDurationMs);
    _endMs = (widget.initialEndMs > 0 ? widget.initialEndMs : widget.totalDurationMs).clamp(0, widget.totalDurationMs);
    if (_endMs <= _startMs) {
      _endMs = widget.totalDurationMs;
    }
    _syncTextControllers();
  }

  void _syncTextControllers() {
    _startController.text = _formatMsToTimestamp(_startMs);
    _endController.text = _formatMsToTimestamp(_endMs);
  }

  String _formatMsToTimestamp(int ms) {
    final d = Duration(milliseconds: ms);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final millis = d.inMilliseconds.remainder(1000);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
  }

  int? _parseTimestampToMs(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    // Check if plain seconds/milliseconds (e.g. 90.500)
    final plainDouble = double.tryParse(clean);
    if (plainDouble != null) {
      return (plainDouble * 1000).round();
    }

    // HH:MM:SS.mmm or MM:SS.mmm
    final parts = clean.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final secParts = parts[2].split('.');
      final s = int.tryParse(secParts[0]) ?? 0;
      final ms = secParts.length > 1 ? (int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0) : 0;
      return (h * 3600000) + (m * 60000) + (s * 1000) + ms;
    } else if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final secParts = parts[1].split('.');
      final s = int.tryParse(secParts[0]) ?? 0;
      final ms = secParts.length > 1 ? (int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0) : 0;
      return (m * 60000) + (s * 1000) + ms;
    }
    return null;
  }

  void _adjustTime({required bool isStart, required int deltaMs}) {
    setState(() {
      _validationError = null;
      if (isStart) {
        _startMs = (_startMs + deltaMs).clamp(0, _endMs - 100);
      } else {
        _endMs = (_endMs + deltaMs).clamp(_startMs + 100, widget.totalDurationMs);
      }
      _syncTextControllers();
    });
  }

  void _onManualTimeChanged() {
    final s = _parseTimestampToMs(_startController.text);
    final e = _parseTimestampToMs(_endController.text);

    if (s == null || e == null) {
      setState(() => _validationError = 'Invalid timestamp format (use MM:SS.mmm)');
      return;
    }

    if (s < 0 || e > widget.totalDurationMs || s >= e) {
      setState(() => _validationError = 'Start time must be before end time and within video duration');
      return;
    }

    setState(() {
      _validationError = null;
      _startMs = s;
      _endMs = e;
    });
  }

  void _resetTrim() {
    setState(() {
      _validationError = null;
      _startMs = 0;
      _endMs = widget.totalDurationMs;
      _syncTextControllers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalMs = widget.totalDurationMs > 0 ? widget.totalDurationMs : 1;
    final segmentDurationMs = (_endMs - _startMs).clamp(0, totalMs);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.content_cut_rounded, color: theme.colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Precise Audio Trimming',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Total Duration: ${_formatMsToTimestamp(totalMs)}',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Segment Duration Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text('Segment Duration:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      _formatMsToTimestamp(segmentDurationMs),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Timeline Range Slider
              RangeSlider(
                values: RangeValues(
                  _startMs.toDouble().clamp(0.0, totalMs.toDouble()),
                  _endMs.toDouble().clamp(_startMs.toDouble(), totalMs.toDouble()),
                ),
                min: 0.0,
                max: totalMs.toDouble(),
                onChanged: (RangeValues values) {
                  setState(() {
                    _validationError = null;
                    _startMs = values.start.round();
                    _endMs = values.end.round();
                    _syncTextControllers();
                  });
                },
              ),

              const SizedBox(height: 12),

              // Manual Timestamp Entry (Hours:Minutes:Seconds.Milliseconds)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _startController,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '00:00.000',
                          ),
                          onChanged: (_) => _onManualTimeChanged(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _endController,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '00:00.000',
                          ),
                          onChanged: (_) => _onManualTimeChanged(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_validationError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validationError!,
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
              ],

              const SizedBox(height: 16),

              // Quick Minute Jump Controls (for long files, 180m, 300m+)
              const Text('Quick Minute Adjustments:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _jumpChip('Start -1m', () => _adjustTime(isStart: true, deltaMs: -60000), theme),
                  _jumpChip('Start +1m', () => _adjustTime(isStart: true, deltaMs: 60000), theme),
                  _jumpChip('Start +5m', () => _adjustTime(isStart: true, deltaMs: 300000), theme),
                  _jumpChip('End -5m', () => _adjustTime(isStart: false, deltaMs: -300000), theme),
                  _jumpChip('End -1m', () => _adjustTime(isStart: false, deltaMs: -60000), theme),
                  _jumpChip('End +1m', () => _adjustTime(isStart: false, deltaMs: 60000), theme),
                ],
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset'),
                    onPressed: _resetTrim,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: _validationError == null
                            ? () {
                                Navigator.of(context).pop({'startMs': _startMs, 'endMs': _endMs});
                              }
                            : null,
                        child: const Text('Apply Trim'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jumpChip(String label, VoidCallback onTap, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        visualDensity: VisualDensity.compact,
        label: Text(label, style: const TextStyle(fontSize: 11)),
        onPressed: onTap,
      ),
    );
  }
}
