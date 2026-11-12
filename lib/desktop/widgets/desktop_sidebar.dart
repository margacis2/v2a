import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/conversion_job.dart';
import '../../services/job_queue_service.dart';

class DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final queue = Provider.of<JobQueueService>(context);
    final activeJobCount = queue.jobs.where((j) => j.status == JobStatus.running || j.status == JobStatus.queued).length;

    final navItems = [
      _NavItem(icon: Icons.dashboard_rounded, label: 'Home'),
      _NavItem(icon: Icons.swap_horiz_rounded, label: 'Convert'),
      _NavItem(
        icon: Icons.view_list_rounded,
        label: 'Queue',
        badgeCount: activeJobCount,
      ),
      _NavItem(icon: Icons.content_cut_rounded, label: 'Trimmer'),
      _NavItem(icon: Icons.headphones_rounded, label: 'Audio Player'),
      _NavItem(icon: Icons.history_rounded, label: 'History'),
      _NavItem(icon: Icons.settings_rounded, label: 'Settings'),
      _NavItem(icon: Icons.info_outline_rounded, label: 'About'),
    ];

    final bgColor = isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF2E3440) : const Color(0xFFE2E8F0);

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Branding
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'V2A',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'v1.2.0',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Video to Audio Studio',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Navigation Links
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: navItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = selectedIndex == index;

                return InkWell(
                  onTap: () => onDestinationSelected(index),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 20,
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : (isDark ? Colors.grey[400] : Colors.grey[700]),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected
                                  ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                  : (isDark ? Colors.grey[300] : Colors.grey[800]),
                            ),
                          ),
                        ),
                        if (item.badgeCount != null && item.badgeCount! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${item.badgeCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14171E) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Desktop Native • 64-bit',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int? badgeCount;

  _NavItem({
    required this.icon,
    required this.label,
    this.badgeCount,
  });
}
