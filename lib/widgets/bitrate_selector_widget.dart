import 'package:flutter/material.dart';
import '../models/conversion_config.dart';

class BitrateSelectorWidget extends StatelessWidget {
  final AudioFormat format;
  final int selectedBitrate;
  final ValueChanged<int> onBitrateChanged;

  static const List<int> standardBitrates = [
    16,
    32,
    64,
    96,
    128,
    160,
    192,
    224,
    256,
    320,
  ];

  const BitrateSelectorWidget({
    super.key,
    required this.format,
    required this.selectedBitrate,
    required this.onBitrateChanged,
  });

  String _getFidelityLabel(int kbps) {
    if (kbps <= 32) return 'Low Bandwidth (Ultra Compact)';
    if (kbps <= 64) return 'Speech / Podcast (Compact)';
    if (kbps <= 96) return 'Standard Voice / Clean Audio';
    if (kbps <= 160) return 'Standard Quality (Good Balance)';
    if (kbps <= 224) return 'High Fidelity (Recommended)';
    if (kbps <= 256) return 'Very High Fidelity';
    return 'Studio Quality (Maximum MP3/AAC)';
  }

  void _showCustomBitrateDialog(BuildContext context) {
    final controller = TextEditingController(text: selectedBitrate.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Bitrate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Bitrate (kbps)',
                suffixText: 'kbps',
                hintText: 'e.g. 192',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Valid range: 16 kbps to 320 kbps for ${format.label}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 16 && val <= 320) {
                onBitrateChanged(val);
                Navigator.of(ctx).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid bitrate between 16 and 320 kbps')),
                );
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!format.isLossy || format.supportedBitrates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_rounded, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${format.label} uses bit-perfect lossless compression. Fixed bitrate is not applicable.',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    final availableBitrates = format.supportedBitrates;
    final minBitrate = availableBitrates.first.toDouble();
    final maxBitrate = availableBitrates.last.toDouble();
    final currentSliderVal = selectedBitrate.clamp(minBitrate.toInt(), maxBitrate.toInt()).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header with selected value badge and custom button
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Audio Bitrate:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$selectedBitrate kbps',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _getFidelityLabel(selectedBitrate),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: const Text('Custom', style: TextStyle(fontSize: 12)),
              onPressed: () => _showCustomBitrateDialog(context),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Continuous Slider snapping to discrete options
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: currentSliderVal,
            min: minBitrate,
            max: maxBitrate,
            divisions: availableBitrates.length > 1 ? availableBitrates.length - 1 : null,
            label: '$selectedBitrate kbps',
            onChanged: (val) {
              // Find nearest available discrete bitrate
              int nearest = availableBitrates.first;
              int minDiff = 999999;
              for (final b in availableBitrates) {
                final diff = (b - val).abs().toInt();
                if (diff < minDiff) {
                  minDiff = diff;
                  nearest = b;
                }
              }
              onBitrateChanged(nearest);
            },
          ),
        ),

        const SizedBox(height: 6),

        // Quick Pick Chips (Responsive Wrap ensuring no horizontal overflow on 320px)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: availableBitrates.map((b) {
            final isSelected = selectedBitrate == b;
            return ChoiceChip(
              visualDensity: VisualDensity.compact,
              label: Text(
                '$b',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) onBitrateChanged(b);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
